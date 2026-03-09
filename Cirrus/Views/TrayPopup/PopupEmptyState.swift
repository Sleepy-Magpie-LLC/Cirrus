import SwiftUI

struct PopupEmptyState: View {
    var onCreateProfile: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No profiles yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("Create your first profile") {
                onCreateProfile()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
