import Testing
@testable import Cirrus
import Foundation

@MainActor
struct LogViewerSheetTests {
    @Test func errorLineGetsRedBackground() {
        let color = LogViewerSheet.backgroundColor(for: "2026-01-01 ERROR: file not found")
        #expect(color != .clear)
    }

    @Test func failedLineGetsRedBackground() {
        let color = LogViewerSheet.backgroundColor(for: "Failed to copy file")
        #expect(color != .clear)
    }

    @Test func warningLineGetsYellowBackground() {
        let color = LogViewerSheet.backgroundColor(for: "WARNING: skipping file")
        #expect(color != .clear)
    }

    @Test func noticeLineGetsYellowBackground() {
        let color = LogViewerSheet.backgroundColor(for: "NOTICE: some info")
        #expect(color != .clear)
    }

    @Test func normalLineGetsClearBackground() {
        let color = LogViewerSheet.backgroundColor(for: "Transferred: 10 bytes")
        #expect(color == .clear)
    }

    @Test func caseInsensitiveErrorDetection() {
        let color = LogViewerSheet.backgroundColor(for: "error occurred")
        #expect(color != .clear)
    }

    @Test func caseInsensitiveWarningDetection() {
        let color = LogViewerSheet.backgroundColor(for: "warning: disk space low")
        #expect(color != .clear)
    }

    @Test func plainStderrLineWithoutErrorKeywordGetsClear() {
        let color = LogViewerSheet.backgroundColor(for: "some regular output")
        #expect(color == .clear)
    }

    @Test func deletedLineGetsSoftRedBackground() {
        let color = LogViewerSheet.backgroundColor(for: "Deleted: path/to/file.txt")
        #expect(color != .clear)
    }

    @Test func removingDirectoryLineGetsSoftRedBackground() {
        let color = LogViewerSheet.backgroundColor(for: "Removing directory: backup/old")
        #expect(color != .clear)
    }

    @Test func copiedLineGetsSoftGreenBackground() {
        let color = LogViewerSheet.backgroundColor(for: "Copied: documents/report.pdf")
        #expect(color != .clear)
    }
}
