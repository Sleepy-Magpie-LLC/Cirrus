import Testing
@testable import Cirrus
import Foundation

struct CirrusErrorTests {
    @Test func errorDescriptionReturnsNonNilForAllCases() {
        let cases: [CirrusError] = [
            .rcloneNotFound,
            .rcloneExecutionFailed(exitCode: 1, stderr: "error"),
            .profileSaveFailed(underlying: NSError(domain: "test", code: 1)),
            .profileNotFound(id: UUID()),
            .processSpawnFailed(underlying: NSError(domain: "test", code: 1)),
            .networkUnavailable,
            .invalidCronExpression("bad"),
            .configDirectoryInaccessible(path: "/tmp/bad"),
        ]

        for error in cases {
            #expect(error.errorDescription != nil, "errorDescription should not be nil for \(error)")
        }
    }

    @Test func rcloneNotFoundDescription() {
        let error = CirrusError.rcloneNotFound
        #expect(error.errorDescription?.contains("rclone") == true)
    }

    @Test func rcloneExecutionFailedIncludesExitCode() {
        let error = CirrusError.rcloneExecutionFailed(exitCode: 42, stderr: "something broke")
        #expect(error.errorDescription?.contains("42") == true)
        #expect(error.errorDescription?.contains("something broke") == true)
    }

    @Test func profileNotFoundIncludesUUID() {
        let id = UUID()
        let error = CirrusError.profileNotFound(id: id)
        #expect(error.errorDescription?.contains(id.uuidString) == true)
    }

    @Test func invalidCronExpressionIncludesExpression() {
        let error = CirrusError.invalidCronExpression("*/999 * *")
        #expect(error.errorDescription?.contains("*/999 * *") == true)
    }

    @Test func configDirectoryInaccessibleIncludesPath() {
        let error = CirrusError.configDirectoryInaccessible(path: "/some/path")
        #expect(error.errorDescription?.contains("/some/path") == true)
    }

    @Test func errorsConformToLocalizedError() {
        let error: LocalizedError = CirrusError.networkUnavailable
        #expect(error.errorDescription != nil)
    }
}
