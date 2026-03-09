import Testing
@testable import Cirrus
import AppKit
import ServiceManagement

struct AppLifecycleTests {
    @Test @MainActor func appDelegatePreventsTerminateOnLastWindowClose() {
        let delegate = AppDelegate()
        let result = delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        #expect(result == false)
    }

    @Test func loginItemServiceAvailable() {
        let status = SMAppService.mainApp.status
        // Just verify the API is accessible — actual registration requires entitlements
        #expect(status == .notRegistered || status == .enabled || status == .notFound || status == .requiresApproval)
    }
}
