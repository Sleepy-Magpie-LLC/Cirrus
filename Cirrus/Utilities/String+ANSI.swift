import Foundation

extension String {
    /// Strips ANSI escape codes (colors, cursor movement, etc.) from the string.
    /// Matches sequences like `\e[32m`, `\e[0;1;31m`, `\e[K`, etc.
    func strippingANSICodes() -> String {
        guard contains("\u{1B}") else { return self }
        return replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
    }
}
