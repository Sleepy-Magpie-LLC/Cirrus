import Testing
@testable import Cirrus
import Foundation

struct ProfileStoreTests {
    private func makeTempConfigDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cirrus-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: url.appendingPathComponent("profiles"),
            withIntermediateDirectories: true
        )
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test @MainActor func saveCreatesFile() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = ProfileStore(configDirectoryURL: { configDir })
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "gdrive", path: "/backup")
        )

        try store.save(profile)

        let expectedFile = configDir
            .appendingPathComponent("profiles")
            .appendingPathComponent("\(profile.id.uuidString.lowercased()).json")
        #expect(FileManager.default.fileExists(atPath: expectedFile.path))
    }

    @Test @MainActor func saveAddsToProfilesArray() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = ProfileStore(configDirectoryURL: { configDir })
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "gdrive", path: "/backup")
        )

        try store.save(profile)
        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].id == profile.id)
    }

    @Test @MainActor func saveUpdatesExistingProfile() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = ProfileStore(configDirectoryURL: { configDir })
        var profile = Profile(
            name: "Original",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "gdrive", path: "/backup")
        )

        try store.save(profile)
        profile.name = "Updated"
        try store.save(profile)

        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].name == "Updated")
    }

    @Test @MainActor func loadAllReadsFiles() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let profile = Profile(
            name: "Loaded",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "remote", path: "/")
        )
        let data = try JSONEncoder.cirrus.encode(profile)
        let fileURL = configDir
            .appendingPathComponent("profiles")
            .appendingPathComponent("\(profile.id.uuidString.lowercased()).json")
        try data.write(to: fileURL)

        let store = ProfileStore(configDirectoryURL: { configDir })
        store.loadAll()

        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].name == "Loaded")
    }

    @Test @MainActor func loadAllSkipsInvalidJSON() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        // Write valid profile
        let profile = Profile(
            name: "Valid",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "remote", path: "/")
        )
        let data = try JSONEncoder.cirrus.encode(profile)
        try data.write(to: configDir.appendingPathComponent("profiles/valid.json"))

        // Write invalid JSON
        try Data("not json".utf8).write(to: configDir.appendingPathComponent("profiles/invalid.json"))

        let store = ProfileStore(configDirectoryURL: { configDir })
        store.loadAll()

        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].name == "Valid")
    }

    @Test @MainActor func loadAllIgnoresNonJSONFiles() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        try Data("readme".utf8).write(to: configDir.appendingPathComponent("profiles/README.txt"))

        let store = ProfileStore(configDirectoryURL: { configDir })
        store.loadAll()

        #expect(store.profiles.isEmpty)
    }

    @Test @MainActor func deleteRemovesFileAndProfile() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = ProfileStore(configDirectoryURL: { configDir })
        let profile = Profile(
            name: "ToDelete",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "remote", path: "/")
        )

        try store.save(profile)
        #expect(store.profiles.count == 1)

        try store.delete(profile)
        #expect(store.profiles.isEmpty)

        let fileURL = configDir
            .appendingPathComponent("profiles")
            .appendingPathComponent("\(profile.id.uuidString.lowercased()).json")
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test @MainActor func profileForIdReturnsMatch() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = ProfileStore(configDirectoryURL: { configDir })
        let profile = Profile(
            name: "Lookup",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "remote", path: "/")
        )

        try store.save(profile)
        let found = store.profile(for: profile.id)
        #expect(found?.name == "Lookup")
    }

    @Test @MainActor func profileForIdReturnsNilForUnknown() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = ProfileStore(configDirectoryURL: { configDir })
        #expect(store.profile(for: UUID()) == nil)
    }

    @Test @MainActor func loadAllSortsBySortOrder() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let p1 = Profile(name: "Third", source: Endpoint(remoteName: "", path: "/tmp"), destination: Endpoint(remoteName: "r", path: "/"), sortOrder: 3)
        let p2 = Profile(name: "First", source: Endpoint(remoteName: "", path: "/tmp"), destination: Endpoint(remoteName: "r", path: "/"), sortOrder: 1)
        let p3 = Profile(name: "Second", source: Endpoint(remoteName: "", path: "/tmp"), destination: Endpoint(remoteName: "r", path: "/"), sortOrder: 2)

        for p in [p1, p2, p3] {
            let data = try JSONEncoder.cirrus.encode(p)
            try data.write(to: configDir.appendingPathComponent("profiles/\(p.id.uuidString.lowercased()).json"))
        }

        let store = ProfileStore(configDirectoryURL: { configDir })
        store.loadAll()

        #expect(store.profiles[0].name == "First")
        #expect(store.profiles[1].name == "Second")
        #expect(store.profiles[2].name == "Third")
    }

    @Test @MainActor func loadAllWithEmptyDirectoryReturnsEmpty() {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = ProfileStore(configDirectoryURL: { configDir })
        store.loadAll()

        #expect(store.profiles.isEmpty)
    }

    @Test @MainActor func saveUpdatesTimestamp() throws {
        let configDir = makeTempConfigDir()
        defer { cleanup(configDir) }

        let store = ProfileStore(configDirectoryURL: { configDir })
        let earlyDate = Date(timeIntervalSince1970: 1000000)
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "r", path: "/"),
            updatedAt: earlyDate
        )

        try store.save(profile)
        #expect(store.profiles[0].updatedAt > earlyDate)
    }
}
