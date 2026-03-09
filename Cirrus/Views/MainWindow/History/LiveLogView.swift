import SwiftUI

struct LiveLogView: View {
    let logEntryId: UUID
    @Environment(LogStore.self) private var logStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var command: String? {
        logStore.entries.first(where: { $0.id == logEntryId })?.command
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let command {
                        Text("$ \(command)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .textSelection(.enabled)
                        Divider()
                    }

                    let buffer = logStore.liveBuffer[logEntryId] ?? "Waiting for output..."
                    let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .background(LogViewerSheet.backgroundColor(for: line))
                    }
                    .textSelection(.enabled)
                    .id("logContent")
                }

                Color.clear.frame(height: 1).id("bottom")
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onChange(of: logStore.liveBuffer[logEntryId]) {
                if !reduceMotion {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                } else {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}
