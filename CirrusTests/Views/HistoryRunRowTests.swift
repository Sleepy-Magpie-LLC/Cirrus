import Testing
@testable import Cirrus
import Foundation

@MainActor
struct HistoryRunRowTests {
    @Test func formatDurationSeconds() {
        #expect(HistoryRunRow.formatDuration(45) == "45s")
    }

    @Test func formatDurationMinutesAndSeconds() {
        #expect(HistoryRunRow.formatDuration(125) == "2m 5s")
    }

    @Test func formatDurationHoursMinutesSeconds() {
        #expect(HistoryRunRow.formatDuration(3725) == "1h 2m 5s")
    }

    @Test func formatDurationZero() {
        #expect(HistoryRunRow.formatDuration(0) == "0s")
    }

    @Test func historyRunRowCreatesWithLogEntry() {
        let entry = LogEntry(profileId: UUID(), logFileName: "test.log")
        let row = HistoryRunRow(entry: entry)
        #expect(row.entry.id == entry.id)
    }

    @Test func historyRunRowAcceptsPreviousDuration() {
        let entry = LogEntry(
            profileId: UUID(),
            status: .success,
            durationSeconds: 120,
            logFileName: "test.log"
        )
        let row = HistoryRunRow(entry: entry, previousDuration: 100)
        #expect(row.previousDuration == 100)
    }

    @Test func historyRunRowNilPreviousDuration() {
        let entry = LogEntry(profileId: UUID(), logFileName: "test.log")
        let row = HistoryRunRow(entry: entry)
        #expect(row.previousDuration == nil)
    }

    @Test func runningEntryHasNoDurationSeconds() {
        let entry = LogEntry(profileId: UUID(), status: .running, logFileName: "test.log")
        #expect(entry.durationSeconds == nil)
        #expect(entry.status == .running)
    }

    @Test func failedEntryShowsDurationNoDelta() {
        let entry = LogEntry(
            profileId: UUID(),
            status: .failed,
            durationSeconds: 60,
            logFileName: "test.log"
        )
        let row = HistoryRunRow(entry: entry, previousDuration: 50)
        #expect(row.entry.status == .failed)
        #expect(row.entry.durationSeconds == 60)
        // Delta should not be shown for failed — only for success
    }

    @Test func interruptedEntryShowsDurationNoDelta() {
        let entry = LogEntry(
            profileId: UUID(),
            status: .interrupted,
            durationSeconds: 90,
            logFileName: "test.log"
        )
        let row = HistoryRunRow(entry: entry, previousDuration: 80)
        #expect(row.entry.status == .interrupted)
        #expect(row.entry.durationSeconds == 90)
    }
}
