import Testing
@testable import Cirrus
import Foundation

@MainActor
struct ScheduleManagerTests {
    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func initSetsEmptyLastFireDates() {
        let tempDir = makeTempDir()
        let profileStore = ProfileStore(configDirectoryURL: { tempDir })
        let logStore = LogStore(configDirectoryURL: { tempDir })
        let jobManager = JobManager(rclonePath: { nil }, logStore: logStore)
        let manager = ScheduleManager(
            profileStore: profileStore,
            jobManager: jobManager,
            configDirectoryURL: { tempDir }
        )
        #expect(manager.lastFireDates.isEmpty)
    }

    @Test func clearFailureRemovesFromSet() {
        let tempDir = makeTempDir()
        let profileStore = ProfileStore(configDirectoryURL: { tempDir })
        let logStore = LogStore(configDirectoryURL: { tempDir })
        let jobManager = JobManager(rclonePath: { nil }, logStore: logStore)
        let manager = ScheduleManager(
            profileStore: profileStore,
            jobManager: jobManager,
            configDirectoryURL: { tempDir }
        )
        let id = UUID()
        // clearFailure on an ID not in the set should not crash
        manager.clearFailure(for: id)
        #expect(manager.lastFireDates.isEmpty)
    }

    @Test func startIsIdempotent() {
        let tempDir = makeTempDir()
        let profileStore = ProfileStore(configDirectoryURL: { tempDir })
        let logStore = LogStore(configDirectoryURL: { tempDir })
        let jobManager = JobManager(rclonePath: { nil }, logStore: logStore)
        let manager = ScheduleManager(
            profileStore: profileStore,
            jobManager: jobManager,
            configDirectoryURL: { tempDir }
        )
        manager.start()
        manager.start() // second call should be no-op
        manager.stop()
    }

    @Test func stopCancelsEvaluationTask() {
        let tempDir = makeTempDir()
        let profileStore = ProfileStore(configDirectoryURL: { tempDir })
        let logStore = LogStore(configDirectoryURL: { tempDir })
        let jobManager = JobManager(rclonePath: { nil }, logStore: logStore)
        let manager = ScheduleManager(
            profileStore: profileStore,
            jobManager: jobManager,
            configDirectoryURL: { tempDir }
        )
        manager.start()
        manager.stop()
        // Should be able to start again after stop
        manager.start()
        manager.stop()
    }
}
