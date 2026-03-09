import SwiftUI

struct ProfileListView: View {
    var onSelectHistory: ((UUID) -> Void)?

    @Environment(ProfileStore.self) private var profileStore
    @Environment(JobManager.self) private var jobManager
    @Environment(LogStore.self) private var logStore
    @State private var showingNewProfile = false
    @State private var editingProfile: Profile?
    @State private var profileToDelete: Profile?
    @State private var profileToCancel: Profile?
    @State private var startError: String?

    var body: some View {
        VStack(spacing: 0) {
            if profileStore.profiles.isEmpty {
                emptyState
            } else {
                profileList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    showingNewProfile = true
                } label: {
                    Text("Add +")
                        .padding(.horizontal, 4)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .padding()
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            ProfileFormView()
        }
        .sheet(item: $editingProfile) { profile in
            ProfileFormView(editingProfile: profile)
        }
        .alert("Delete Profile", isPresented: Binding(
            get: { profileToDelete != nil },
            set: { if !$0 { profileToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    try? profileStore.delete(profile)
                    profileToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
        } message: {
            if let profile = profileToDelete {
                Text("Delete '\(profile.name)'? This cannot be undone.")
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
        .alert("Cancel Job", isPresented: Binding(
            get: { profileToCancel != nil },
            set: { if !$0 { profileToCancel = nil } }
        )) {
            Button("Cancel Job", role: .destructive) {
                if let profile = profileToCancel {
                    jobManager.cancelJob(for: profile.id)
                    profileToCancel = nil
                }
            }
            Button("Keep Running", role: .cancel) {
                profileToCancel = nil
            }
        } message: {
            if let profile = profileToCancel {
                Text("Cancel the running job for '\(profile.name)'?")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Profiles")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Create a profile to start syncing your files.")
                .foregroundStyle(.tertiary)
            Button("New Profile") {
                showingNewProfile = true
            }
            Spacer()
        }
    }

    private var profileList: some View {
        List(profileStore.profiles) { profile in
            let status = jobStatus(for: profile)
            let lastRun = lastSuccessfulRunDate(for: profile)
            let startedAt = jobManager.activeJobs[profile.id]?.startedAt

            GUIProfileRow(
                profile: profile,
                jobStatus: status,
                lastRunDate: lastRun,
                jobStartedAt: startedAt,
                onStart: {
                    do {
                        try jobManager.startJob(for: profile)
                    } catch {
                        startError = error.localizedDescription
                    }
                },
                onCancel: {
                    profileToCancel = profile
                },
                onEdit: {
                    editingProfile = profile
                },
                onSelectHistory: {
                    onSelectHistory?(profile.id)
                }
            )
            .contextMenu {
                Button("Edit") {
                    editingProfile = profile
                }
                Divider()
                Button("Delete", role: .destructive) {
                    profileToDelete = profile
                }
            }
        }
    }

    private func jobStatus(for profile: Profile) -> JobStatus {
        if let job = jobManager.activeJobs[profile.id] {
            return job.status
        }
        if let lastEntry = logStore.entries.last(where: { $0.profileId == profile.id }) {
            return lastEntry.status
        }
        return .idle
    }

    private func lastSuccessfulRunDate(for profile: Profile) -> Date? {
        logStore.entries
            .filter { $0.profileId == profile.id && $0.status == .success }
            .last?
            .completedAt
    }

}
