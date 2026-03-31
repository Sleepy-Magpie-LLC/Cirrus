import SwiftUI

struct IgnorePattern: Identifiable {
    let id = UUID()
    var value: String
}

struct ProfileFormView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    var editingProfile: Profile?

    @State private var name = ""
    @State private var source: Endpoint = .empty
    @State private var destination: Endpoint = .empty
    @State private var action: RcloneAction = .sync
    @State private var ignorePatterns: [IgnorePattern] = []
    @State private var extraFlags = ""
    @State private var discoveredRemotes: [String] = []
    @State private var saveError: String?
    @State private var creationMode: CreationMode = .manual
    @State private var showCommandPreview = false
    @State private var showIgnorePatterns = false
    @State private var logRetentionDays: Int? = nil
    @State private var logRetentionEnabled = false
    @State private var dryRunOutput: String?
    @State private var isDryRunning = false
    @State private var scheduleEnabled = false
    @State private var schedule: CronSchedule?
    @State private var showDeleteConfirmation = false

    enum CreationMode: String, CaseIterable {
        case manual = "Manual"
        case paste = "Paste Command"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if editingProfile == nil {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Creation Mode", selection: $creationMode) {
                                    ForEach(CreationMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()

                                if creationMode == .paste {
                                    PasteCommandView { result in
                                        applyParseResult(result)
                                        creationMode = .manual
                                    }
                                }
                            }
                        }
                    }

                    if editingProfile != nil {
                        runningJobWarning
                    }

                    nameSection

                    // --- Sync Configuration ---
                    sectionHeader("Sync Configuration")
                    EndpointFormSection(
                        title: "Source",
                        endpoint: $source,
                        discoveredRemotes: discoveredRemotes,
                        rclonePath: appSettings.settings.rclonePath
                    )
                    EndpointFormSection(
                        title: "Destination",
                        endpoint: $destination,
                        discoveredRemotes: discoveredRemotes,
                        rclonePath: appSettings.settings.rclonePath
                    )

                    HStack(spacing: 4) {
                        Text("For info on connecting to a supported storage system, see")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link("rclone documentation", destination: URL(string: "https://rclone.org/overview/")!)
                            .font(.caption)
                    }
                    .padding(.horizontal, 4)

                    actionSection

                    // --- Command Options ---
                    sectionHeader("Command Options")
                    flagsSection
                    commandPreviewSection
                    ignorePatternsSection

                    // --- Scheduling & Maintenance ---
                    sectionHeader("Scheduling & Maintenance")
                    scheduleSection
                    logRetentionSection

                    // --- Testing ---
                    sectionHeader("Testing")
                    dryRunSection
                }
                .padding()
            }

            if let error = saveError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                if editingProfile != nil {
                    Button("Delete", role: .destructive) {
                        showDeleteConfirmation = true
                    }.foregroundStyle(.red)
                }

                Spacer()
                Button("Save") { saveProfile() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
            .alert("Delete Profile?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { deleteProfile() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(editingProfile?.name ?? "")\"? This cannot be undone.")
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            loadRemotes()
            if let profile = editingProfile {
                populateFrom(profile)
            }
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
        }
        .padding(.top, 8)
    }

    private var nameSection: some View {
        GroupBox("Name") {
            TextField("", text: $name, prompt: Text("Profile Name"))
                .textFieldStyle(.roundedBorder)
        }
    }

    private var actionSection: some View {
        GroupBox("Action") {
            ActionSelectorView(selectedAction: $action)
        }
    }

    private var ignorePatternsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation { showIgnorePatterns.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showIgnorePatterns ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .frame(width: 10)
                        Text("Ignore Patterns")
                        if !ignorePatterns.filter({ !$0.value.isEmpty }).isEmpty {
                            Text("(\(ignorePatterns.filter { !$0.value.isEmpty }.count))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showIgnorePatterns {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach($ignorePatterns) { $pattern in
                            HStack {
                                TextField("", text: $pattern.value, prompt: Text("Pattern"))
                                    .textFieldStyle(.roundedBorder)
                                Button(role: .destructive) {
                                    ignorePatterns.removeAll { $0.id == pattern.id }
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        Button {
                            ignorePatterns.append(IgnorePattern(value: ""))
                        } label: {
                            Label("Add Pattern", systemImage: "plus")
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var flagsSection: some View {
        GroupBox("Extra Flags") {
            TextField("", text: $extraFlags, prompt: Text("e.g., --verbose --dry-run"))
                .textFieldStyle(.roundedBorder)
        }
    }

    private var commandPreviewSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation { showCommandPreview.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCommandPreview ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .frame(width: 10)
                        Text("Command Preview")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showCommandPreview {
                    let command = RcloneService.commandPreview(
                        rclonePath: appSettings.settings.rclonePath,
                        action: action,
                        source: source,
                        destination: destination,
                        ignorePatterns: ignorePatterns.map(\.value),
                        extraFlags: extraFlags
                    )
                    HStack(alignment: .top) {
                        Text(command)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(command, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy to clipboard")
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var scheduleSection: some View {
        GroupBox("Schedule") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable automatic scheduling", isOn: $scheduleEnabled)
                    .onChange(of: scheduleEnabled) {
                        if !scheduleEnabled {
                            schedule = nil
                        }
                    }

                if scheduleEnabled {
                    CronBuilderView(schedule: $schedule)
                }
            }
        }
    }

    private var logRetentionSection: some View {
        GroupBox("Log Retention") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Automatically prune old logs", isOn: $logRetentionEnabled)
                    .onChange(of: logRetentionEnabled) {
                        if !logRetentionEnabled {
                            logRetentionDays = nil
                        } else if logRetentionDays == nil {
                            logRetentionDays = 30
                        }
                    }

                if logRetentionEnabled {
                    HStack {
                        Text("Keep logs for")
                        TextField(
                            "",
                            value: Binding(
                                get: { logRetentionDays ?? 30 },
                                set: { logRetentionDays = max(1, min(365, $0)) }
                            ),
                            format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        Text("days")
                    }
                }
            }
        }
    }

    private var runningJobWarning: some View {
        // UI hook for FR19 — activates when JobManager (Epic 3) is injected
        EmptyView()
    }

    private var dryRunSection: some View {
        GroupBox("Test") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button {
                        runDryRun()
                    } label: {
                        Label("Test (Dry Run)", systemImage: "play.circle")
                    }
                    .disabled(!isValid || isDryRunning || appSettings.settings.rclonePath == nil)

                    if isDryRunning {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text("No files will be modified")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let output = dryRunOutput {
                    ScrollView {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
    }

    // MARK: - Computed

    private var isValid: Bool {
        let nameOk = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let sourceOk = source.isLocal
            ? !source.path.trimmingCharacters(in: .whitespaces).isEmpty
            : !source.remoteName.trimmingCharacters(in: .whitespaces).isEmpty
        let destOk = destination.isLocal
            ? !destination.path.trimmingCharacters(in: .whitespaces).isEmpty
            : !destination.remoteName.trimmingCharacters(in: .whitespaces).isEmpty
        return nameOk && sourceOk && destOk
    }

    // MARK: - Actions

    private func loadRemotes() {
        guard let rclonePath = appSettings.settings.rclonePath else { return }
        do {
            discoveredRemotes = try RcloneService.listRemotes(rclonePath: rclonePath)
        } catch {
            // Remotes discovery failed — user can still type manually
        }
    }

    private func applyParseResult(_ result: RcloneCommandParser.ParseResult) {
        if let parsed = result.action { action = parsed }
        if let src = result.source { source = src }
        if let dst = result.destination { destination = dst }
        if !result.ignorePatterns.isEmpty { ignorePatterns = result.ignorePatterns.map { IgnorePattern(value: $0) } }
        if !result.extraFlags.isEmpty { extraFlags = result.extraFlags }
    }

    private func runDryRun() {
        guard let rclonePath = appSettings.settings.rclonePath else { return }
        isDryRunning = true
        dryRunOutput = nil

        let currentAction = action
        let currentSource = source
        let currentDest = destination
        let currentPatterns = ignorePatterns.map(\.value).filter { !$0.isEmpty }
        let currentFlags = extraFlags

        Task.detached {
            let result: String
            do {
                result = try RcloneService.dryRun(
                    rclonePath: rclonePath,
                    action: currentAction,
                    source: currentSource,
                    destination: currentDest,
                    ignorePatterns: currentPatterns,
                    extraFlags: currentFlags
                )
            } catch let error as CirrusError {
                switch error {
                case .rcloneExecutionFailed(let exitCode, let stderr):
                    let firstLine = stderr
                        .components(separatedBy: .newlines)
                        .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
                        ?? "Unknown error"
                    result = "Error (exit code \(exitCode)): \(firstLine)"
                default:
                    result = "Error: \(error.errorDescription ?? error.localizedDescription)"
                }
            } catch {
                result = "Error: \(error.localizedDescription)"
            }
            await MainActor.run {
                let cleaned = result.strippingANSICodes()
                dryRunOutput = cleaned.isEmpty ? "No changes detected." : cleaned
                isDryRunning = false
            }
        }
    }

    private func populateFrom(_ profile: Profile) {
        name = profile.name
        source = profile.source
        destination = profile.destination
        action = profile.action
        ignorePatterns = profile.ignorePatterns.map { IgnorePattern(value: $0) }
        extraFlags = profile.extraFlags
        schedule = profile.schedule
        scheduleEnabled = profile.schedule?.enabled == true
        logRetentionDays = profile.logRetentionDays
        logRetentionEnabled = profile.logRetentionDays != nil
    }

    private func deleteProfile() {
        guard let profile = editingProfile else { return }
        do {
            try profileStore.delete(profile)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func saveProfile() {
        let filteredPatterns = ignorePatterns.map(\.value).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let trimmedSource = Endpoint(
            remoteName: source.remoteName.trimmingCharacters(in: .whitespaces),
            path: source.path.trimmingCharacters(in: .whitespaces)
        )
        let trimmedDest = Endpoint(
            remoteName: destination.remoteName.trimmingCharacters(in: .whitespaces),
            path: destination.path.trimmingCharacters(in: .whitespaces)
        )

        let profile: Profile
        if let existing = editingProfile {
            profile = Profile(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                source: trimmedSource,
                destination: trimmedDest,
                action: action,
                ignorePatterns: filteredPatterns,
                extraFlags: extraFlags,
                schedule: scheduleEnabled ? schedule : nil,
                logRetentionDays: logRetentionEnabled ? logRetentionDays : nil,
                groupName: existing.groupName,
                sortOrder: existing.sortOrder,
                createdAt: existing.createdAt
            )
        } else {
            profile = Profile(
                name: name.trimmingCharacters(in: .whitespaces),
                source: trimmedSource,
                destination: trimmedDest,
                action: action,
                ignorePatterns: filteredPatterns,
                extraFlags: extraFlags,
                schedule: scheduleEnabled ? schedule : nil,
                logRetentionDays: logRetentionEnabled ? logRetentionDays : nil
            )
        }

        do {
            try profileStore.save(profile)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
