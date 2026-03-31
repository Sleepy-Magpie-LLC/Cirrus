import Foundation
import os

@MainActor @Observable
final class ScheduleManager {
    private var evaluationTask: Task<Void, Never>?
    private(set) var lastFireDates: [UUID: Date] = [:]
    private var failedProfiles: Set<UUID> = []
    private var lastPruneDate: Date?
    private let profileStore: ProfileStore
    private let jobManager: JobManager
    private let logStore: LogStore
    private let configDirectoryURL: () -> URL

    private static let logger = Logger(subsystem: "com.sane.cirrus", category: "ScheduleManager")

    init(profileStore: ProfileStore, jobManager: JobManager, logStore: LogStore, configDirectoryURL: @escaping () -> URL) {
        self.profileStore = profileStore
        self.jobManager = jobManager
        self.logStore = logStore
        self.configDirectoryURL = configDirectoryURL
    }

    func start() {
        guard evaluationTask == nil else { return }
        loadLastFireDates()
        evaluationTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.evaluateSchedules()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stop() {
        evaluationTask?.cancel()
        evaluationTask = nil
    }

    private func evaluateSchedules() {
        let now = Date()

        if lastPruneDate == nil || now.timeIntervalSince(lastPruneDate!) > 86400 {
            logStore.pruneExpiredLogs(profiles: profileStore.profiles)
            lastPruneDate = now
        }

        for profile in profileStore.profiles {
            guard let schedule = profile.schedule, schedule.enabled else { continue }
            guard !jobManager.isRunning(for: profile.id) else { continue }
            guard !failedProfiles.contains(profile.id) else { continue }

            do {
                let lastFired = lastFireDates[profile.id] ?? .distantPast
                let nextFire = try CronParser.nextFireDate(for: schedule.expression, after: lastFired)

                if nextFire <= now {
                    try jobManager.startJob(for: profile)
                    lastFireDates[profile.id] = now
                    saveLastFireDates()
                    Self.logger.info("Scheduled job fired for profile '\(profile.name)'")
                }
            } catch let error as CirrusError {
                // Cron parse errors — log and skip until profile is edited
                Self.logger.warning("Schedule evaluation failed for '\(profile.name)': \(error.localizedDescription)")
            } catch {
                // startJob failure — mark as failed to prevent retry storm
                failedProfiles.insert(profile.id)
                Self.logger.warning("Failed to start scheduled job for '\(profile.name)': \(error.localizedDescription)")
            }
        }
    }

    /// Clear failure state when a profile is edited, allowing retry
    func clearFailure(for profileId: UUID) {
        failedProfiles.remove(profileId)
    }

    // MARK: - Persistence

    private var fireDatesFileURL: URL {
        configDirectoryURL().appendingPathComponent("schedule-state.json")
    }

    private func loadLastFireDates() {
        guard FileManager.default.fileExists(atPath: fireDatesFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fireDatesFileURL)
            let decoded = try JSONDecoder.cirrus.decode([String: Date].self, from: data)
            lastFireDates = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        } catch {
            Self.logger.warning("Failed to load schedule state: \(error.localizedDescription)")
        }
    }

    private func saveLastFireDates() {
        let encoded = Dictionary(uniqueKeysWithValues: lastFireDates.map { ($0.key.uuidString, $0.value) })
        do {
            let data = try JSONEncoder.cirrus.encode(encoded)
            try AtomicFileWriter.write(data, to: fireDatesFileURL)
        } catch {
            Self.logger.warning("Failed to save schedule state: \(error.localizedDescription)")
        }
    }
}
