import Foundation

final class JobRun {
    let profileId: UUID
    let profileSnapshot: Profile
    let process: Process
    let startedAt: Date
    var status: JobStatus
    nonisolated(unsafe) var isCancelled: Bool = false
    let logFileURL: URL
    let logEntryId: UUID
    var filterFileURL: URL?

    init(
        profileId: UUID,
        profileSnapshot: Profile,
        process: Process,
        startedAt: Date = Date(),
        status: JobStatus = .running,
        logFileURL: URL,
        logEntryId: UUID,
        filterFileURL: URL? = nil
    ) {
        self.profileId = profileId
        self.profileSnapshot = profileSnapshot
        self.process = process
        self.startedAt = startedAt
        self.status = status
        self.logFileURL = logFileURL
        self.logEntryId = logEntryId
        self.filterFileURL = filterFileURL
    }
}
