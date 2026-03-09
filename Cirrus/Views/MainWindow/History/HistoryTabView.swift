import SwiftUI

struct HistoryTabView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(JobManager.self) private var jobManager
    @Environment(LogStore.self) private var logStore
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Binding var externalProfileId: UUID?
    @State private var selectedProfileId: UUID?
    @State private var selectedLogEntry: LogEntry?
    @State private var cancelConfirmation = false
    @State private var startError: String?
    @State private var statusFilter: JobStatus?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding()
            Divider()
            historyContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selectedProfileId == nil {
                selectedProfileId = profileStore.profiles.first?.id
            }
        }
        .onChange(of: externalProfileId) {
            if let id = externalProfileId {
                selectedProfileId = id
                externalProfileId = nil
            }
        }
        .onChange(of: selectedLogEntry) {
            if let entry = selectedLogEntry {
                openLogWindow(for: entry)
                selectedLogEntry = nil
            }
        }
        .alert("Error", isPresented: Binding(
            get: { startError != nil },
            set: { if !$0 { startError = nil } }
        )) {
            Button("OK") { startError = nil }
        } message: {
            if let error = startError {
                Text(error)
            }
        }
        .alert("Cancel Job", isPresented: $cancelConfirmation) {
            Button("Cancel Job", role: .destructive) {
                if let profileId = selectedProfileId {
                    jobManager.cancelJob(for: profileId)
                }
            }
            Button("Keep Running", role: .cancel) {}
        } message: {
            Text("Cancel the running job?")
        }
    }

    private var toolbar: some View {
        HStack {
            Picker("Profile", selection: $selectedProfileId) {
                ForEach(profileStore.profiles) { profile in
                    HStack {
                        StatusBadge(status: currentStatus(for: profile))
                        Text(profile.name)
                    }
                    .tag(profile.id as UUID?)
                }
            }
            .pickerStyle(.menu)

            Picker("Status", selection: $statusFilter) {
                Text("All").tag(nil as JobStatus?)
                Divider()
                Text("Success").tag(JobStatus.success as JobStatus?)
                Text("Failed").tag(JobStatus.failed as JobStatus?)
                Text("Interrupted").tag(JobStatus.interrupted as JobStatus?)
                Text("Canceled").tag(JobStatus.canceled as JobStatus?)
            }
            .pickerStyle(.menu)
            .frame(width: 130)

            Spacer()

            if let profileId = selectedProfileId {
                if jobManager.isRunning(for: profileId) {
                    Button {
                        cancelConfirmation = true
                    } label: {
                        Label("Cancel", systemImage: "stop.circle.fill")
                    }
                    .tint(.red)
                } else {
                    Button {
                        guard let profile = profileStore.profile(for: profileId) else { return }
                        guard networkMonitor.isConnected else {
                            startError = "No network connection. Cannot start sync."
                            return
                        }
                        do {
                            try jobManager.startJob(for: profile)
                        } catch {
                            startError = error.localizedDescription
                        }
                    } label: {
                        Label("Start", systemImage: "play.circle.fill")
                    }
                    .tint(.green)
                }
            }
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if let profileId = selectedProfileId {
            VStack(spacing: 0) {
                if jobManager.isRunning(for: profileId),
                   let entryId = jobManager.activeJobs[profileId]?.logEntryId {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Live Output", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                        LiveLogView(logEntryId: entryId)
                            .frame(height: 200)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                    Divider()
                }

                let allEntries = logStore.entries(for: profileId)
                let entries = statusFilter.map { filter in
                    allEntries.filter { $0.status == filter }
                } ?? allEntries
                if entries.isEmpty && !jobManager.isRunning(for: profileId) {
                    emptyHistory
                } else {
                    List(entries) { entry in
                        let laterEntries = allEntries.drop(while: { $0.id != entry.id }).dropFirst()
                        let previousDuration = laterEntries
                            .first(where: { $0.status == .success })?.durationSeconds
                        HistoryRunRow(entry: entry, previousDuration: previousDuration)
                            .onTapGesture {
                                selectedLogEntry = entry
                            }
                    }
                }
            }
        } else {
            emptyHistory
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Run History")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("This profile hasn't been run yet.")
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func currentStatus(for profile: Profile) -> JobStatus {
        if jobManager.isRunning(for: profile.id) {
            return .running
        }
        return logStore.lastStatus(for: profile.id) ?? .idle
    }

    private func openLogWindow(for entry: LogEntry) {
        let content = LogViewerSheet(entry: entry)
            .environment(logStore)

        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.minSize = NSSize(width: 600, height: 400)
        window.title = "Log — \(entry.startedAt.formatted(date: .abbreviated, time: .shortened))"
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
    }
}
