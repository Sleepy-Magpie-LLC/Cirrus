import Testing
@testable import Cirrus
import Foundation

struct FilterFileWriterTests {
    @Test func writeCreatesFile() throws {
        let url = try FilterFileWriter.write(patterns: ["*.tmp", ".DS_Store"])
        defer { FilterFileWriter.cleanup(at: url) }

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func writeFormatsAsFilterRules() throws {
        let url = try FilterFileWriter.write(patterns: ["*.tmp", ".DS_Store"])
        defer { FilterFileWriter.cleanup(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("- *.tmp"))
        #expect(content.contains("- .DS_Store"))
    }

    @Test func writeSkipsEmptyPatterns() throws {
        let url = try FilterFileWriter.write(patterns: ["*.tmp", "", "*.log"])
        defer { FilterFileWriter.cleanup(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 2)
    }

    @Test func cleanupRemovesFile() throws {
        let url = try FilterFileWriter.write(patterns: ["*.tmp"])
        #expect(FileManager.default.fileExists(atPath: url.path))

        FilterFileWriter.cleanup(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func cleanupNonexistentFileDoesNotThrow() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.txt")
        FilterFileWriter.cleanup(at: url)
    }
}
