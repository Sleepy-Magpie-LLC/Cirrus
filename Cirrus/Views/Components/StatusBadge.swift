import SwiftUI

struct StatusBadge: View {
    let status: JobStatus

    var body: some View {
        Image(systemName: symbolName)
            .foregroundStyle(color)
            .accessibilityLabel(accessibilityText)
    }

    var symbolName: String {
        switch status {
        case .idle: "circle"
        case .running: "clock.fill"
        case .success: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .canceled: "minus.circle"
        case .interrupted: "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch status {
        case .idle: .gray
        case .running: .yellow
        case .success: .green
        case .failed: .red
        case .canceled: .orange
        case .interrupted: .orange
        }
    }

    var accessibilityText: String {
        switch status {
        case .idle: "Idle"
        case .running: "Running"
        case .success: "Success"
        case .failed: "Failed"
        case .canceled: "Canceled"
        case .interrupted: "Interrupted"
        }
    }
}
