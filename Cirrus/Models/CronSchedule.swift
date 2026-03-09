import Foundation

struct CronSchedule: Codable, Equatable {
    var expression: String
    var enabled: Bool

    init(expression: String, enabled: Bool = true) {
        self.expression = expression
        self.enabled = enabled
    }
}
