import Foundation

enum JobStatus: String, Codable {
    case idle, running, success, failed, canceled, interrupted
}
