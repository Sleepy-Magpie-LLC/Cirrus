import Foundation

struct RcloneService {
    static func detectRclone() throws -> String {
        // Try `which rclone` first
        if let path = try? runProcess("/usr/bin/which", arguments: ["rclone"]) {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && FileManager.default.isExecutableFile(atPath: trimmed) {
                return trimmed
            }
        }

        // Check common locations
        let commonPaths = [
            "/usr/local/bin/rclone",
            "/opt/homebrew/bin/rclone",
            NSString("~/.local/bin/rclone").expandingTildeInPath,
        ]

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        throw CirrusError.rcloneNotFound
    }

    static func version(at path: String) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw CirrusError.rcloneNotFound
        }

        let output = try runProcess(path, arguments: ["version"])
        // First line format: "rclone v1.67.0"
        guard let firstLine = output.components(separatedBy: .newlines).first,
              !firstLine.isEmpty else {
            throw CirrusError.rcloneExecutionFailed(exitCode: 0, stderr: "Empty version output")
        }

        return firstLine
    }

    static func downloadAndInstall() async throws -> String {
        let installDir = NSString("~/.local/bin").expandingTildeInPath
        let installPath = (installDir as NSString).appendingPathComponent("rclone")
        let fileManager = FileManager.default

        // Create install directory
        if !fileManager.fileExists(atPath: installDir) {
            try fileManager.createDirectory(atPath: installDir, withIntermediateDirectories: true)
        }

        // Determine architecture
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "amd64"
        #endif

        let urlString = "https://downloads.rclone.org/rclone-current-osx-\(arch).zip"
        guard let url = URL(string: urlString) else {
            throw CirrusError.rcloneNotFound
        }

        // Download
        let (zipURL, _) = try await URLSession.shared.download(from: url)
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
            try? fileManager.removeItem(at: zipURL)
        }

        // Unzip
        let unzipOutput = try runProcess("/usr/bin/unzip", arguments: ["-o", zipURL.path, "-d", tempDir.path])
        _ = unzipOutput

        // Find rclone binary in extracted contents
        let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: nil)
        var binaryPath: String?
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent == "rclone" && fileManager.isExecutableFile(atPath: fileURL.path) {
                binaryPath = fileURL.path
                break
            }
        }

        guard let sourcePath = binaryPath else {
            throw CirrusError.rcloneNotFound
        }

        // Copy to install location
        if fileManager.fileExists(atPath: installPath) {
            try fileManager.removeItem(atPath: installPath)
        }
        try fileManager.copyItem(atPath: sourcePath, toPath: installPath)

        // Ensure executable
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installPath)

        return installPath
    }

    static func listRemotes(rclonePath: String) throws -> [String] {
        guard FileManager.default.isExecutableFile(atPath: rclonePath) else {
            throw CirrusError.rcloneNotFound
        }

        let output = try runProcess(rclonePath, arguments: ["listremotes"])
        return parseListRemotesOutput(output)
    }

    static func parseListRemotesOutput(_ output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.hasSuffix(":") ? String($0.dropLast()) : $0 }
    }

    static func listDirectories(rclonePath: String, remoteName: String, path: String) throws -> [String] {
        guard FileManager.default.isExecutableFile(atPath: rclonePath) else {
            throw CirrusError.rcloneNotFound
        }

        let remotePath = path.isEmpty ? "\(remoteName):" : "\(remoteName):\(path)"
        let output = try runProcess(rclonePath, arguments: ["lsd", remotePath])
        return parseLsdOutput(output)
    }

    static func parseLsdOutput(_ output: String) -> [String] {
        // rclone lsd output format: "          -1 2024-01-15 10:30:00        -1 dirname"
        // The directory name is the last whitespace-delimited field per line
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                // Split by whitespace and take the last component
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard let last = parts.last else { return nil }
                return String(last)
            }
    }

    static func dryRun(
        rclonePath: String,
        action: RcloneAction,
        source: Endpoint,
        destination: Endpoint,
        ignorePatterns: [String],
        extraFlags: String
    ) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: rclonePath) else {
            throw CirrusError.rcloneNotFound
        }

        let trimmedSource = source.formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDest = destination.formatted.trimmingCharacters(in: .whitespacesAndNewlines)

        var arguments = [action.rawValue, trimmedSource, trimmedDest, "--dry-run"]

        for pattern in ignorePatterns {
            let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            arguments.append("--exclude")
            arguments.append(trimmed)
        }

        let sanitizedFlags = extraFlags.replacingOccurrences(of: "\n", with: " ")
        let flagParts = RcloneCommandParser.tokenize(sanitizedFlags)
        arguments.append(contentsOf: flagParts)

        return try runProcess(rclonePath, arguments: arguments)
    }

    static func commandPreview(
        rclonePath: String?,
        action: RcloneAction,
        source: Endpoint,
        destination: Endpoint,
        ignorePatterns: [String],
        extraFlags: String
    ) -> String {
        let executable = rclonePath ?? "rclone"

        func quoted(_ path: String) -> String {
            path.contains(" ") ? "\"\(path)\"" : path
        }

        var parts = [quoted(executable), action.rawValue]

        let sourceFormatted = source.formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceFormatted.isEmpty {
            parts.append(quoted(sourceFormatted))
        } else {
            parts.append("<source>")
        }

        let destFormatted = destination.formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        if !destFormatted.isEmpty {
            parts.append(quoted(destFormatted))
        } else {
            parts.append("<destination>")
        }

        for pattern in ignorePatterns {
            let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            parts.append("--exclude")
            parts.append("\"\(trimmed)\"")
        }

        let sanitizedFlags = extraFlags.replacingOccurrences(of: "\n", with: " ")
        let flagParts = RcloneCommandParser.tokenize(sanitizedFlags)
        parts.append(contentsOf: flagParts)

        return parts.joined(separator: " ")
    }

    static func buildCommand(profile: Profile, filterFileURL: URL?, needsResync: Bool = false) -> [String] {
        var args = [profile.action.rawValue, profile.source.formatted, profile.destination.formatted, "--verbose"]

        if needsResync {
            args.append("--resync")
        }

        if let filterURL = filterFileURL {
            args.append("--filter-from")
            args.append(filterURL.path)
        }

        let flagParts = RcloneCommandParser.tokenize(profile.extraFlags)
        args.append(contentsOf: flagParts)

        return args
    }

    static func parseVersionNumber(from versionString: String) -> String? {
        // Extract version like "v1.67.0" from "rclone v1.67.0"
        let components = versionString.split(separator: " ")
        return components.first(where: {
            $0.hasPrefix("v") && $0.count > 1 && $0[$0.index(after: $0.startIndex)].isNumber
        }).map(String.init)
    }

    // MARK: - Private

    private static func runProcess(_ executablePath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw CirrusError.processSpawnFailed(underlying: error)
        }

        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            throw CirrusError.rcloneExecutionFailed(exitCode: process.terminationStatus, stderr: errorOutput)
        }

        return output
    }
}
