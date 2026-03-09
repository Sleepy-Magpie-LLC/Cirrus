import Testing
@testable import Cirrus
import Foundation

@MainActor
struct LiveLogViewTests {
    @Test func liveLogViewCreatesWithLogEntryId() {
        let entryId = UUID()
        let view = LiveLogView(logEntryId: entryId)
        #expect(view.logEntryId == entryId)
    }
}
