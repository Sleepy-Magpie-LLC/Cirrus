import Foundation

struct LogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let profileId: UUID
    let startedAt: Date
    var completedAt: Date?
    var status: JobStatus
    var durationSeconds: Double?
    let logFileName: String
    var command: String?
    var action: RcloneAction?

    init(
        id: UUID = UUID(),
        profileId: UUID,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        status: JobStatus = .running,
        durationSeconds: Double? = nil,
        logFileName: String,
        command: String? = nil,
        action: RcloneAction? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.durationSeconds = durationSeconds
        self.logFileName = logFileName
        self.command = command
        self.action = action
    }
}
