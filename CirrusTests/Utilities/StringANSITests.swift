import Testing
@testable import Cirrus

struct StringANSITests {
    @Test func stripsColorCodes() {
        let input = "\u{1B}[32mTransferred: 0 / 0\u{1B}[0m"
        #expect(input.strippingANSICodes() == "Transferred: 0 / 0")
    }

    @Test func stripsBoldAndReset() {
        let input = "\u{1B}[1;31mERROR\u{1B}[0m: something failed"
        #expect(input.strippingANSICodes() == "ERROR: something failed")
    }

    @Test func stripsMultipleCodes() {
        let input = "\u{1B}[33mWARNING\u{1B}[0m: \u{1B}[36mfile.txt\u{1B}[0m not found"
        #expect(input.strippingANSICodes() == "WARNING: file.txt not found")
    }

    @Test func stripsCursorMovement() {
        let input = "\u{1B}[2K\u{1B}[1Aprogress: 50%"
        #expect(input.strippingANSICodes() == "progress: 50%")
    }

    @Test func noOpOnPlainText() {
        let input = "plain text with no codes"
        #expect(input.strippingANSICodes() == input)
    }

    @Test func emptyString() {
        #expect("".strippingANSICodes() == "")
    }
}
