import Testing
@testable import Cirrus
import Foundation

struct LogEntryTests {
    @Test func codableRoundTrip() throws {
        let entry = LogEntry(
            profileId: UUID(),
            startedAt: Date(),
            completedAt: Date(),
            status: .success,
            durationSeconds: 42.5,
            logFileName: "test_2026-01-01T00-00-00Z.log"
        )

        let data = try JSONEncoder.cirrus.encode(entry)
        let decoded = try JSONDecoder.cirrus.decode(LogEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.profileId == entry.profileId)
        #expect(decoded.status == entry.status)
        #expect(decoded.durationSeconds == entry.durationSeconds)
        #expect(decoded.logFileName == entry.logFileName)
    }

    @Test func codableRoundTripWithNilOptionals() throws {
        let entry = LogEntry(
            profileId: UUID(),
            logFileName: "test.log"
        )

        let data = try JSONEncoder.cirrus.encode(entry)
        let decoded = try JSONDecoder.cirrus.decode(LogEntry.self, from: data)

        #expect(decoded.completedAt == nil)
        #expect(decoded.durationSeconds == nil)
        #expect(decoded.status == .running)
    }

    @Test func defaultStatusIsRunning() {
        let entry = LogEntry(profileId: UUID(), logFileName: "test.log")
        #expect(entry.status == .running)
    }
}
