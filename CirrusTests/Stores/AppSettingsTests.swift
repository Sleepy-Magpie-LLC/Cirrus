import Testing
@testable import Cirrus
import Foundation

struct AppSettingsTests {
    private func makeTempConfigDir() -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("cirrus-test-\(UUID().uuidString)")
            .path
        return path
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test @MainActor func loadWithMissingFileUsesDefaults() throws {
        let tempDir = makeTempConfigDir()
        defer { cleanup(tempDir) }

        let appSettings = AppSettings(configDirectory: tempDir)
        try appSettings.load()

        // configDirectory should remain as set
        #expect(appSettings.settings.configDirectory == tempDir)

        // rclonePath may be auto-detected if rclone is installed on the system
        if let path = appSettings.settings.rclonePath {
            #expect(FileManager.default.isExecutableFile(atPath: path))
        }
    }

    @Test @MainActor func saveThenLoadProducesIdenticalSettings() throws {
        let tempDir = makeTempConfigDir()
        defer { cleanup(tempDir) }

        let appSettings = AppSettings(configDirectory: tempDir)
        try appSettings.update { settings in
            settings.rclonePath = "/usr/local/bin/rclone"
        }

        let saved = appSettings.settings

        let loader = AppSettings(configDirectory: tempDir)
        try loader.load()

        #expect(loader.settings.rclonePath == saved.rclonePath)
        #expect(loader.settings.configDirectory == saved.configDirectory)
    }

    @Test @MainActor func configDirectoryURLExpandsTilde() {
        let appSettings = AppSettings()
        let url = appSettings.configDirectoryURL
        #expect(!url.path.contains("~"))
    }

    @Test @MainActor func configDirectoryURLUsesSettingsValue() {
        let tempDir = makeTempConfigDir()
        defer { cleanup(tempDir) }

        let appSettings = AppSettings(configDirectory: tempDir)
        #expect(appSettings.configDirectoryURL.path == tempDir)
    }

    @Test @MainActor func ensureDirectoryStructureCreatesSubdirectories() throws {
        let tempDir = makeTempConfigDir()
        defer { cleanup(tempDir) }

        let appSettings = AppSettings(configDirectory: tempDir)
        try appSettings.save()

        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: tempDir))
        #expect(fileManager.fileExists(atPath: (tempDir as NSString).appendingPathComponent("profiles")))
        #expect(fileManager.fileExists(atPath: (tempDir as NSString).appendingPathComponent("logs/runs")))
    }
}
