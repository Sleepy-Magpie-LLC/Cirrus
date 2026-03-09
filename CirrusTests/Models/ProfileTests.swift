import Testing
@testable import Cirrus
import Foundation

struct ProfileTests {
    @Test func codableRoundTrip() throws {
        let profile = Profile(
            name: "Test Profile",
            source: Endpoint(remoteName: "", path: "/Users/test/Documents"),
            destination: Endpoint(remoteName: "gdrive", path: "/backup"),
            action: .sync,
            ignorePatterns: [".DS_Store", "*.tmp"],
            extraFlags: "--verbose",
            schedule: CronSchedule(expression: "0 * * * *"),
            groupName: "daily",
            sortOrder: 1
        )

        let data = try JSONEncoder.cirrus.encode(profile)
        let decoded = try JSONDecoder.cirrus.decode(Profile.self, from: data)

        #expect(decoded.id == profile.id)
        #expect(decoded.name == profile.name)
        #expect(decoded.source == profile.source)
        #expect(decoded.destination == profile.destination)
        #expect(decoded.action == profile.action)
        #expect(decoded.ignorePatterns == profile.ignorePatterns)
        #expect(decoded.extraFlags == profile.extraFlags)
        #expect(decoded.schedule == profile.schedule)
        #expect(decoded.groupName == profile.groupName)
        #expect(decoded.sortOrder == profile.sortOrder)
    }

    @Test func codableRoundTripWithNilOptionals() throws {
        let profile = Profile(
            name: "Minimal",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "remote", path: "/"),
            action: .copy
        )

        let data = try JSONEncoder.cirrus.encode(profile)
        let decoded = try JSONDecoder.cirrus.decode(Profile.self, from: data)

        #expect(decoded.schedule == nil)
        #expect(decoded.groupName == nil)
        #expect(decoded.ignorePatterns.isEmpty)
        #expect(decoded.extraFlags == "")
    }

    @Test func legacyJSONDecoding() throws {
        // Simulate old-format JSON with sourcePath/remoteName/remotePath
        let legacyJSON = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "Legacy Profile",
            "sourcePath": "/Users/test/Documents",
            "remoteName": "gdrive",
            "remotePath": "backup",
            "action": "sync",
            "ignorePatterns": [],
            "extraFlags": "",
            "sortOrder": 0,
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z"
        }
        """
        let data = legacyJSON.data(using: .utf8)!
        let decoded = try JSONDecoder.cirrus.decode(Profile.self, from: data)

        #expect(decoded.source == Endpoint(remoteName: "", path: "/Users/test/Documents"))
        #expect(decoded.destination == Endpoint(remoteName: "gdrive", path: "backup"))
        #expect(decoded.name == "Legacy Profile")
    }

    @Test func rcloneActionRawValues() {
        #expect(RcloneAction.sync.rawValue == "sync")
        #expect(RcloneAction.copy.rawValue == "copy")
        #expect(RcloneAction.move.rawValue == "move")
        #expect(RcloneAction.delete.rawValue == "delete")
    }

    @Test func rcloneActionDisplayDescriptions() {
        #expect(RcloneAction.sync.displayDescription == "Sync")
        #expect(RcloneAction.copy.displayDescription == "Copy")
        #expect(RcloneAction.move.displayDescription == "Move")
        #expect(RcloneAction.delete.displayDescription == "Delete")
    }

    @Test func rcloneActionCaseIterable() {
        #expect(RcloneAction.allCases.count == 5)
    }

    @Test func profileIdentifiable() {
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "", path: "/tmp"),
            destination: Endpoint(remoteName: "r", path: "/")
        )
        let id: UUID = profile.id
        #expect(id == profile.id)
    }

    @Test func cronScheduleCodableRoundTrip() throws {
        let schedule = CronSchedule(expression: "0 */6 * * *", enabled: false)
        let data = try JSONEncoder.cirrus.encode(schedule)
        let decoded = try JSONDecoder.cirrus.decode(CronSchedule.self, from: data)

        #expect(decoded.expression == "0 */6 * * *")
        #expect(decoded.enabled == false)
    }

    @Test func jobStatusRawValues() {
        #expect(JobStatus.idle.rawValue == "idle")
        #expect(JobStatus.running.rawValue == "running")
        #expect(JobStatus.success.rawValue == "success")
        #expect(JobStatus.failed.rawValue == "failed")
        #expect(JobStatus.canceled.rawValue == "canceled")
    }

    // MARK: - Endpoint

    @Test func endpointIsLocal() {
        let local = Endpoint(remoteName: "", path: "/tmp")
        #expect(local.isLocal)

        let remote = Endpoint(remoteName: "gdrive", path: "backup")
        #expect(!remote.isLocal)
    }

    @Test func endpointFormatted() {
        #expect(Endpoint(remoteName: "", path: "/tmp").formatted == "/tmp")
        #expect(Endpoint(remoteName: "gdrive", path: "backup").formatted == "gdrive:backup")
        #expect(Endpoint(remoteName: "gdrive", path: "").formatted == "gdrive:")
    }

    @Test func endpointDisplayString() {
        #expect(Endpoint(remoteName: "", path: "/tmp").displayString == "/tmp")
        #expect(Endpoint(remoteName: "", path: "").displayString == "(no path)")
        #expect(Endpoint(remoteName: "gdrive", path: "backup").displayString == "gdrive:backup")
        #expect(Endpoint(remoteName: "gdrive", path: "").displayString == "gdrive:")
    }

    @Test func endpointEmpty() {
        let empty = Endpoint.empty
        #expect(empty.remoteName == "")
        #expect(empty.path == "")
        #expect(empty.isLocal)
    }
}
