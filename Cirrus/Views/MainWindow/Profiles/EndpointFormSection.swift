import SwiftUI

struct EndpointFormSection: View {
    let title: String
    @Binding var endpoint: Endpoint
    let discoveredRemotes: [String]
    let rclonePath: String?

    @State private var remoteDirectories: [String] = []
    @State private var isLoadingDirs = false
    @State private var loadDirsTask: Task<Void, Never>?

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Type", selection: $endpoint.remoteName) {
                    Text("Local").tag("")
                    ForEach(discoveredRemotes, id: \.self) { remote in
                        Text(remote).tag(remote)
                    }
                }
                .labelsHidden()
                .onChange(of: endpoint.remoteName) {
                    remoteDirectories = []
                    loadRemoteDirectories()
                }

                if endpoint.isLocal {
                    localSection
                } else {
                    remoteSection
                }
            }
        }
    }

    private var localSection: some View {
        HStack {
            TextField("", text: $endpoint.path, prompt: Text("Path"))
                .textFieldStyle(.roundedBorder)
            Button("Browse...") { browseFolder() }
        }
    }

    private var remoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $endpoint.path, prompt: Text("Remote Path"))
                .textFieldStyle(.roundedBorder)

            if isLoadingDirs {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading directories...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !remoteDirectories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(remoteDirectories, id: \.self) { dir in
                            Button {
                                if endpoint.path.isEmpty {
                                    endpoint.path = dir
                                } else {
                                    let base = endpoint.path.hasSuffix("/") ? endpoint.path : endpoint.path + "/"
                                    endpoint.path = base + dir
                                }
                                loadRemoteDirectories()
                            } label: {
                                Text(dir)
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadRemoteDirectories()
        }
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select \(title.lowercased()) folder"

        if panel.runModal() == .OK {
            endpoint.path = panel.url?.path ?? ""
        }
    }

    private func loadRemoteDirectories() {
        loadDirsTask?.cancel()
        guard !endpoint.isLocal, let rclonePath else {
            remoteDirectories = []
            return
        }

        let remote = endpoint.remoteName
        let path = endpoint.path

        isLoadingDirs = true
        loadDirsTask = Task.detached {
            let dirs: [String]
            do {
                dirs = try RcloneService.listDirectories(
                    rclonePath: rclonePath,
                    remoteName: remote,
                    path: path
                )
            } catch {
                dirs = []
            }
            await MainActor.run {
                remoteDirectories = dirs
                isLoadingDirs = false
            }
        }
    }
}
