import Foundation

struct FilterFileWriter {
    static func write(patterns: [String]) throws -> URL {
        let fileName = "cirrus-filter-\(UUID().uuidString).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let content = patterns
            .filter { !$0.isEmpty }
            .map { "- \($0)" }
            .joined(separator: "\n")

        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func cleanup(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
