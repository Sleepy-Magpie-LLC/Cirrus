import Foundation
import os

/// Owns the app's long-lived managers and performs the one-time load of on-disk state.
///
/// This lives outside the SwiftUI view hierarchy on purpose: when macOS launches Cirrus
/// as a login item (after a reboot), the `Window` scene is never instantiated, so any
/// startup work hung off a view's `onAppear` silently never runs. Everything that must
/// happen at launch happens here and in `AppDelegate.applicationDidFinishLaunching`.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let appSettings: AppSettings
    let profileStore: ProfileStore
    let logStore: LogStore
    let jobManager: JobManager
    let networkMonitor: NetworkMonitor
    let scheduleManager: ScheduleManager

    private static let logger = Logger(subsystem: "com.sane.cirrus", category: "AppEnvironment")

    private init() {
        let settings = AppSettings()
        let logStore = LogStore(configDirectoryURL: { settings.configDirectoryURL })
        let profileStore = ProfileStore(configDirectoryURL: { settings.configDirectoryURL })
        let jobManager = JobManager(
            rclonePath: { settings.settings.rclonePath },
            logStore: logStore
        )

        do {
            try settings.load()
        } catch {
            Self.logger.error("Failed to load settings: \(error.localizedDescription)")
        }
        profileStore.loadAll()
        logStore.loadIndex()

        self.appSettings = settings
        self.logStore = logStore
        self.profileStore = profileStore
        self.jobManager = jobManager
        self.networkMonitor = NetworkMonitor()
        self.scheduleManager = ScheduleManager(
            profileStore: profileStore,
            jobManager: jobManager,
            logStore: logStore,
            configDirectoryURL: { settings.configDirectoryURL }
        )
    }
}
