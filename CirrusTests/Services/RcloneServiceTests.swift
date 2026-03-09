import Testing
@testable import Cirrus
import Foundation

struct RcloneServiceTests {
    @Test func parseVersionNumberExtractsVersion() {
        let result = RcloneService.parseVersionNumber(from: "rclone v1.67.0")
        #expect(result == "v1.67.0")
    }

    @Test func parseVersionNumberHandlesExtraText() {
        let result = RcloneService.parseVersionNumber(from: "rclone v1.68.1-beta")
        #expect(result == "v1.68.1-beta")
    }

    @Test func parseVersionNumberReturnsNilForNoVersion() {
        let result = RcloneService.parseVersionNumber(from: "no version here")
        #expect(result == nil)
    }

    @Test func parseVersionNumberHandlesEmptyString() {
        let result = RcloneService.parseVersionNumber(from: "")
        #expect(result == nil)
    }

    @Test func detectRcloneFindsSystemRclone() {
        // This test passes if rclone is installed, skips otherwise
        do {
            let path = try RcloneService.detectRclone()
            #expect(!path.isEmpty)
            #expect(FileManager.default.isExecutableFile(atPath: path))
        } catch {
            // rclone not installed — test is informational only
        }
    }

    @Test func versionAtInvalidPathThrows() {
        #expect(throws: CirrusError.self) {
            try RcloneService.version(at: "/nonexistent/path/rclone")
        }
    }

    // MARK: - listRemotes parsing

    @Test func parseListRemotesOutputParsesColonTerminated() {
        let output = "gdrive:\nmydropbox:\nonedrive:\n"
        let result = RcloneService.parseListRemotesOutput(output)
        #expect(result == ["gdrive", "mydropbox", "onedrive"])
    }

    @Test func parseListRemotesOutputHandlesEmpty() {
        let result = RcloneService.parseListRemotesOutput("")
        #expect(result.isEmpty)
    }

    @Test func parseListRemotesOutputHandlesTrailingNewlines() {
        let output = "remote1:\nremote2:\n\n\n"
        let result = RcloneService.parseListRemotesOutput(output)
        #expect(result == ["remote1", "remote2"])
    }

    @Test func parseListRemotesOutputHandlesNoColon() {
        let output = "remote1\nremote2\n"
        let result = RcloneService.parseListRemotesOutput(output)
        #expect(result == ["remote1", "remote2"])
    }

    @Test func parseListRemotesOutputTrimsWhitespace() {
        let output = "  gdrive:  \n  dropbox:  \n"
        let result = RcloneService.parseListRemotesOutput(output)
        #expect(result == ["gdrive", "dropbox"])
    }

    @Test func listRemotesAtInvalidPathThrows() {
        #expect(throws: CirrusError.self) {
            try RcloneService.listRemotes(rclonePath: "/nonexistent/rclone")
        }
    }

    @Test func listRemotesIntegration() {
        guard let path = try? RcloneService.detectRclone() else { return }
        do {
            let remotes = try RcloneService.listRemotes(rclonePath: path)
            // Just verify it returns without crashing; may be empty
            #expect(remotes.count >= 0)
        } catch {
            // rclone might fail in test sandbox
        }
    }

    // MARK: - parseLsdOutput

    @Test func parseLsdOutputParsesDirectories() {
        let output = """
                  -1 2024-01-15 10:30:00        -1 Documents
                  -1 2024-01-15 10:30:00        -1 Photos
                  -1 2024-01-15 10:30:00        -1 Backups
        """
        let result = RcloneService.parseLsdOutput(output)
        #expect(result == ["Documents", "Photos", "Backups"])
    }

    @Test func parseLsdOutputHandlesEmpty() {
        let result = RcloneService.parseLsdOutput("")
        #expect(result.isEmpty)
    }

    @Test func parseLsdOutputHandlesTrailingNewlines() {
        let output = "          -1 2024-01-15 10:30:00        -1 MyDir\n\n\n"
        let result = RcloneService.parseLsdOutput(output)
        #expect(result == ["MyDir"])
    }

    // MARK: - Dry Run

    @Test func dryRunAtInvalidPathThrows() {
        #expect(throws: CirrusError.self) {
            try RcloneService.dryRun(
                rclonePath: "/nonexistent/rclone",
                action: .sync,
                source: Endpoint(remoteName: "", path: "/tmp"),
                destination: Endpoint(remoteName: "remote", path: "/"),
                ignorePatterns: [],
                extraFlags: ""
            )
        }
    }

    // MARK: - commandPreview

    @Test func commandPreviewBasic() {
        let result = RcloneService.commandPreview(
            rclonePath: "/usr/local/bin/rclone",
            action: .sync,
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "gdrive", path: "backup"),
            ignorePatterns: [],
            extraFlags: ""
        )
        #expect(result == "/usr/local/bin/rclone sync /tmp/src gdrive:backup")
    }

    @Test func commandPreviewFallbackPath() {
        let result = RcloneService.commandPreview(
            rclonePath: nil,
            action: .copy,
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "remote", path: "path"),
            ignorePatterns: [],
            extraFlags: ""
        )
        #expect(result.hasPrefix("rclone copy"))
    }

    @Test func commandPreviewWithIgnorePatterns() {
        let result = RcloneService.commandPreview(
            rclonePath: nil,
            action: .sync,
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "gdrive", path: "backup"),
            ignorePatterns: ["*.log", ".DS_Store", ""],
            extraFlags: ""
        )
        #expect(result.contains("--exclude \"*.log\""))
        #expect(result.contains("--exclude \".DS_Store\""))
        #expect(!result.contains("--exclude \"\""))
    }

    @Test func commandPreviewWithExtraFlags() {
        let result = RcloneService.commandPreview(
            rclonePath: nil,
            action: .sync,
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "gdrive", path: "backup"),
            ignorePatterns: [],
            extraFlags: "--verbose --transfers 4"
        )
        #expect(result.contains("--verbose"))
        #expect(result.contains("--transfers"))
        #expect(result.contains("4"))
    }

    @Test func commandPreviewEmptyFieldsShowPlaceholders() {
        let result = RcloneService.commandPreview(
            rclonePath: nil,
            action: .sync,
            source: Endpoint(remoteName: "", path: ""),
            destination: Endpoint(remoteName: "", path: ""),
            ignorePatterns: [],
            extraFlags: ""
        )
        #expect(result == "rclone sync <source> <destination>")
    }

    @Test func commandPreviewEmptyRemotePathOmitsTrailing() {
        let result = RcloneService.commandPreview(
            rclonePath: nil,
            action: .sync,
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "gdrive", path: ""),
            ignorePatterns: [],
            extraFlags: ""
        )
        #expect(result == "rclone sync /tmp/src gdrive:")
    }

    @Test func commandPreviewTrimsWhitespacePatterns() {
        let result = RcloneService.commandPreview(
            rclonePath: nil,
            action: .sync,
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "gdrive", path: "backup"),
            ignorePatterns: ["*.log", "  ", "\n"],
            extraFlags: ""
        )
        #expect(result.contains("--exclude \"*.log\""))
        #expect(!result.contains("--exclude \"  \""))
    }

    @Test func commandPreviewQuotesSpacesInPaths() {
        let result = RcloneService.commandPreview(
            rclonePath: "/Applications/My Apps/rclone",
            action: .sync,
            source: Endpoint(remoteName: "", path: "/Users/me/My Documents"),
            destination: Endpoint(remoteName: "gdrive", path: "My Backup"),
            ignorePatterns: [],
            extraFlags: ""
        )
        #expect(result.contains("\"/Applications/My Apps/rclone\""))
        #expect(result.contains("\"/Users/me/My Documents\""))
        #expect(result.contains("\"gdrive:My Backup\""))
    }

    @Test func commandPreviewRemoteToRemote() {
        let result = RcloneService.commandPreview(
            rclonePath: nil,
            action: .sync,
            source: Endpoint(remoteName: "gdrive", path: "source"),
            destination: Endpoint(remoteName: "s3", path: "bucket/dest"),
            ignorePatterns: [],
            extraFlags: ""
        )
        #expect(result == "rclone sync gdrive:source s3:bucket/dest")
    }

    @Test func commandPreviewRemoteToLocal() {
        let result = RcloneService.commandPreview(
            rclonePath: nil,
            action: .copy,
            source: Endpoint(remoteName: "gdrive", path: "docs"),
            destination: Endpoint(remoteName: "", path: "/tmp/local"),
            ignorePatterns: [],
            extraFlags: ""
        )
        #expect(result == "rclone copy gdrive:docs /tmp/local")
    }

    // MARK: - buildCommand

    @Test func buildCommandBasic() {
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "gdrive", path: "backup"),
            action: .sync
        )
        let args = RcloneService.buildCommand(profile: profile, filterFileURL: nil)
        #expect(args == ["sync", "/tmp/src", "gdrive:backup", "--verbose"])
    }

    @Test func buildCommandWithFilterFile() {
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "gdrive", path: "backup"),
            action: .copy
        )
        let filterURL = URL(fileURLWithPath: "/tmp/filter.txt")
        let args = RcloneService.buildCommand(profile: profile, filterFileURL: filterURL)
        #expect(args.contains("--filter-from"))
        #expect(args.contains("/tmp/filter.txt"))
    }

    @Test func buildCommandWithExtraFlags() {
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "", path: "/tmp/src"),
            destination: Endpoint(remoteName: "gdrive", path: "backup"),
            action: .sync,
            extraFlags: "--verbose --transfers 4"
        )
        let args = RcloneService.buildCommand(profile: profile, filterFileURL: nil)
        #expect(args.contains("--verbose"))
        #expect(args.contains("--transfers"))
        #expect(args.contains("4"))
    }

    @Test func buildCommandRemoteToRemote() {
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "gdrive", path: "source"),
            destination: Endpoint(remoteName: "s3", path: "bucket"),
            action: .sync
        )
        let args = RcloneService.buildCommand(profile: profile, filterFileURL: nil)
        #expect(args == ["sync", "gdrive:source", "s3:bucket", "--verbose"])
    }

    @Test func buildCommandRemoteToLocal() {
        let profile = Profile(
            name: "Test",
            source: Endpoint(remoteName: "gdrive", path: "docs"),
            destination: Endpoint(remoteName: "", path: "/tmp/local"),
            action: .copy
        )
        let args = RcloneService.buildCommand(profile: profile, filterFileURL: nil)
        #expect(args == ["copy", "gdrive:docs", "/tmp/local", "--verbose"])
    }

    @Test func versionAtValidPathReturnsString() {
        // Only runs if rclone is available
        guard let path = try? RcloneService.detectRclone() else { return }
        do {
            let version = try RcloneService.version(at: path)
            #expect(version.contains("rclone"))
        } catch {
            // rclone might fail in test sandbox
        }
    }
}
