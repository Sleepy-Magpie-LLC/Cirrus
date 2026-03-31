import Foundation
import os

@MainActor @Observable
final class JobManager {
    private(set) var activeJobs: [UUID: JobRun] = [:]
    private let rclonePath: () -> String?
    private let logStore: LogStore

    private static let logger = Logger(subsystem: "com.sane.cirrus", category: "JobManager")

    init(rclonePath: @escaping () -> String?, logStore: LogStore) {
        self.rclonePath = rclonePath
        self.logStore = logStore
    }

    var runningCount: Int {
        activeJobs.values.filter { $0.status == .running }.count
    }

    func isRunning(for profileId: UUID) -> Bool {
        activeJobs[profileId]?.status == .running
    }

    func startJob(for profile: Profile) throws {
        guard let path = rclonePath() else {
            throw CirrusError.rcloneNotFound
        }

        let snapshot = profile

        // Write filter file if patterns exist
        var filterURL: URL?
        if !snapshot.ignorePatterns.isEmpty {
            filterURL = try FilterFileWriter.write(patterns: snapshot.ignorePatterns)
        }

        // For bisync, add --resync until a bisync run succeeds
        let needsResync = snapshot.action == .bisync &&
            !logStore.entries(for: snapshot.id).contains(where: { $0.status == .success && $0.action == .bisync })

        // Build command
        let args = RcloneService.buildCommand(profile: snapshot, filterFileURL: filterURL, needsResync: needsResync)

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Log file
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let logFileName = "\(snapshot.id.uuidString.lowercased())_\(timestamp).log"
        let logFileURL = logStore.logFileURL(for: logFileName)

        // Build display command for log
        let commandString = RcloneService.commandPreview(
            rclonePath: path,
            action: snapshot.action,
            source: snapshot.source,
            destination: snapshot.destination,
            ignorePatterns: snapshot.ignorePatterns,
            extraFlags: snapshot.extraFlags
        )

        // Create log entry
        let logEntry = logStore.createEntry(profileId: snapshot.id, logFileName: logFileName, command: commandString, action: snapshot.action)

        // Create job run
        let jobRun = JobRun(
            profileId: snapshot.id,
            profileSnapshot: snapshot,
            process: process,
            logFileURL: logFileURL,
            logEntryId: logEntry.id,
            filterFileURL: filterURL
        )

        activeJobs[snapshot.id] = jobRun

        // Setup pipe handlers
        let logStoreRef = logStore
        let entryId = logEntry.id

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                logStoreRef.appendChunk(jobId: entryId, chunk: chunk)
                logStoreRef.appendToLogFile(url: logFileURL, chunk: chunk)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                logStoreRef.appendChunk(jobId: entryId, chunk: "\(chunk)")
                logStoreRef.appendToLogFile(url: logFileURL, chunk: "\(chunk)")
            }
        }

        // Termination handler
        let startedAt = jobRun.startedAt

        let profileId = snapshot.id
        // Use nonisolated(unsafe) isCancelled via unowned reference to avoid Sendable issue
        nonisolated(unsafe) let jobRunRef = jobRun
        nonisolated(unsafe) let filterURLRef = filterURL

        process.terminationHandler = { [weak self] proc in
            let duration = Date().timeIntervalSince(startedAt)
            let finalStatus: JobStatus
            if jobRunRef.isCancelled {
                finalStatus = .canceled
            } else {
                finalStatus = proc.terminationStatus == 0 ? .success : .failed
            }

            // Nil out readability handlers before reading remaining data
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            Task { @MainActor [weak self] in
                if !remainingStdout.isEmpty, let chunk = String(data: remainingStdout, encoding: .utf8) {
                    logStoreRef.appendToLogFile(url: logFileURL, chunk: chunk)
                }
                if !remainingStderr.isEmpty, let chunk = String(data: remainingStderr, encoding: .utf8) {
                    logStoreRef.appendToLogFile(url: logFileURL, chunk: "\(chunk)")
                }

                logStoreRef.finalizeEntry(id: entryId, status: finalStatus, duration: duration)

                if let filterURL = filterURLRef {
                    FilterFileWriter.cleanup(at: filterURL)
                }

                self?.activeJobs.removeValue(forKey: profileId)
            }
        }

        // Launch
        do {
            try process.run()
        } catch {
            activeJobs.removeValue(forKey: snapshot.id)
            if let url = filterURL {
                FilterFileWriter.cleanup(at: url)
            }
            throw CirrusError.processSpawnFailed(underlying: error)
        }
    }

    func cancelJob(for profileId: UUID) {
        guard let job = activeJobs[profileId], job.process.isRunning else { return }
        job.isCancelled = true
        job.process.terminate()

        Task {
            try? await Task.sleep(for: .seconds(2))
            if job.process.isRunning {
                kill(job.process.processIdentifier, SIGKILL)
            }
        }
    }

    func cancelAllJobs() {
        let jobs = activeJobs.values.filter { $0.process.isRunning }
        for job in jobs {
            job.isCancelled = true
            job.process.terminate()
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            for job in jobs where job.process.isRunning {
                kill(job.process.processIdentifier, SIGKILL)
            }
        }
    }
}
