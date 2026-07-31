import Testing
@testable import Cirrus
import Foundation
import SwiftUI

@MainActor
struct HistoryTabViewTests {
    /// Split panes keep both preview and runs list visible (neither can collapse to zero).
    @Test func splitPaneMinimumHeightsKeepBothPanelsVisible() {
        #expect(HistoryTabView.logPreviewMinHeight >= 120)
        #expect(HistoryTabView.runsListMinHeight >= 100)
        #expect(HistoryTabView.logPreviewMinHeight > HistoryTabView.runsListMinHeight)
    }

    @Test func historyTabViewAcceptsExternalProfileBinding() {
        var profileId: UUID? = nil
        let binding = Binding(get: { profileId }, set: { profileId = $0 })
        let view = HistoryTabView(externalProfileId: binding)
        #expect(view.externalProfileId == nil)
    }
}

@MainActor
struct LogViewerReloadTests {
    /// Selecting a different run must reload file contents for that entry.
    @Test func readLogFileReturnsContentsForSelectedEntry() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = LogStore(configDirectoryURL: { tempDir })
        let runsDir = tempDir.appendingPathComponent("logs/runs", isDirectory: true)
        try FileManager.default.createDirectory(at: runsDir, withIntermediateDirectories: true)

        let profileId = UUID()
        let firstName = "first.log"
        let secondName = "second.log"
        try "first run output".write(to: runsDir.appendingPathComponent(firstName), atomically: true, encoding: .utf8)
        try "second run output".write(to: runsDir.appendingPathComponent(secondName), atomically: true, encoding: .utf8)

        let first = store.createEntry(profileId: profileId, logFileName: firstName)
        let second = store.createEntry(profileId: profileId, logFileName: secondName)

        #expect(store.readLogFile(fileName: first.logFileName) == "first run output")
        #expect(store.readLogFile(fileName: second.logFileName) == "second run output")
        #expect(store.entries(for: profileId).count == 2)
    }
}
