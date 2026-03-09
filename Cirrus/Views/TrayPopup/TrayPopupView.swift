import SwiftUI

struct TrayPopupView: View {
    @Environment(TrayPopupState.self) var state
    var onStart: (Profile) -> Void = { _ in }
    var onCancel: (UUID) -> Void = { _ in }
    var onOpenMainWindow: () -> Void = {}
    var onOpenHistory: (UUID) -> Void = { _ in }
    var onQuit: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            contentArea
            Divider()
            footer
        }
        .frame(width: TrayPopupPanel.popupWidth, height: TrayPopupPanel.popupHeight)
    }

    private var header: some View {
        HStack {
            Text("Cirrus")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var contentArea: some View {
        Group {
            if state.profiles.isEmpty {
                PopupEmptyState(onCreateProfile: onOpenMainWindow)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(state.profiles.enumerated()), id: \.element.id) { index, profile in
                                let status = jobStatus(for: profile)
                                let lastRun = lastSuccessfulRunDate(for: profile)
                                let startedAt = state.activeJobs[profile.id]?.startedAt

                                PopupProfileRow(
                                    profile: profile,
                                    jobStatus: status,
                                    lastRunDate: lastRun,
                                    jobStartedAt: startedAt,
                                    onStart: {
                                        if state.isNetworkConnected {
                                            state.errorMessage = nil
                                            state.isNetworkError = false
                                            onStart(profile)
                                        } else {
                                            state.errorMessage = "No network connection. Cannot start sync."
                                            state.isNetworkError = true
                                        }
                                    },
                                    onCancel: {
                                        onCancel(profile.id)
                                    },
                                    onHistory: {
                                        onOpenHistory(profile.id)
                                    }
                                )
                                if index < state.profiles.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }

                    if let error = state.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: state.isNetworkConnected) {
            if state.isNetworkConnected && state.isNetworkError {
                state.errorMessage = nil
                state.isNetworkError = false
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Open Cirrus") {
                onOpenMainWindow()
            }
            Spacer()
            Button("Quit") {
                onQuit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func jobStatus(for profile: Profile) -> JobStatus {
        if let job = state.activeJobs[profile.id] {
            return job.status
        }
        if let lastEntry = state.logEntries.last(where: { $0.profileId == profile.id }) {
            return lastEntry.status
        }
        return .idle
    }

    private func lastSuccessfulRunDate(for profile: Profile) -> Date? {
        state.logEntries
            .filter { $0.profileId == profile.id && $0.status == .success }
            .last?
            .completedAt
    }
}
