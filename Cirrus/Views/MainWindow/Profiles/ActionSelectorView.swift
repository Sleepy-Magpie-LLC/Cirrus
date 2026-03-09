import SwiftUI

struct ActionSelectorView: View {
    @Binding var selectedAction: RcloneAction

    private static let descriptions: [RcloneAction: String] = [
        .sync: "Make destination identical to source, deleting extra files",
        .copy: "Copy files from source to destination, skipping existing",
        .move: "Move files from source to destination, deleting from source",
        .delete: "Delete files from destination that match the patterns",
        .bisync: "Two-way sync, keeping changes from both source and destination. (required) --resync is added automatically on the first run.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Action", selection: $selectedAction) {
                ForEach(RcloneAction.allCases, id: \.self) { action in
                    Text(action.displayDescription).tag(action)
                }
            }
            .pickerStyle(.segmented)

            if let description = Self.descriptions[selectedAction] {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
