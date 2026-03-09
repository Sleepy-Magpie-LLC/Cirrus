import Foundation
import os

@MainActor @Observable
final class LogStore {
    private(set) var entries: [LogEntry] = []
    var liveBuffer: [UUID: String] = [:]
    private let configDirectoryURL: () -> URL
    private let fileManager = FileManager.default

    private static let logger = Logger(subsystem: "com.sane.cirrus", category: "LogStore")

    init(configDirectoryURL: @escaping () -> URL) {
        self.configDirectoryURL = configDirectoryURL
    }

    private var logsDirectory: URL {
        configDirectoryURL().appendingPathComponent("logs/runs")
    }

    private var indexFileURL: URL {
        configDirectoryURL().appendingPathComponent("logs/index.json")
    }

    func loadIndex() {
        guard fileManager.fileExists(atPath: indexFileURL.path) else {
            entries = []
            return
        }

        do {
            let data = try Data(contentsOf: indexFileURL)
            entries = try JSONDecoder.cirrus.decode([LogEntry].self, from: data)
            finalizeStaleEntries()
        } catch {
            Self.logger.warning("Failed to load log index: \(error.localizedDescription)")
            entries = []
        }
    }

    /// Marks any entries still in `.running` state as `.interrupted` — they were killed by an app quit.
    private func finalizeStaleEntries() {
        var changed = false
        for i in entries.indices where entries[i].status == .running {
            entries[i].status = .interrupted
            entries[i].completedAt = entries[i].startedAt
            changed = true
        }
        if changed {
            try? saveIndex()
        }
    }

    func createEntry(profileId: UUID, logFileName: String, command: String? = nil, action: RcloneAction? = nil) -> LogEntry {
        let entry = LogEntry(profileId: profileId, logFileName: logFileName, command: command, action: action)
        entries.append(entry)
        try? saveIndex()
        return entry
    }

    func finalizeEntry(id: UUID, status: JobStatus, duration: Double) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].status = status
        entries[index].completedAt = Date()
        entries[index].durationSeconds = duration
        try? saveIndex()
        liveBuffer.removeValue(forKey: id)
    }

    func saveIndex() throws {
        let dir = configDirectoryURL().appendingPathComponent("logs")
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder.cirrus.encode(entries)
        try AtomicFileWriter.write(data, to: indexFileURL)
    }

    func appendChunk(jobId: UUID, chunk: String) {
        let current = liveBuffer[jobId, default: ""]
        liveBuffer[jobId] = current + chunk.strippingANSICodes()
    }

    func appendToLogFile(url: URL, chunk: String) {
        guard let data = chunk.strippingANSICodes().data(using: .utf8) else { return }
        if fileManager.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }

    func logFileURL(for fileName: String) -> URL {
        logsDirectory.appendingPathComponent(fileName)
    }

    func entries(for profileId: UUID) -> [LogEntry] {
        entries
            .filter { $0.profileId == profileId }
            .sorted { ($0.startedAt) > ($1.startedAt) }
    }

    func lastStatus(for profileId: UUID) -> JobStatus? {
        entries
            .filter { $0.profileId == profileId }
            .max(by: { $0.startedAt < $1.startedAt })?
            .status
    }

    func readLogFile(fileName: String) -> String {
        let url = logFileURL(for: fileName)
        return (try? String(contentsOf: url, encoding: .utf8))?.strippingANSICodes() ?? "Log file not found."
    }
}
