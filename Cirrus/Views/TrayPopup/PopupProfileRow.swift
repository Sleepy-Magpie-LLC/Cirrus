import SwiftUI

struct PopupProfileRow: View {
    let profile: Profile
    let jobStatus: JobStatus
    let lastRunDate: Date?
    let jobStartedAt: Date?
    var onStart: () -> Void = {}
    var onCancel: () -> Void = {}
    var onHistory: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            StatusBadge(status: jobStatus)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                metadataView
            }

            Spacer()

            actionButtons
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onHistory()
        }
    }

    @ViewBuilder
    private var metadataView: some View {
        if jobStatus == .running, let startedAt = jobStartedAt {
            TimelineView(.periodic(from: startedAt, by: 1)) { _ in
                Text(elapsedString(from: startedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let date = lastRunDate {
            Text(date, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Never run")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if jobStatus == .running {
            Button {
                onCancel()
            } label: {
                Image(systemName: "stop.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        } else {
            HStack(spacing: 4) {
                Button {
                    onStart()
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.borderless)

                Button {
                    onHistory()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func elapsedString(from date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
