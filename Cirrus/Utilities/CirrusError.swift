import Foundation

enum CirrusError: LocalizedError {
    case rcloneNotFound
    case rcloneExecutionFailed(exitCode: Int32, stderr: String)
    case profileSaveFailed(underlying: Error)
    case profileNotFound(id: UUID)
    case processSpawnFailed(underlying: Error)
    case networkUnavailable
    case invalidCronExpression(String)
    case configDirectoryInaccessible(path: String)

    var errorDescription: String? {
        switch self {
        case .rcloneNotFound:
            return "rclone was not found. Please install rclone or set its path in Settings."
        case .rcloneExecutionFailed(let exitCode, let stderr):
            return "rclone exited with code \(exitCode): \(stderr)"
        case .profileSaveFailed(let underlying):
            return "Failed to save profile: \(underlying.localizedDescription)"
        case .profileNotFound(let id):
            return "Profile not found: \(id)"
        case .processSpawnFailed(let underlying):
            return "Failed to start process: \(underlying.localizedDescription)"
        case .networkUnavailable:
            return "No network connection available. Please check your internet connection."
        case .invalidCronExpression(let expression):
            return "Invalid cron expression: \"\(expression)\""
        case .configDirectoryInaccessible(let path):
            return "Cannot access configuration directory: \(path)"
        }
    }
}
