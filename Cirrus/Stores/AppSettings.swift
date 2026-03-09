import Foundation

@MainActor @Observable
final class AppSettings {
    private(set) var settings: AppSettingsModel
    private(set) var rcloneVersion: String?

    init(configDirectory: String = "~/.config/cirrus") {
        self.settings = AppSettingsModel(configDirectory: configDirectory)
    }

    var configDirectoryURL: URL {
        let path = (settings.configDirectory as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    var hasRclone: Bool {
        settings.rclonePath != nil
    }

    private var settingsFileURL: URL {
        configDirectoryURL.appendingPathComponent("settings.json")
    }

    func load() throws {
        let fileManager = FileManager.default
        ensureDirectoryStructure()

        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            // First launch — try auto-detecting rclone
            detectRcloneIfNeeded()
            return
        }

        let data = try Data(contentsOf: settingsFileURL)
        settings = try JSONDecoder.cirrus.decode(AppSettingsModel.self, from: data)
        refreshRcloneVersion()
    }

    private func detectRcloneIfNeeded() {
        guard settings.rclonePath == nil else { return }
        if let path = try? RcloneService.detectRclone() {
            settings.rclonePath = path
            refreshRcloneVersion()
            try? save()
        }
    }

    func refreshRcloneVersion() {
        guard let path = settings.rclonePath else {
            rcloneVersion = nil
            return
        }
        rcloneVersion = try? RcloneService.version(at: path)
    }

    func save() throws {
        ensureDirectoryStructure()
        let data = try JSONEncoder.cirrus.encode(settings)
        try AtomicFileWriter.write(data, to: settingsFileURL)
    }

    func update(_ transform: (inout AppSettingsModel) -> Void) throws {
        transform(&settings)
        try save()
    }

    private func ensureDirectoryStructure() {
        let fileManager = FileManager.default
        let dirs = [
            configDirectoryURL,
            configDirectoryURL.appendingPathComponent("profiles"),
            configDirectoryURL.appendingPathComponent("logs/runs"),
        ]
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}
