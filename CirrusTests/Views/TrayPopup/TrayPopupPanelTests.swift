import Testing
@testable import Cirrus
import AppKit
import SwiftUI

struct TrayPopupPanelTests {
    @Test @MainActor func panelIsBorderlessAndNonActivating() {
        let panel = TrayPopupPanel(contentView: Text("Test"))
        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.styleMask.contains(.fullSizeContentView))
    }

    @Test @MainActor func panelLevelIsPopUpMenu() {
        let panel = TrayPopupPanel(contentView: Text("Test"))
        #expect(panel.level == .popUpMenu)
    }

    @Test @MainActor func panelIsTransparent() {
        let panel = TrayPopupPanel(contentView: Text("Test"))
        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == .clear)
    }

    @Test @MainActor func panelHasShadow() {
        let panel = TrayPopupPanel(contentView: Text("Test"))
        #expect(panel.hasShadow == true)
    }

    @Test @MainActor func panelCanBecomeKey() {
        let panel = TrayPopupPanel(contentView: Text("Test"))
        #expect(panel.canBecomeKey == true)
    }

    @Test @MainActor func panelContentViewIsVisualEffectView() {
        let panel = TrayPopupPanel(contentView: Text("Test"))
        #expect(panel.contentView is NSVisualEffectView)
    }

    @Test @MainActor func visualEffectViewUsesPopoverMaterial() {
        let panel = TrayPopupPanel(contentView: Text("Test"))
        let visualEffect = panel.contentView as? NSVisualEffectView
        #expect(visualEffect?.material == .popover)
        #expect(visualEffect?.blendingMode == .behindWindow)
    }

    @Test @MainActor func panelCollectionBehaviorIsTransient() {
        let panel = TrayPopupPanel(contentView: Text("Test"))
        #expect(panel.collectionBehavior.contains(.transient))
        #expect(panel.collectionBehavior.contains(.ignoresCycle))
    }
}
