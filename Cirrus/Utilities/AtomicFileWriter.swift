import Foundation

struct AtomicFileWriter {
    static func write(_ data: Data, to url: URL) throws {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw CirrusError.configDirectoryInaccessible(path: directory.path)
            }
        }

        let tempURL = url.appendingPathExtension("tmp")

        do {
            try data.write(to: tempURL)
        } catch {
            throw CirrusError.profileSaveFailed(underlying: error)
        }

        do {
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
        } catch {
            // Clean up temp file on failure
            try? fileManager.removeItem(at: tempURL)
            throw CirrusError.profileSaveFailed(underlying: error)
        }
    }
}
