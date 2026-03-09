import Testing
@testable import Cirrus
import Foundation

struct RcloneCommandParserTests {
    // MARK: - Basic Commands

    @Test func parseBasicSyncCommand() {
        let result = RcloneCommandParser.parse("rclone sync ~/docs gdrive:backup")
        #expect(result.action == .sync)
        #expect(result.source == Endpoint(remoteName: "", path: "~/docs"))
        #expect(result.destination == Endpoint(remoteName: "gdrive", path: "backup"))
        #expect(result.warnings.isEmpty)
    }

    @Test func parseCopyCommand() {
        let result = RcloneCommandParser.parse("rclone copy /data remote:archive")
        #expect(result.action == .copy)
        #expect(result.source == Endpoint(remoteName: "", path: "/data"))
        #expect(result.destination == Endpoint(remoteName: "remote", path: "archive"))
    }

    @Test func parseMoveCommand() {
        let result = RcloneCommandParser.parse("rclone move ~/photos s3:bucket/photos")
        #expect(result.action == .move)
        #expect(result.source == Endpoint(remoteName: "", path: "~/photos"))
        #expect(result.destination == Endpoint(remoteName: "s3", path: "bucket/photos"))
    }

    @Test func parseDeleteCommand() {
        let result = RcloneCommandParser.parse("rclone delete remote:old-data")
        #expect(result.action == .delete)
        #expect(result.source == Endpoint(remoteName: "remote", path: "old-data"))
    }

    // MARK: - Without rclone Prefix

    @Test func parseWithoutRclonePrefix() {
        let result = RcloneCommandParser.parse("sync ~/docs gdrive:backup")
        #expect(result.action == .sync)
        #expect(result.source == Endpoint(remoteName: "", path: "~/docs"))
        #expect(result.destination == Endpoint(remoteName: "gdrive", path: "backup"))
    }

    // MARK: - Remote-to-Remote

    @Test func parseRemoteToRemote() {
        let result = RcloneCommandParser.parse("rclone sync gdrive:source s3:bucket/dest")
        #expect(result.action == .sync)
        #expect(result.source == Endpoint(remoteName: "gdrive", path: "source"))
        #expect(result.destination == Endpoint(remoteName: "s3", path: "bucket/dest"))
    }

    // MARK: - Remote-to-Local

    @Test func parseRemoteToLocal() {
        let result = RcloneCommandParser.parse("rclone copy gdrive:docs /tmp/local")
        #expect(result.action == .copy)
        #expect(result.source == Endpoint(remoteName: "gdrive", path: "docs"))
        #expect(result.destination == Endpoint(remoteName: "", path: "/tmp/local"))
    }

    // MARK: - Exclude Flags

    @Test func parseWithExcludeFlags() {
        let result = RcloneCommandParser.parse(
            "rclone copy ~/photos remote:pics --exclude \"*.tmp\" --exclude \".DS_Store\""
        )
        #expect(result.action == .copy)
        #expect(result.ignorePatterns == ["*.tmp", ".DS_Store"])
        #expect(result.extraFlags.isEmpty)
    }

    @Test func parseWithExcludeEqualsFlags() {
        let result = RcloneCommandParser.parse(
            "rclone sync /data remote:bak --exclude=*.log --exclude=\"*.tmp\""
        )
        #expect(result.ignorePatterns == ["*.log", "*.tmp"])
    }

    @Test func parseWithFilterFlags() {
        let result = RcloneCommandParser.parse(
            "rclone sync /data remote:bak --filter \"- *.log\" --filter \"+ *.txt\""
        )
        #expect(result.ignorePatterns == ["- *.log", "+ *.txt"])
    }

    @Test func parseWithFilterFromFlag() {
        let result = RcloneCommandParser.parse(
            "rclone sync /data remote:bak --filter-from /path/to/rules"
        )
        #expect(result.warnings.contains("--filter-from not supported, add patterns manually"))
    }

    // MARK: - Extra Flags

    @Test func parseWithExtraFlags() {
        let result = RcloneCommandParser.parse(
            "rclone sync /data s3:bucket --verbose --dry-run"
        )
        #expect(result.action == .sync)
        #expect(result.extraFlags == "--verbose --dry-run")
    }

    @Test func parseWithFlagEqualsValue() {
        let result = RcloneCommandParser.parse(
            "rclone sync /data remote:bak --bwlimit=10M --transfers=4"
        )
        #expect(result.extraFlags == "--bwlimit=10M --transfers=4")
    }

    @Test func parseMixedExcludesAndFlags() {
        let result = RcloneCommandParser.parse(
            "rclone sync /data remote:bak --exclude \"*.tmp\" --verbose --exclude \"*.log\" --dry-run"
        )
        #expect(result.ignorePatterns == ["*.tmp", "*.log"])
        #expect(result.extraFlags == "--verbose --dry-run")
    }

