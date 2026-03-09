import Foundation

struct AppSettingsModel: Codable, Equatable {
    var rclonePath: String?
    var configDirectory: String
    var showWindowOnLaunch: Bool?

    init(rclonePath: String? = nil, configDirectory: String = "~/.config/cirrus", showWindowOnLaunch: Bool? = nil) {
        self.rclonePath = rclonePath
        self.configDirectory = configDirectory
        self.showWindowOnLaunch = showWindowOnLaunch
    }
}
