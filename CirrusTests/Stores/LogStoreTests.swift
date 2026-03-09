import Testing
@testable import Cirrus
import Foundation

struct LogStoreTests {
    private func makeTempConfigDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cirrus-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: url.appendingPathComponent("logs/runs"),
            withIntermediateDirectories: true
        )
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test @MainActor func createEntryAddsToEntries() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let entry = store.createEntry(profileId: UUID(), logFileName: "test.log")

        #expect(store.entries.count == 1)
        #expect(store.entries[0].id == entry.id)
        #expect(store.entries[0].status == .running)
    }

    @Test @MainActor func finalizeEntryUpdatesStatus() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let entry = store.createEntry(profileId: UUID(), logFileName: "test.log")

        store.finalizeEntry(id: entry.id, status: .success, duration: 10.5)

        #expect(store.entries[0].status == .success)
        #expect(store.entries[0].durationSeconds == 10.5)
        #expect(store.entries[0].completedAt != nil)
    }

    @Test @MainActor func saveAndLoadIndex() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        _ = store.createEntry(profileId: UUID(), logFileName: "test1.log")
        _ = store.createEntry(profileId: UUID(), logFileName: "test2.log")

        let store2 = LogStore(configDirectoryURL: { configDir })
        store2.loadIndex()

        #expect(store2.entries.count == 2)
    }

    @Test @MainActor func loadIndexWithMissingFileReturnsEmpty() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        store.loadIndex()

        #expect(store.entries.isEmpty)
    }

    @Test @MainActor func appendChunkUpdatesLiveBuffer() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let jobId = UUID()

        store.appendChunk(jobId: jobId, chunk: "hello ")
        store.appendChunk(jobId: jobId, chunk: "world")

        #expect(store.liveBuffer[jobId] == "hello world")
    }

    @Test @MainActor func finalizeEntryClearsLiveBuffer() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let entry = store.createEntry(profileId: UUID(), logFileName: "test.log")

        store.appendChunk(jobId: entry.id, chunk: "output")
        store.finalizeEntry(id: entry.id, status: .success, duration: 1.0)

        #expect(store.liveBuffer[entry.id] == nil)
    }

    @Test @MainActor func appendToLogFileCreatesAndAppends() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let fileURL = configDir.appendingPathComponent("logs/runs/test.log")

        store.appendToLogFile(url: fileURL, chunk: "line 1\n")
        store.appendToLogFile(url: fileURL, chunk: "line 2\n")

        let content = try? String(contentsOf: fileURL, encoding: .utf8)
        #expect(content == "line 1\nline 2\n")
    }

    @Test @MainActor func entriesForProfileFiltersCorrectly() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let profileA = UUID()
        let profileB = UUID()

        _ = store.createEntry(profileId: profileA, logFileName: "a1.log")
        _ = store.createEntry(profileId: profileB, logFileName: "b1.log")
        _ = store.createEntry(profileId: profileA, logFileName: "a2.log")

        let entriesA = store.entries(for: profileA)
        #expect(entriesA.count == 2)
        #expect(entriesA.allSatisfy { $0.profileId == profileA })

        let entriesB = store.entries(for: profileB)
        #expect(entriesB.count == 1)
    }

    @Test @MainActor func entriesForProfileSortsMostRecentFirst() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let profileId = UUID()

        let entry1 = store.createEntry(profileId: profileId, logFileName: "1.log")
        let entry2 = store.createEntry(profileId: profileId, logFileName: "2.log")

        let entries = store.entries(for: profileId)
        // entry2 was created after entry1, so it should appear first
        #expect(entries[0].id == entry2.id)
        #expect(entries[1].id == entry1.id)
    }

    @Test @MainActor func lastStatusReturnsNilForUnknownProfile() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        #expect(store.lastStatus(for: UUID()) == nil)
    }

    @Test @MainActor func readLogFileReturnsContent() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let fileURL = configDir.appendingPathComponent("logs/runs/test.log")
        try! "line 1\nline 2\n".data(using: .utf8)!.write(to: fileURL)

        let content = store.readLogFile(fileName: "test.log")
        #expect(content == "line 1\nline 2\n")
    }

    @Test @MainActor func readLogFileMissingReturnsNotFound() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let content = store.readLogFile(fileName: "nonexistent.log")
        #expect(content == "Log file not found.")
    }

    @Test @MainActor func lastStatusReturnsMostRecentStatus() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = LogStore(configDirectoryURL: { configDir })
        let profileId = UUID()

        let entry1 = store.createEntry(profileId: profileId, logFileName: "1.log")
        store.finalizeEntry(id: entry1.id, status: .success, duration: 10)

        let entry2 = store.createEntry(profileId: profileId, logFileName: "2.log")
        store.finalizeEntry(id: entry2.id, status: .failed, duration: 5)

        #expect(store.lastStatus(for: profileId) == .failed)
    }
}
