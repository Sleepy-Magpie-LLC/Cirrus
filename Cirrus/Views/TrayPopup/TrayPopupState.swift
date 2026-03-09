import Foundation

@MainActor @Observable
final class TrayPopupState {
    var profiles: [Profile] = []
    var activeJobs: [UUID: JobRun] = [:]
    var logEntries: [LogEntry] = []
    var isNetworkConnected: Bool = true
    var errorMessage: String?
    var isNetworkError = false
}
