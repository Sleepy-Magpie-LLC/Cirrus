import SwiftUI

struct GUIProfileRow: View {
    let profile: Profile
    let jobStatus: JobStatus
    let lastRunDate: Date?
    let jobStartedAt: Date?
    var onStart: () -> Void = {}
    var onCancel: () -> Void = {}
    var onEdit: () -> Void = {}
    var onSelectHistory: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(status: jobStatus)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    onSelectHistory()
                } label: {
                    Text(profile.name)
                        .font(.title3.bold())
                        .foregroundStyle(.link)
                }
                .buttonStyle(.plain)
                .accessibilityHint("View sync history")

                HStack(spacing: 4) {
                    Text(profile.action.displayDescription)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(profile.source.displayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(profile.destination.displayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 12) {
                    statusInfo
                    scheduleInfo
                }
            }

            Spacer()

            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusInfo: some View {
        if jobStatus == .running, let startedAt = jobStartedAt {
            TimelineView(.periodic(from: startedAt, by: 1)) { _ in
                Label(elapsedString(from: startedAt), systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let date = lastRunDate {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(Self.relativeSinceSync(from: date, now: context.date), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Last synced: \(date.formatted(date: .abbreviated, time: .shortened))")
            }
        } else {
            Label("Never run", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .help("This profile has never been synced")
        }
    }

    static func relativeSinceSync(from date: Date, now: Date = Date()) -> String {
        let elapsed = Int(now.timeIntervalSince(date))
        if elapsed < 0 { return "Just now" }
        if elapsed < 60 { return "\(elapsed)s ago" }
        if elapsed < 3600 {
            let minutes = elapsed / 60
            return "\(minutes)m ago"
        }
        if elapsed < 86400 {
            let hours = elapsed / 3600
            return "\(hours)h ago"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    @ViewBuilder
    private var scheduleInfo: some View {
        if let schedule = profile.schedule, schedule.enabled {
            if let nextFire = try? CronParser.nextFireDate(for: schedule.expression) {
                Label("Next: \(nextFire.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(CronParser.humanReadable(schedule.expression), systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Label("No schedule", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        HStack(spacing: 8) {
            if jobStatus == .running {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    onStart()
                } label: {
                    Label("Start", systemImage: "play.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
            .buttonStyle(.bordered)
            .help("Edit profile")
        }
    }

    private func elapsedString(from date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
