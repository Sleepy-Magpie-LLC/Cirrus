import SwiftUI

@main
struct CirrusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings: AppSettings
    @State private var profileStore: ProfileStore
    @State private var logStore: LogStore
    @State private var jobManager: JobManager
    @State private var networkMonitor = NetworkMonitor()
    @State private var scheduleManager: ScheduleManager
    @State private var hasLaunched = false

    init() {
        let settings = AppSettings()
        let logStoreInstance = LogStore(configDirectoryURL: { settings.configDirectoryURL })
        let profileStoreInstance = ProfileStore(configDirectoryURL: { settings.configDirectoryURL })
        let jobManagerInstance = JobManager(
            rclonePath: { settings.settings.rclonePath },
            logStore: logStoreInstance
        )

        // Load data before creating @State so onAppear doesn't trigger re-renders
        try? settings.load()
        profileStoreInstance.loadAll()
        logStoreInstance.loadIndex()

        _appSettings = State(initialValue: settings)
        _profileStore = State(initialValue: profileStoreInstance)
        _logStore = State(initialValue: logStoreInstance)
        _jobManager = State(initialValue: jobManagerInstance)
        _scheduleManager = State(initialValue: ScheduleManager(
            profileStore: profileStoreInstance,
            jobManager: jobManagerInstance,
            logStore: logStoreInstance,
            configDirectoryURL: { settings.configDirectoryURL }
        ))
    }

    var body: some Scene {
        Window("Cirrus", id: "main") {
            MainWindowView()
                .environment(appSettings)
                .environment(profileStore)
                .environment(logStore)
                .environment(jobManager)
                .environment(networkMonitor)
                .environment(scheduleManager)
                .onAppear {
                    guard !hasLaunched else {
                        // Reopened from tray — just make sure we're in regular mode
                        NSApp.setActivationPolicy(.regular)
                        appDelegate.startWindowObserver()
                        return
                    }
                    hasLaunched = true

                    scheduleManager.start()
                    wireAppDelegate()

                    let shouldShow = appSettings.settings.showWindowOnLaunch
                        ?? profileStore.profiles.isEmpty
                    if shouldShow {
                        NSApp.setActivationPolicy(.regular)
                        appDelegate.startWindowObserver()
                    } else {
                        // Close the auto-created window and go to menu-bar-only
                        DispatchQueue.main.async {
                            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                                window.close()
                            }
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .defaultSize(width: 800, height: 600)
    }

    private func wireAppDelegate() {
        appDelegate.jobManager = jobManager
        appDelegate.profileStore = profileStore
        appDelegate.logStore = logStore
        appDelegate.networkMonitor = networkMonitor
    }
}
