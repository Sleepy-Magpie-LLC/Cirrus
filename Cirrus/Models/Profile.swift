import Foundation

struct Endpoint: Codable, Equatable {
    var remoteName: String
    var path: String

    static let empty = Endpoint(remoteName: "", path: "")

    var isLocal: Bool { remoteName.isEmpty }

    /// Returns `remote:path` for remote endpoints, or just `path` for local.
    var formatted: String {
        if isLocal {
            return path
        }
        return path.isEmpty ? "\(remoteName):" : "\(remoteName):\(path)"
    }

    /// Human-readable display string for UI labels.
    var displayString: String {
        if isLocal {
            return path.isEmpty ? "(no path)" : path
        }
        return formatted
    }
}

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var source: Endpoint
    var destination: Endpoint
    var action: RcloneAction
    var ignorePatterns: [String]
    var extraFlags: String
    var schedule: CronSchedule?
    var groupName: String?
    var logRetentionDays: Int?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        source: Endpoint,
        destination: Endpoint,
        action: RcloneAction = .sync,
        ignorePatterns: [String] = [],
        extraFlags: String = "",
        schedule: CronSchedule? = nil,
        logRetentionDays: Int? = nil,
        groupName: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.destination = destination
        self.action = action
        self.ignorePatterns = ignorePatterns
        self.extraFlags = extraFlags
        self.schedule = schedule
        self.logRetentionDays = logRetentionDays
        self.groupName = groupName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Backward-compatible decoding

    private enum CodingKeys: String, CodingKey {
        case id, name, source, destination, action, ignorePatterns, extraFlags
        case schedule, logRetentionDays, groupName, sortOrder, createdAt, updatedAt
        // Legacy keys
        case sourcePath, remoteName, remotePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        // Try new format first, fall back to legacy
        if let src = try? container.decode(Endpoint.self, forKey: .source),
           let dst = try? container.decode(Endpoint.self, forKey: .destination) {
            source = src
            destination = dst
        } else {
            let sourcePath = try container.decodeIfPresent(String.self, forKey: .sourcePath) ?? ""
            let remoteName = try container.decodeIfPresent(String.self, forKey: .remoteName) ?? ""
            let remotePath = try container.decodeIfPresent(String.self, forKey: .remotePath) ?? ""
            source = Endpoint(remoteName: "", path: sourcePath)
            destination = Endpoint(remoteName: remoteName, path: remotePath)
        }

        action = try container.decode(RcloneAction.self, forKey: .action)
        ignorePatterns = try container.decodeIfPresent([String].self, forKey: .ignorePatterns) ?? []
        extraFlags = try container.decodeIfPresent(String.self, forKey: .extraFlags) ?? ""
        schedule = try container.decodeIfPresent(CronSchedule.self, forKey: .schedule)
        logRetentionDays = try container.decodeIfPresent(Int.self, forKey: .logRetentionDays)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(source, forKey: .source)
        try container.encode(destination, forKey: .destination)
        try container.encode(action, forKey: .action)
        try container.encode(ignorePatterns, forKey: .ignorePatterns)
        try container.encode(extraFlags, forKey: .extraFlags)
        try container.encodeIfPresent(schedule, forKey: .schedule)
        try container.encodeIfPresent(logRetentionDays, forKey: .logRetentionDays)
        try container.encodeIfPresent(groupName, forKey: .groupName)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

enum RcloneAction: String, Codable, CaseIterable {
    case sync, copy, move, delete, bisync

    var displayDescription: String {
        switch self {
        case .sync: "Sync"
        case .copy: "Copy"
        case .move: "Move"
        case .delete: "Delete"
        case .bisync: "Bisync"
        }
    }
}
