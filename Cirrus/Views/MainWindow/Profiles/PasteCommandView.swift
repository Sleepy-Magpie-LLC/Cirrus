import SwiftUI

struct PasteCommandView: View {
    @State private var commandText = ""
    @State private var parseResult: RcloneCommandParser.ParseResult?
    var onParsed: (RcloneCommandParser.ParseResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste an rclone command to auto-fill the profile form.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $commandText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 120)
                .border(Color.secondary.opacity(0.3))

            if let result = parseResult, !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Parse & Fill Form") {
                    let result = RcloneCommandParser.parse(commandText)
                    parseResult = result
                    onParsed(result)
                }
                .disabled(commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
