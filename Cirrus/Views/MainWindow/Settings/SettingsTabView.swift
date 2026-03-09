import SwiftUI
import ServiceManagement

struct SettingsTabView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var loginItemEnabled = SMAppService.mainApp.status == .enabled
    @State private var isDownloading = false
    @State private var downloadError: String?

    var body: some View {
        Form {
            rcloneSection
            storageSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - rclone Section

    private var rcloneSection: some View {
        Section("rclone") {
            if let path = appSettings.settings.rclonePath {
                LabeledContent("Path") {
                    HStack {
                        Text(path)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Browse...") {
                            browseForRclone()
                        }
                    }
                }

                if let version = appSettings.rcloneVersion {
                    LabeledContent("Version", value: version)
                }
            } else {
                HStack {
                    Text("rclone not found")
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Browse...") {
                        browseForRclone()
                    }
                }

                HStack {
                    Button("Download & Install rclone") {
                        downloadRclone()
                    }
                    .disabled(isDownloading)

                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let error = downloadError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section("Storage") {
            LabeledContent("Config Directory") {
                HStack {
                    Text(appSettings.settings.configDirectory)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Change...") {
                        changeConfigDirectory()
                    }
                }
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at Login", isOn: $loginItemEnabled)
                .onChange(of: loginItemEnabled) { _, newValue in
                    toggleLoginItem(enabled: newValue)
                }
            Toggle("Show window on launch", isOn: Binding(
                get: { appSettings.settings.showWindowOnLaunch ?? true },
                set: { newValue in
                    try? appSettings.update { $0.showWindowOnLaunch = newValue }
                }
            ))
        }
    }

    // MARK: - Actions

    private func browseForRclone() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select rclone binary"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        try? appSettings.update { settings in
            settings.rclonePath = url.path
        }
        appSettings.refreshRcloneVersion()
    }

    private func changeConfigDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select configuration directory"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        try? appSettings.update { settings in
            settings.configDirectory = url.path
        }
    }

    private func downloadRclone() {
        isDownloading = true
        downloadError = nil

        Task {
            do {
                let path = try await RcloneService.downloadAndInstall()
                try appSettings.update { settings in
                    settings.rclonePath = path
                }
                appSettings.refreshRcloneVersion()
            } catch {
                downloadError = error.localizedDescription
            }
            isDownloading = false
        }
    }

    private func toggleLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
