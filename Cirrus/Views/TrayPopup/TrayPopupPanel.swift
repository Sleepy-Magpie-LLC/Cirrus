import AppKit
import SwiftUI

@MainActor
final class TrayPopupPanel: NSPanel {
    static let popupWidth: CGFloat = 320
    static let popupHeight: CGFloat = 400

    var onDismiss: (() -> Void)?

    init(contentView swiftUIView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.popupWidth, height: Self.popupHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        collectionBehavior = [.transient, .ignoresCycle]

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: swiftUIView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setAccessibilityRole(.popover)

        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
        ])

        self.contentView = visualEffect
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }

    func show(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let frameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrame = buttonWindow.convertToScreen(frameInWindow)

        var x = buttonFrame.midX - Self.popupWidth / 2
        let y = buttonFrame.minY - 4

        if let screen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            x = max(visibleFrame.minX, min(x, visibleFrame.maxX - Self.popupWidth))
        }

        setFrameTopLeftPoint(NSPoint(x: x, y: y))
        makeKeyAndOrderFront(nil)
    }
}
