import Testing
@testable import Cirrus
import Foundation

struct AtomicFileWriterTests {
    private func makeTempURL(filename: String = "test.json") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(filename)
    }

    private func cleanup(_ url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func writesFileToDestination() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        let data = Data("hello".utf8)
        try AtomicFileWriter.write(data, to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let read = try Data(contentsOf: url)
        #expect(read == data)
    }

    @Test func createsParentDirectories() throws {
        let url = makeTempURL(filename: "nested/deep/file.json")
        defer { cleanup(url) }

        let data = Data("test".utf8)
        try AtomicFileWriter.write(data, to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func overwritesExistingFile() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        try AtomicFileWriter.write(Data("first".utf8), to: url)
        try AtomicFileWriter.write(Data("second".utf8), to: url)

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == "second")
    }

    @Test func noTempFileLeftAfterSuccess() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        try AtomicFileWriter.write(Data("test".utf8), to: url)

        let tempURL = url.appendingPathExtension("tmp")
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
    }

    @Test func writeToReadOnlyDirectoryThrows() throws {
        let url = URL(fileURLWithPath: "/System/test_\(UUID().uuidString).json")
        #expect(throws: CirrusError.self) {
            try AtomicFileWriter.write(Data("test".utf8), to: url)
        }
    }
}
