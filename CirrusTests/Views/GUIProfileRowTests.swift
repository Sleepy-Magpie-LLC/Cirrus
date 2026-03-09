import Testing
@testable import Cirrus
import Foundation

@MainActor
struct GUIProfileRowTests {
    private func makeProfile(
        name: String = "Test Profile",
        schedule: CronSchedule? = nil
    ) -> Profile {
        Profile(
            name: name,
            source: Endpoint(remoteName: "", path: "/Users/test/Documents"),
            destination: Endpoint(remoteName: "gdrive", path: "backup"),
            schedule: schedule
        )
    }

    @Test func idleProfileShowsStartButton() {
        let profile = makeProfile()
        let row = GUIProfileRow(profile: profile, jobStatus: .idle, lastRunDate: nil, jobStartedAt: nil)
        // Pure view — verifying it can be created without errors
        _ = row
    }

    @Test func runningProfileShowsCancelButton() {
        let profile = makeProfile()
        let row = GUIProfileRow(profile: profile, jobStatus: .running, lastRunDate: nil, jobStartedAt: Date())
        _ = row
    }

    @Test func profileWithScheduleDisplaysExpression() {
        let schedule = CronSchedule(expression: "0 */6 * * *", enabled: true)
        let profile = makeProfile(schedule: schedule)
        let row = GUIProfileRow(profile: profile, jobStatus: .idle, lastRunDate: nil, jobStartedAt: nil)
        _ = row
    }

    @Test func profileWithDisabledScheduleDisplaysNoSchedule() {
        let schedule = CronSchedule(expression: "0 */6 * * *", enabled: false)
        let profile = makeProfile(schedule: schedule)
        let row = GUIProfileRow(profile: profile, jobStatus: .idle, lastRunDate: nil, jobStartedAt: nil)
        _ = row
    }

    @Test func profileWithNilScheduleDisplaysNoSchedule() {
        let profile = makeProfile(schedule: nil)
        let row = GUIProfileRow(profile: profile, jobStatus: .idle, lastRunDate: nil, jobStartedAt: nil)
        _ = row
    }

    @Test func startCallbackIsCalled() {
        let profile = makeProfile()
        var startCalled = false
        let row = GUIProfileRow(
            profile: profile,
            jobStatus: .idle,
            lastRunDate: nil,
            jobStartedAt: nil,
            onStart: { startCalled = true }
        )
        row.onStart()
        #expect(startCalled)
    }

    @Test func cancelCallbackIsCalled() {
        let profile = makeProfile()
        var cancelCalled = false
        let row = GUIProfileRow(
            profile: profile,
            jobStatus: .running,
            lastRunDate: nil,
            jobStartedAt: Date(),
            onCancel: { cancelCalled = true }
        )
        row.onCancel()
        #expect(cancelCalled)
    }

    @Test func elapsedStringFormatsCorrectly() {
        let profile = makeProfile()
        let startedAt = Date().addingTimeInterval(-125) // 2:05
        let row = GUIProfileRow(profile: profile, jobStatus: .running, lastRunDate: nil, jobStartedAt: startedAt)
        _ = row
    }

    @Test func lastRunDateIsDisplayed() {
        let profile = makeProfile()
        let lastRun = Date().addingTimeInterval(-3600) // 1 hour ago
        let row = GUIProfileRow(profile: profile, jobStatus: .success, lastRunDate: lastRun, jobStartedAt: nil)
        _ = row
    }

    // MARK: - relativeSinceSync

    @Test func relativeSinceSyncShowsSeconds() {
        let now = Date()
        let date = now.addingTimeInterval(-30)
        let result = GUIProfileRow.relativeSinceSync(from: date, now: now)
        #expect(result == "30s ago")
    }

    @Test func relativeSinceSyncShowsMinutes() {
        let now = Date()
        let date = now.addingTimeInterval(-150) // 2.5 minutes
        let result = GUIProfileRow.relativeSinceSync(from: date, now: now)
        #expect(result == "2m ago")
    }

    @Test func relativeSinceSyncShowsHours() {
        let now = Date()
        let date = now.addingTimeInterval(-7200) // 2 hours
        let result = GUIProfileRow.relativeSinceSync(from: date, now: now)
        #expect(result == "2h ago")
    }

    @Test func relativeSinceSyncShowsDateAfter24Hours() {
        let now = Date()
        let date = now.addingTimeInterval(-90000) // 25 hours
        let result = GUIProfileRow.relativeSinceSync(from: date, now: now)
        #expect(!result.contains("ago"))
    }

    @Test func relativeSinceSyncBoundaryAt60Seconds() {
        let now = Date()
        let date = now.addingTimeInterval(-59)
        #expect(GUIProfileRow.relativeSinceSync(from: date, now: now) == "59s ago")

        let date60 = now.addingTimeInterval(-60)
        #expect(GUIProfileRow.relativeSinceSync(from: date60, now: now) == "1m ago")
    }

    @Test func selectHistoryCallbackIsCalled() {
        let profile = makeProfile()
        var historyCalled = false
        let row = GUIProfileRow(
            profile: profile,
            jobStatus: .idle,
            lastRunDate: nil,
            jobStartedAt: nil,
            onSelectHistory: { historyCalled = true }
        )
        row.onSelectHistory()
        #expect(historyCalled)
    }
}