    // MARK: - Quoted Paths

    @Test func parseQuotedPaths() {
        let result = RcloneCommandParser.parse(
            "rclone sync \"/path with spaces\" gdrive:\"folder name\""
        )
        #expect(result.source == Endpoint(remoteName: "", path: "/path with spaces"))
        #expect(result.destination == Endpoint(remoteName: "gdrive", path: "folder name"))
    }

    @Test func parseSingleQuotedPaths() {
        let result = RcloneCommandParser.parse(
            "rclone sync '/path with spaces' remote:dest"
        )
        #expect(result.source?.path == "/path with spaces")
    }

    @Test func parseEscapedSpaces() {
        let result = RcloneCommandParser.parse(
            "rclone sync /path\\ with\\ spaces remote:dest"
        )
        #expect(result.source?.path == "/path with spaces")
    }

    // MARK: - Edge Cases

    @Test func parseEmptyCommand() {
        let result = RcloneCommandParser.parse("")
        #expect(result.action == nil)
        #expect(result.warnings.contains("Empty command"))
    }

    @Test func parseOnlyRclone() {
        let result = RcloneCommandParser.parse("rclone")
        #expect(result.action == nil)
        #expect(result.warnings.contains("No action specified"))
    }

    @Test func parseUnknownAction() {
        let result = RcloneCommandParser.parse("rclone unknown ~/docs remote:bak")
        #expect(result.action == nil)
        #expect(result.warnings.first?.contains("Unknown action") == true)
        #expect(result.source?.path == "~/docs")
    }

    @Test func parseMultipleSpaces() {
        let result = RcloneCommandParser.parse("rclone   sync   ~/docs   gdrive:backup")
        #expect(result.action == .sync)
        #expect(result.source?.path == "~/docs")
        #expect(result.destination?.remoteName == "gdrive")
    }

    @Test func parseRemoteWithNoPath() {
        let result = RcloneCommandParser.parse("rclone sync ~/docs gdrive:")
        #expect(result.destination?.remoteName == "gdrive")
        #expect(result.destination?.path == "")
    }

    @Test func parseRemoteWithDeepPath() {
        let result = RcloneCommandParser.parse("rclone sync ~/docs gdrive:a/b/c/d")
        #expect(result.destination?.remoteName == "gdrive")
        #expect(result.destination?.path == "a/b/c/d")
    }

    // MARK: - Tokenizer

    @Test func tokenizeSimple() {
        let tokens = RcloneCommandParser.tokenize("hello world")
        #expect(tokens == ["hello", "world"])
    }

    @Test func tokenizeQuoted() {
        let tokens = RcloneCommandParser.tokenize("\"hello world\" foo")
        #expect(tokens == ["hello world", "foo"])
    }

    @Test func tokenizeSingleQuoted() {
        let tokens = RcloneCommandParser.tokenize("'hello world' foo")
        #expect(tokens == ["hello world", "foo"])
    }

    @Test func tokenizeEscaped() {
        let tokens = RcloneCommandParser.tokenize("hello\\ world foo")
        #expect(tokens == ["hello world", "foo"])
    }

    @Test func tokenizeMultipleSpaces() {
        let tokens = RcloneCommandParser.tokenize("  hello   world  ")
        #expect(tokens == ["hello", "world"])
    }

    // MARK: - Line Continuations

    @Test func parseMultilineCommandWithBackslashContinuations() {
        let command = """
        rclone sync "$SRC" "$DEST" \\
          --progress \\
          --exclude ".DS_Store" \\
          --exclude "node_modules/**" \\
          --exclude ".git/**"
        """
        let result = RcloneCommandParser.parse(command)
        #expect(result.action == .sync)
        #expect(result.ignorePatterns == [".DS_Store", "node_modules/**", ".git/**"])
        #expect(result.extraFlags == "--progress")
    }

    @Test func tokenizeBackslashNewlineContinuation() {
        let tokens = RcloneCommandParser.tokenize("hello \\\nworld")
        #expect(tokens == ["hello", "world"])
    }

    // MARK: - Performance

    @Test func parsePerformanceComplexCommand() {
        let command = "rclone sync /very/long/path/to/source remote:deep/nested/path " +
            (0..<50).map { "--exclude \"pattern_\($0)\"" }.joined(separator: " ") +
            " --verbose --dry-run --bwlimit=10M --transfers=4"

        let start = Date()
        let result = RcloneCommandParser.parse(command)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 1.0)
        #expect(result.ignorePatterns.count == 50)
    }
}
