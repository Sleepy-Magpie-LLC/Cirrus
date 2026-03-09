import Testing
@testable import Cirrus
import Foundation

struct AppSettingsModelTests {
    @Test func codableRoundTrip() throws {
        let original = AppSettingsModel(rclonePath: "/usr/local/bin/rclone", configDirectory: "~/.config/cirrus")
        let data = try JSONEncoder.cirrus.encode(original)
        let decoded = try JSONDecoder.cirrus.decode(AppSettingsModel.self, from: data)
        #expect(decoded == original)
    }

    @Test func defaultValues() {
        let settings = AppSettingsModel()
        #expect(settings.rclonePath == nil)
        #expect(settings.configDirectory == "~/.config/cirrus")
    }

    @Test func codableRoundTripWithNilRclonePath() throws {
        let original = AppSettingsModel(rclonePath: nil, configDirectory: "/custom/path")
        let data = try JSONEncoder.cirrus.encode(original)
        let decoded = try JSONDecoder.cirrus.decode(AppSettingsModel.self, from: data)
        #expect(decoded == original)
        #expect(decoded.rclonePath == nil)
    }

    @Test func customConfigDirectory() {
        let settings = AppSettingsModel(configDirectory: "/custom/path")
        #expect(settings.configDirectory == "/custom/path")
    }
}
