import AppKit
import SwiftUI

extension Notification.Name {
    static let openHistoryTab = Notification.Name("openHistoryTab")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popupPanel: TrayPopupPanel!
    private var globalClickMonitor: Any?
    var jobManager: JobManager?
    var profileStore: ProfileStore?
    var logStore: LogStore?
    var networkMonitor: NetworkMonitor?
    private let popupState = TrayPopupState()
    private var refreshTimer: Timer?
    private var statusTimer: Timer?
    private var showingSyncIndicator = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopupPanel()
        startStatusTimer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return confirmAndTerminate() ? .terminateNow : .terminateCancel
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        button.image = makeMenuBarIcon()

        button.action = #selector(togglePopup)
        button.target = self
    }

    private func makeMenuBarIcon(syncing: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let cx: CGFloat = 9.5, cy: CGFloat = 9

            // Letter C arc
            let cPath = NSBezierPath()
            cPath.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: 6.5, startAngle: 50, endAngle: 310, clockwise: false)
            cPath.lineWidth = 2.2
            cPath.lineCapStyle = .round
            NSColor.black.setStroke()
            cPath.stroke()

            // Cloud bumps
            NSColor.black.setFill()
            NSBezierPath(ovalIn: CGRect(x: 4.2, y: 12.2, width: 4, height: 4)).fill()
            NSBezierPath(ovalIn: CGRect(x: 7.5, y: 14, width: 3, height: 3)).fill()

            // Small arrow at bottom tip
            let arr = NSBezierPath()
            arr.move(to: NSPoint(x: 13.5, y: 4.5))
            arr.line(to: NSPoint(x: 15.5, y: 3))
            arr.move(to: NSPoint(x: 15.5, y: 3))
            arr.line(to: NSPoint(x: 13.2, y: 2.5))
            arr.lineWidth = 1.2
            arr.lineCapStyle = .round
            arr.lineJoinStyle = .round
            NSColor.black.setStroke()
            arr.stroke()

            return true
        }
        // Always template — macOS tints the icon for light/dark menu bar
        image.isTemplate = true
        return image
    }

    private func startStatusTimer() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusIcon()
            }
        }
    }

    private func updateStatusIcon() {
        let isSyncing = (jobManager?.runningCount ?? 0) > 0
        guard isSyncing != showingSyncIndicator else { return }
        showingSyncIndicator = isSyncing

        guard let button = statusItem.button else { return }

        if isSyncing {
            if button.layer?.sublayers?.contains(where: { $0.name == "syncDot" }) != true {
                button.wantsLayer = true
                let dot = CALayer()
                dot.name = "syncDot"
                dot.backgroundColor = NSColor.systemCyan.cgColor
                dot.frame = CGRect(x: 13, y: 1, width: 5, height: 5)
                dot.cornerRadius = 2.5
                button.layer?.addSublayer(dot)
            }
        } else {
            button.layer?.sublayers?.removeAll { $0.name == "syncDot" }
        }
    }

    // MARK: - Popup

    private func setupPopupPanel() {
        let popupView = TrayPopupView(
            onStart: { [weak self] profile in
                do {
                    try self?.jobManager?.startJob(for: profile)
                } catch {
                    self?.popupState.errorMessage = error.localizedDescription
                }
                self?.refreshPopupState()
            },
            onCancel: { [weak self] profileId in
                self?.jobManager?.cancelJob(for: profileId)
                self?.refreshPopupState()
            },
            onOpenMainWindow: { [weak self] in
                self?.openMainWindow()
            },
            onOpenHistory: { [weak self] profileId in
                self?.openMainWindow()
                NotificationCenter.default.post(
                    name: .openHistoryTab,
                    object: nil,
                    userInfo: ["profileId": profileId]
                )
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        .environment(popupState)

        popupPanel = TrayPopupPanel(contentView: popupView)
        popupPanel.onDismiss = { [weak self] in
            self?.closePopup()
        }
    }

    private func refreshPopupState() {
        popupState.profiles = profileStore?.profiles ?? []
        popupState.activeJobs = jobManager?.activeJobs ?? [:]
        popupState.logEntries = logStore?.entries ?? []
        popupState.isNetworkConnected = networkMonitor?.isConnected ?? true
    }

    @objc private func togglePopup() {
        if popupPanel.isVisible {
            closePopup()
        } else {
            showPopup()
        }
    }

    private func showPopup() {
        guard let button = statusItem.button else { return }
        refreshPopupState()
        popupState.errorMessage = nil
        popupPanel.show(relativeTo: button)

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopup()
        }

        // Refresh popup state periodically while open
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPopupState()
            }
        }
    }

    private func closePopup() {
        popupPanel.orderOut(nil)
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Main Window

    func openMainWindow() {
        closePopup()
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.sendAction(#selector(NSWindowController.showWindow(_:)), to: nil, from: nil)
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        startWindowObserver()
    }

    private var windowCloseObserver: NSObjectProtocol?

    func startWindowObserver() {
        guard windowCloseObserver == nil else { return }
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow,
                  window.identifier?.rawValue == "main" else { return }
            self?.windowCloseObserver.flatMap { NotificationCenter.default.removeObserver($0) }
            self?.windowCloseObserver = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Quit

    /// Shows quit confirmation and returns `true` if the user confirmed.
    private func confirmAndTerminate() -> Bool {
        closePopup()

        // Ensure the app is active so the alert can receive focus
        let wasAccessory = NSApp.activationPolicy() == .accessory
        if wasAccessory {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Quit Cirrus?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        let jobCount = jobManager?.runningCount ?? 0
        let scheduledCount = profileStore?.profiles.filter { $0.schedule?.enabled == true }.count ?? 0

        if jobCount > 0 && scheduledCount > 0 {
            alert.informativeText = "\(jobCount) job(s) are currently running and \(scheduledCount) scheduled sync\(scheduledCount == 1 ? "" : "s") will be stopped."
        } else if jobCount > 0 {
            alert.informativeText = "\(jobCount) job(s) are currently running. They will be stopped."
        } else if scheduledCount > 0 {
            alert.informativeText = "Quitting will stop \(scheduledCount) scheduled sync\(scheduledCount == 1 ? "" : "s"). Are you sure?"
        } else {
            alert.informativeText = "Are you sure you want to quit Cirrus?"
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            jobManager?.cancelAllJobs()
            return true
        }

        // Restore accessory mode if the user cancelled and no main window is open
        if wasAccessory {
            let hasMainWindow = NSApp.windows.contains { $0.identifier?.rawValue == "main" && $0.isVisible }
            if !hasMainWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        return false
    }
}
