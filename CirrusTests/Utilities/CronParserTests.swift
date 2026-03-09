import Testing
@testable import Cirrus
import Foundation

struct CronParserTests {
    // MARK: - Validation

    @Test func validExpressions() {
        #expect(CronParser.validate("* * * * *"))
        #expect(CronParser.validate("0 2 * * *"))
        #expect(CronParser.validate("*/15 * * * *"))
        #expect(CronParser.validate("0 9 * * 1-5"))
        #expect(CronParser.validate("30 8,17 * * *"))
        #expect(CronParser.validate("0 0 1 1 *"))
        #expect(CronParser.validate("5 4 * * 0"))
    }

    @Test func invalidExpressions() {
        #expect(!CronParser.validate("* * * *"))          // 4 fields
        #expect(!CronParser.validate("60 * * * *"))       // minute out of range
        #expect(!CronParser.validate("* 24 * * *"))       // hour out of range
        #expect(!CronParser.validate("* * 0 * *"))        // day 0
        #expect(!CronParser.validate("* * * 13 *"))       // month out of range
        #expect(!CronParser.validate("* * * * 7"))        // weekday out of range
        #expect(!CronParser.validate("abc"))              // nonsense
        #expect(!CronParser.validate(""))                 // empty
    }

    // MARK: - Field Parsing

    @Test func parseWildcard() throws {
        let field = try CronParser.parseField("*", range: 0...59)
        #expect(field.values.count == 60)
    }

    @Test func parseSingleValue() throws {
        let field = try CronParser.parseField("5", range: 0...59)
        #expect(field.values == [5])
    }

    @Test func parseRange() throws {
        let field = try CronParser.parseField("1-5", range: 0...59)
        #expect(field.values == [1, 2, 3, 4, 5])
    }

    @Test func parseStep() throws {
        let field = try CronParser.parseField("*/15", range: 0...59)
        #expect(field.values == [0, 15, 30, 45])
    }

    @Test func parseList() throws {
        let field = try CronParser.parseField("1,3,5", range: 0...59)
        #expect(field.values == [1, 3, 5])
    }

    @Test func parseRangeWithStep() throws {
        let field = try CronParser.parseField("1-10/3", range: 0...59)
        #expect(field.values == [1, 4, 7, 10])
    }

    @Test func parseListWithRanges() throws {
        let field = try CronParser.parseField("1-3,7,10-12", range: 1...31)
        #expect(field.values == [1, 2, 3, 7, 10, 11, 12])
    }

    // MARK: - Next Fire Date

    @Test func nextFireDateEveryMinute() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 1
        components.hour = 10
        components.minute = 30
        components.second = 0
        let after = calendar.date(from: components)!

        let next = try CronParser.nextFireDate(for: "* * * * *", after: after)
        let nextComps = calendar.dateComponents([.minute, .hour], from: next)
        #expect(nextComps.minute == 31)
        #expect(nextComps.hour == 10)
    }

    @Test func nextFireDateDailyAt2AM() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 1
        components.hour = 10
        components.minute = 0
        components.second = 0
        let after = calendar.date(from: components)!

        let next = try CronParser.nextFireDate(for: "0 2 * * *", after: after)
        let nextComps = calendar.dateComponents([.day, .hour, .minute], from: next)
        #expect(nextComps.day == 2)
        #expect(nextComps.hour == 2)
        #expect(nextComps.minute == 0)
    }

    @Test func nextFireDateEvery15Minutes() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 1
        components.hour = 10
        components.minute = 5
        components.second = 0
        let after = calendar.date(from: components)!

        let next = try CronParser.nextFireDate(for: "*/15 * * * *", after: after)
        let nextComps = calendar.dateComponents([.minute], from: next)
        #expect(nextComps.minute == 15)
    }

    @Test func nextFireDateWeekdaysOnly() throws {
        let calendar = Calendar.current
        // Find a Friday
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 27 // Friday
        components.hour = 10
        components.minute = 0
        components.second = 0
        let friday = calendar.date(from: components)!

        let next = try CronParser.nextFireDate(for: "0 9 * * 1-5", after: friday)
        let nextComps = calendar.dateComponents([.weekday, .hour, .minute], from: next)
        // Should be Monday (weekday 2) at 9:00
        #expect(nextComps.weekday == 2)
        #expect(nextComps.hour == 9)
        #expect(nextComps.minute == 0)
    }

    @Test func nextFireDateMultipleHours() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 1
        components.hour = 9
        components.minute = 0
        components.second = 0
        let after = calendar.date(from: components)!

        let next = try CronParser.nextFireDate(for: "30 8,17 * * *", after: after)
        let nextComps = calendar.dateComponents([.hour, .minute], from: next)
        #expect(nextComps.hour == 17)
        #expect(nextComps.minute == 30)
    }

    @Test func nextFireDateInvalidExpressionThrows() {
        #expect(throws: CirrusError.self) {
            _ = try CronParser.nextFireDate(for: "invalid")
        }
    }

    @Test func nextFireDateCrossesMidnight() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 1
        components.hour = 23
        components.minute = 55
        components.second = 0
        let after = calendar.date(from: components)!

        let next = try CronParser.nextFireDate(for: "0 2 * * *", after: after)
        let nextComps = calendar.dateComponents([.day, .hour, .minute], from: next)
        #expect(nextComps.day == 2)
        #expect(nextComps.hour == 2)
        #expect(nextComps.minute == 0)
    }

    @Test func nextFireDateCrossesMonthEnd() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 0
        let after = calendar.date(from: components)!

        let next = try CronParser.nextFireDate(for: "0 0 1 * *", after: after)
        let nextComps = calendar.dateComponents([.month, .day, .hour, .minute], from: next)
        #expect(nextComps.month == 4)
        #expect(nextComps.day == 1)
    }

    // MARK: - Human Readable

    @Test func humanReadableEveryMinute() {
        let result = CronParser.humanReadable("* * * * *")
        #expect(result == "Every minute")
    }

    @Test func humanReadableDaily() {
        let result = CronParser.humanReadable("0 2 * * *")
        #expect(result.contains("2:00 AM"))
    }

    @Test func humanReadableEvery15Minutes() {
        let result = CronParser.humanReadable("*/15 * * * *")
        #expect(result.contains("15 minutes"))
    }

    @Test func humanReadableWeekdays() {
        let result = CronParser.humanReadable("0 9 * * 1-5")
        #expect(result.contains("Monday"))
        #expect(result.contains("Friday"))
    }

    @Test func humanReadableInvalid() {
        let result = CronParser.humanReadable("invalid")
        #expect(result == "Invalid schedule")
    }
}
