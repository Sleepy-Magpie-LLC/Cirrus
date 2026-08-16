import SwiftUI

@main
struct CirrusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings: AppSettings
    @State private var profileStore: ProfileStore
    @State private var logStore: LogStore
    @State private var jobManager: JobManager
    @State private var networkMonitor: NetworkMonitor
    @State private var scheduleManager: ScheduleManager

    /// Managers are built and loaded by `AppEnvironment` rather than here, so that a launch
    /// with no window (login item) still gets fully initialized state.
    init() {
        let environment = AppEnvironment.shared
        _appSettings = State(initialValue: environment.appSettings)
        _profileStore = State(initialValue: environment.profileStore)
        _logStore = State(initialValue: environment.logStore)
        _jobManager = State(initialValue: environment.jobManager)
        _networkMonitor = State(initialValue: environment.networkMonitor)
        _scheduleManager = State(initialValue: environment.scheduleManager)
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
                    appDelegate.mainWindowDidAppear()
                }
        }
        .defaultSize(width: 800, height: 600)
    }
}
