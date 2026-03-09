import SwiftUI

enum MainTab: Hashable {
    case profiles
    case history
    case settings
}

struct MainWindowView: View {
    @State private var selectedTab: MainTab = .profiles
    @State private var historyProfileId: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            ProfileListView(onSelectHistory: { profileId in
                historyProfileId = profileId
                selectedTab = .history
            })
                .tabItem {
                    Label("Profiles", systemImage: "folder")
                }
                .tag(MainTab.profiles)

            HistoryTabView(externalProfileId: $historyProfileId)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(MainTab.history)

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(MainTab.settings)
        }
        .frame(minWidth: 700, minHeight: 500)
        .onReceive(NotificationCenter.default.publisher(for: .openHistoryTab)) { notification in
            if let profileId = notification.userInfo?["profileId"] as? UUID {
                historyProfileId = profileId
            }
            selectedTab = .history
        }
    }
}
