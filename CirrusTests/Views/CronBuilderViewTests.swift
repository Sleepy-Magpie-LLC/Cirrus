import Testing
@testable import Cirrus
import Foundation

@MainActor
struct CronBuilderViewTests {
    @Test func presetEvery5MinGeneratesCorrectExpression() {
        #expect(CronBuilderView.CronPreset.every5Min.expression == "*/5 * * * *")
    }

    @Test func presetEvery15MinGeneratesCorrectExpression() {
        #expect(CronBuilderView.CronPreset.every15Min.expression == "*/15 * * * *")
    }

    @Test func presetEvery30MinGeneratesCorrectExpression() {
        #expect(CronBuilderView.CronPreset.every30Min.expression == "*/30 * * * *")
    }

    @Test func presetHourlyGeneratesCorrectExpression() {
        #expect(CronBuilderView.CronPreset.hourly.expression == "0 * * * *")
    }

    @Test func presetEvery6HoursGeneratesCorrectExpression() {
        #expect(CronBuilderView.CronPreset.every6Hours.expression == "0 */6 * * *")
    }

    @Test func presetDailyReturnsNilForCustomTime() {
        #expect(CronBuilderView.CronPreset.daily.expression == nil)
    }

    @Test func presetWeekdaysReturnsNilForCustomTime() {
        #expect(CronBuilderView.CronPreset.weekdays.expression == nil)
    }

    @Test func presetCustomReturnsNil() {
        #expect(CronBuilderView.CronPreset.custom.expression == nil)
    }

    @Test func allPresetsHaveUniqueIds() {
        let ids = CronBuilderView.CronPreset.allCases.map(\.id)
        #expect(Set(ids).count == CronBuilderView.CronPreset.allCases.count)
    }

    @Test func allPresetExpressionsAreValid() {
        for preset in CronBuilderView.CronPreset.allCases {
            if let expr = preset.expression {
                #expect(CronParser.validate(expr), "Preset \(preset.rawValue) has invalid expression: \(expr)")
            }
        }
    }
}
