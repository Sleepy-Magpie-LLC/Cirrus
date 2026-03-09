import SwiftUI

struct HistoryRunRow: View {
    let entry: LogEntry
    var previousDuration: Double?

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(status: entry.status)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)

                HStack(spacing: 8) {
                    Text(entry.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(statusForeground)

                    if entry.status == .running {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let elapsed = context.date.timeIntervalSince(entry.startedAt)
                            Label(Self.formatDuration(elapsed), systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    } else if let duration = entry.durationSeconds {
                        Label(Self.formatDuration(duration), systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if entry.status == .success {
                            durationDelta(current: duration)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func durationDelta(current: Double) -> some View {
        if let prev = previousDuration, prev > 0 {
            let change = ((current - prev) / prev) * 100
            if abs(change) >= 5 {
                let isSlower = change > 0
                HStack(spacing: 2) {
                    Image(systemName: isSlower ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%+.0f%%", change))
                        .font(.caption)
                }
                .foregroundStyle(isSlower ? .orange : .green)
                .help(String(format: "%@ than previous run (%@)",
                             isSlower ? "Slower" : "Faster",
                             Self.formatDuration(prev)))
            }
        }
    }

    private var statusForeground: Color {
        switch entry.status {
        case .success: .green
        case .failed: .red
        case .canceled: .orange
        case .interrupted: .orange
        case .running: .yellow
        case .idle: .gray
        }
    }

    static func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 { return "\(hours)h \(minutes)m \(secs)s" }
        if minutes > 0 { return "\(minutes)m \(secs)s" }
        return "\(secs)s"
    }
}
