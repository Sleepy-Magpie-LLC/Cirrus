import SwiftUI

struct LogViewerSheet: View {
    let entry: LogEntry
    @Environment(LogStore.self) private var logStore
    @State private var logContent: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            contentView
        }
        .task {
            logContent = logStore.readLogFile(fileName: entry.logFileName)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    StatusBadge(status: entry.status)
                    Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                }
                if let duration = entry.durationSeconds {
                    Text("Duration: \(HistoryRunRow.formatDuration(duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                if let content = logContent {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .padding()
    }

    @ViewBuilder
    private var contentView: some View {
        if let content = logContent {
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .dropLast(while: { $0.isEmpty })

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let command = entry.command {
                        Text("$ \(command)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.08))
                        Divider()
                    }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .background(Self.backgroundColor(for: line))
                    }
                }
                .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView("Loading log...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    static func backgroundColor(for line: String) -> Color {
        let upper = line.uppercased()
        if upper.contains("ERROR") || upper.contains("FAILED") {
            return Color.red.opacity(0.35)
        }
        if upper.contains("WARNING") || upper.contains("NOTICE") {
            return Color.yellow.opacity(0.35)
        }
        if upper.contains("DELETED") || upper.contains("REMOVING DIRECTORY") {
            return Color.red.opacity(0.10)
        }
        if upper.contains("COPIED") {
            return Color.green.opacity(0.10)
        }
        return Color.clear
    }
}

private extension Array {
    func dropLast(while predicate: (Element) -> Bool) -> [Element] {
        var result = self
        while let last = result.last, predicate(last) {
            result.removeLast()
        }
        return result
    }
}
