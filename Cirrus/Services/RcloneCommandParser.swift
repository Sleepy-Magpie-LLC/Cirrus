import Foundation

struct RcloneCommandParser {
    struct ParseResult {
        var action: RcloneAction?
        var source: Endpoint?
        var destination: Endpoint?
        var ignorePatterns: [String]
        var extraFlags: String
        var warnings: [String]

        init() {
            ignorePatterns = []
            extraFlags = ""
            warnings = []
        }
    }

    /// Parses an endpoint token into an Endpoint.
    /// If the token contains `:`, it's treated as `remote:path`.
    /// Otherwise it's treated as a local path.
    private static func parseEndpoint(_ token: String) -> Endpoint {
        if let colonIndex = token.firstIndex(of: ":") {
            let remote = String(token[token.startIndex..<colonIndex])
            let pathStart = token.index(after: colonIndex)
            let path = pathStart < token.endIndex ? String(token[pathStart...]) : ""
            return Endpoint(remoteName: remote, path: path)
        }
        return Endpoint(remoteName: "", path: token)
    }

    static func parse(_ command: String) -> ParseResult {
        var result = ParseResult()
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            result.warnings.append("Empty command")
            return result
        }

        let tokens = tokenize(trimmed)
        guard !tokens.isEmpty else {
            result.warnings.append("No tokens found")
            return result
        }

        var index = 0

        // Skip leading "rclone" if present
        if tokens[index].lowercased() == "rclone" {
            index += 1
        }

        guard index < tokens.count else {
            result.warnings.append("No action specified")
            return result
        }

        // Parse action
        let actionToken = tokens[index].lowercased()
        if let action = RcloneAction(rawValue: actionToken) {
            result.action = action
            index += 1
        } else {
            result.warnings.append("Unknown action: \(tokens[index])")
            index += 1
        }

        // Parse positional arguments (source and destination)
        var positionals: [String] = []
        var flagTokens: [String] = []
        var i = index
        while i < tokens.count {
            let token = tokens[i]
            if token.hasPrefix("-") {
                // Collect this and remaining as flags
                flagTokens.append(contentsOf: tokens[i...])
                break
            } else {
                positionals.append(token)
            }
            i += 1
        }

        // First positional = source, second = destination
        if positionals.count >= 1 {
            result.source = parseEndpoint(positionals[0])
        }
        if positionals.count >= 2 {
            result.destination = parseEndpoint(positionals[1])
        }
        // Extra positionals beyond 2 go to extraFlags
        if positionals.count > 2 {
            let extras = positionals[2...].joined(separator: " ")
            flagTokens.insert(extras, at: 0)
        }

        // Parse flags
        var extraFlagParts: [String] = []
        var fi = 0
        while fi < flagTokens.count {
            let flag = flagTokens[fi]

            if flag == "--exclude" || flag == "--filter" {
                fi += 1
                if fi < flagTokens.count {
                    result.ignorePatterns.append(flagTokens[fi])
                }
            } else if flag.hasPrefix("--exclude=") {
                let value = String(flag.dropFirst("--exclude=".count))
                result.ignorePatterns.append(value)
            } else if flag.hasPrefix("--filter=") {
                let value = String(flag.dropFirst("--filter=".count))
                result.ignorePatterns.append(value)
            } else if flag == "--filter-from" {
                fi += 1 // skip the path argument
                result.warnings.append("--filter-from not supported, add patterns manually")
            } else if flag.hasPrefix("--filter-from=") {
                result.warnings.append("--filter-from not supported, add patterns manually")
            } else {
                extraFlagParts.append(flag)
            }
            fi += 1
        }

        result.extraFlags = extraFlagParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if var src = result.source {
            src.remoteName = src.remoteName.trimmingCharacters(in: .whitespaces)
            src.path = src.path.trimmingCharacters(in: .whitespaces)
            result.source = src
        }
        if var dst = result.destination {
            dst.remoteName = dst.remoteName.trimmingCharacters(in: .whitespaces)
            dst.path = dst.path.trimmingCharacters(in: .whitespaces)
            result.destination = dst
        }
        result.ignorePatterns = result.ignorePatterns.map { $0.trimmingCharacters(in: .whitespaces) }
        return result
    }

    // MARK: - Tokenizer

    static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        for char in input {
            if escaped {
                // Backslash + newline = line continuation, skip both
                if char == "\n" || char == "\r" {
                    escaped = false
                    continue
                }
                current.append(char)
                escaped = false
                continue
            }

            if char == "\\" && !inSingleQuote {
                escaped = true
                continue
            }

            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }

            if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }

            if (char == " " || char == "\n" || char == "\r" || char == "\t") && !inSingleQuote && !inDoubleQuote {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(char)
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}
