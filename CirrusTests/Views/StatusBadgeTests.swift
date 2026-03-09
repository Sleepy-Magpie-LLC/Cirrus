import Testing
@testable import Cirrus
import Foundation

@MainActor
struct StatusBadgeTests {
    @Test func idleStatusUsesCircleSymbol() {
        let badge = StatusBadge(status: .idle)
        #expect(badge.symbolName == "circle")
    }

    @Test func runningStatusUsesClockSymbol() {
        let badge = StatusBadge(status: .running)
        #expect(badge.symbolName == "clock.fill")
    }

    @Test func successStatusUsesCheckmarkSymbol() {
        let badge = StatusBadge(status: .success)
        #expect(badge.symbolName == "checkmark.circle.fill")
    }

    @Test func failedStatusUsesXmarkSymbol() {
        let badge = StatusBadge(status: .failed)
        #expect(badge.symbolName == "xmark.circle.fill")
    }

    @Test func canceledStatusUsesMinusSymbol() {
        let badge = StatusBadge(status: .canceled)
        #expect(badge.symbolName == "minus.circle")
    }

    @Test func interruptedStatusUsesWarningSymbol() {
        let badge = StatusBadge(status: .interrupted)
        #expect(badge.symbolName == "exclamationmark.triangle")
        #expect(badge.accessibilityText == "Interrupted")
    }

    @Test func allStatusesHaveAccessibilityLabels() {
        for status in [JobStatus.idle, .running, .success, .failed, .canceled, .interrupted] {
            let badge = StatusBadge(status: status)
            #expect(!badge.accessibilityText.isEmpty)
        }
    }

    @Test func allStatusesHaveDistinctSymbols() {
        let statuses: [JobStatus] = [.idle, .running, .success, .failed, .canceled, .interrupted]
        let symbols = Set(statuses.map { StatusBadge(status: $0).symbolName })
        #expect(symbols.count == 6)
    }
}
