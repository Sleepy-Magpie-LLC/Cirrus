import Foundation
import os

@MainActor @Observable
final class ProfileStore {
    private(set) var profiles: [Profile] = []
    private let configDirectoryURL: () -> URL

    private static let logger = Logger(subsystem: "com.sane.cirrus", category: "ProfileStore")

    init(configDirectoryURL: @escaping () -> URL) {
        self.configDirectoryURL = configDirectoryURL
    }

    private var profilesDirectory: URL {
        configDirectoryURL().appendingPathComponent("profiles")
    }

    func loadAll() {
        let fileManager = FileManager.default
        let dir = profilesDirectory

        guard fileManager.fileExists(atPath: dir.path) else {
            profiles = []
            return
        }

        var loaded: [Profile] = []
        guard let urls = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else {
            profiles = []
            return
        }

        for url in urls where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let profile = try JSONDecoder.cirrus.decode(Profile.self, from: data)
                loaded.append(profile)
            } catch {
                Self.logger.warning("Skipping invalid profile at \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        profiles = loaded.sorted { $0.sortOrder < $1.sortOrder }
    }

    func save(_ profile: Profile) throws {
        var updated = profile
        updated.updatedAt = Date()

        let url = profilesDirectory.appendingPathComponent("\(updated.id.uuidString.lowercased()).json")
        let data = try JSONEncoder.cirrus.encode(updated)
        try AtomicFileWriter.write(data, to: url)

        if let index = profiles.firstIndex(where: { $0.id == updated.id }) {
            profiles[index] = updated
        } else {
            profiles.append(updated)
        }
        profiles.sort { $0.sortOrder < $1.sortOrder }
    }

    func delete(_ profile: Profile) throws {
        let url = profilesDirectory.appendingPathComponent("\(profile.id.uuidString.lowercased()).json")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }

        profiles.removeAll { $0.id == profile.id }
    }

    func profile(for id: UUID) -> Profile? {
        profiles.first { $0.id == id }
    }
}
