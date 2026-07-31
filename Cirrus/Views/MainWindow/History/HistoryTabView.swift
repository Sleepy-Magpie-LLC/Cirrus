import SwiftUI

struct HistoryTabView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(JobManager.self) private var jobManager
    @Environment(LogStore.self) private var logStore
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Binding var externalProfileId: UUID?
    @State private var selectedProfileId: UUID?
    @State private var selectedLogEntryId: UUID?
    @State private var cancelConfirmation = false
    @State private var startError: String?
    @State private var statusFilter: JobStatus?

    /// Minimum height for the log preview pane in the split view.
    static let logPreviewMinHeight: CGFloat = 160
    /// Minimum height for the runs list pane so it stays on screen.
    static let runsListMinHeight: CGFloat = 120

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
            syncSelectionForCurrentProfile()
        }
        .onChange(of: externalProfileId) {
            if let id = externalProfileId {
                selectedProfileId = id
                externalProfileId = nil
            }
        }
        .onChange(of: selectedProfileId) {
            syncSelectionForCurrentProfile()
        }
        .onChange(of: selectedProfileLiveEntryId) {
            // Jump to live output when a job starts for this profile.
            if let liveId = selectedProfileLiveEntryId {
                selectedLogEntryId = liveId
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
            let allEntries = logStore.entries(for: profileId)
            let entries = statusFilter.map { filter in
                allEntries.filter { $0.status == filter }
            } ?? allEntries
            let isLive = jobManager.isRunning(for: profileId)

            VSplitView {
                logPanel(profileId: profileId, allEntries: allEntries)
                    .frame(minHeight: Self.logPreviewMinHeight, maxHeight: .infinity)
                    .layoutPriority(1)

                runsPanel(entries: entries, allEntries: allEntries, isLive: isLive)
                    .frame(minHeight: Self.runsListMinHeight, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            emptyHistory
        }
    }

    @ViewBuilder
    private func logPanel(profileId: UUID, allEntries: [LogEntry]) -> some View {
        let selectedEntry = selectedLogEntryId.flatMap { id in
            allEntries.first(where: { $0.id == id }) ?? logStore.entries.first(where: { $0.id == id })
        }
        let liveEntryId = jobManager.activeJobs[profileId]?.logEntryId
        // Preview follows list selection. Live stream only when that run is selected (or nothing is).
        let showingLive = jobManager.isRunning(for: profileId)
            && liveEntryId != nil
            && (selectedLogEntryId == nil || selectedLogEntryId == liveEntryId)

        VStack(alignment: .leading, spacing: 4) {
            if showingLive, let liveEntryId {
                Label("Live Output", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LiveLogView(logEntryId: liveEntryId)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let selectedEntry {
                if selectedEntry.status == .running,
                   logStore.liveBuffer[selectedEntry.id] != nil {
                    Label("Live Output", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LiveLogView(logEntryId: selectedEntry.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LogViewerSheet(entry: selectedEntry)
                        .id(selectedEntry.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                emptyLogPanel
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func runsPanel(entries: [LogEntry], allEntries: [LogEntry], isLive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Runs")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if entries.isEmpty && !isLive {
                emptyHistoryList
            } else {
                List(entries, selection: $selectedLogEntryId) { entry in
                    let laterEntries = allEntries.drop(while: { $0.id != entry.id }).dropFirst()
                    let previousDuration = laterEntries
                        .first(where: { $0.status == .success })?.durationSeconds
                    HistoryRunRow(entry: entry, previousDuration: previousDuration)
                        .tag(entry.id as UUID?)
                        .contentShape(Rectangle())
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyLogPanel: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Select a run to view its log")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyHistoryList: some View {
        VStack(spacing: 4) {
            Spacer()
            Text("No Run History")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("This profile hasn't been run yet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// Live log entry for the selected profile, if a job is running.
    private var selectedProfileLiveEntryId: UUID? {
        guard let profileId = selectedProfileId,
              jobManager.isRunning(for: profileId) else { return nil }
        return jobManager.activeJobs[profileId]?.logEntryId
    }

    private func currentStatus(for profile: Profile) -> JobStatus {
        if jobManager.isRunning(for: profile.id) {
            return .running
        }
        return logStore.lastStatus(for: profile.id) ?? .idle
    }

    /// Prefer the live run, otherwise the newest entry for this profile.
    private func syncSelectionForCurrentProfile() {
        guard let profileId = selectedProfileId else {
            selectedLogEntryId = nil
            return
        }
        if let liveId = selectedProfileLiveEntryId {
            selectedLogEntryId = liveId
            return
        }
        selectedLogEntryId = logStore.entries(for: profileId).first?.id
    }
}
