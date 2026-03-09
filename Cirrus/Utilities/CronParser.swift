import Foundation

struct CronParser {
    struct CronField {
        let values: Set<Int>
    }

    static func validate(_ expression: String) -> Bool {
        do {
            _ = try parseFields(expression)
            return true
        } catch {
            return false
        }
    }

    static func nextFireDate(for expression: String, after date: Date = Date()) throws -> Date {
        let fields = try parseFields(expression)
        let calendar = Calendar.current

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        // Start from the next minute
        components.second = 0
        components.nanosecond = 0

        guard var candidate = calendar.date(from: components) else {
            throw CirrusError.invalidCronExpression(expression)
        }

        // Move to next minute if we're at or past the current minute
        candidate = calendar.date(byAdding: .minute, value: 1, to: candidate)!

        // Search up to 2 years ahead
        let limit = calendar.date(byAdding: .year, value: 2, to: date)!

        while candidate < limit {
            let comps = calendar.dateComponents([.year, .minute, .hour, .day, .month, .weekday], from: candidate)
            guard let minute = comps.minute, let hour = comps.hour,
                  let day = comps.day, let month = comps.month,
                  let weekday = comps.weekday else {
                candidate = calendar.date(byAdding: .minute, value: 1, to: candidate)!
                continue
            }

            // Convert weekday: Calendar uses 1=Sunday, cron uses 0=Sunday
            let cronWeekday = weekday - 1

            if fields.minute.values.contains(minute) &&
                fields.hour.values.contains(hour) &&
                fields.dayOfMonth.values.contains(day) &&
                fields.month.values.contains(month) &&
                fields.dayOfWeek.values.contains(cronWeekday) {
                return candidate
            }

            // Optimize: skip ahead when possible
            if !fields.month.values.contains(month) {
                // Skip to next month
                var nextComps = comps
                nextComps.day = 1
                nextComps.hour = 0
                nextComps.minute = 0
                if let nextMonth = calendar.date(from: nextComps),
                   let advanced = calendar.date(byAdding: .month, value: 1, to: nextMonth) {
                    candidate = advanced
                    continue
                }
            }

            if !fields.dayOfMonth.values.contains(day) || !fields.dayOfWeek.values.contains(cronWeekday) {
                // Skip to next day
                var nextComps = comps
                nextComps.hour = 0
                nextComps.minute = 0
                if let nextDay = calendar.date(from: nextComps),
                   let advanced = calendar.date(byAdding: .day, value: 1, to: nextDay) {
                    candidate = advanced
                    continue
                }
            }

            if !fields.hour.values.contains(hour) {
                // Skip to next hour
                var nextComps = comps
                nextComps.minute = 0
                if let nextHour = calendar.date(from: nextComps),
                   let advanced = calendar.date(byAdding: .hour, value: 1, to: nextHour) {
                    candidate = advanced
                    continue
                }
            }

            candidate = calendar.date(byAdding: .minute, value: 1, to: candidate)!
        }

        throw CirrusError.invalidCronExpression(expression)
    }

    static func humanReadable(_ expression: String) -> String {
        guard let fields = try? parseFields(expression) else {
            return "Invalid schedule"
        }

        let minuteStr = describeField(fields.minute, range: 0...59)
        let hourStr = describeField(fields.hour, range: 0...23)
        let domStr = describeField(fields.dayOfMonth, range: 1...31)
        let monthStr = describeField(fields.month, range: 1...12)
        let dowStr = describeField(fields.dayOfWeek, range: 0...6)

        // Common patterns
        if minuteStr == "all" && hourStr == "all" && domStr == "all" && monthStr == "all" && dowStr == "all" {
            return "Every minute"
        }

        var parts: [String] = []

        // Time description
        if minuteStr != "all" && hourStr != "all" {
            let times = formatTimes(minutes: fields.minute.values, hours: fields.hour.values)
            parts.append("At \(times)")
        } else if minuteStr != "all" && hourStr == "all" {
            let minuteValues = fields.minute.values.sorted()
            if minuteValues.count == 1 && minuteValues[0] == 0 {
                parts.append("Every hour")
            } else {
                let step = detectStep(minuteValues, range: 0...59)
                if let step = step {
                    parts.append("Every \(step) minutes")
                } else {
                    parts.append("At minute \(minuteValues.map(String.init).joined(separator: ", "))")
                }
            }
        } else if minuteStr == "all" && hourStr != "all" {
            let hourValues = fields.hour.values.sorted()
            parts.append("Every minute during hour \(hourValues.map(String.init).joined(separator: ", "))")
        }

        // Day description
        if dowStr != "all" {
            let dayNames = fields.dayOfWeek.values.sorted().map { dayName($0) }
            parts.append("on \(dayNames.joined(separator: ", "))")
        }

        if domStr != "all" {
            let days = fields.dayOfMonth.values.sorted().map(String.init)
            parts.append("on day \(days.joined(separator: ", "))")
        }

        if monthStr != "all" {
            let months = fields.month.values.sorted().map { monthName($0) }
            parts.append("in \(months.joined(separator: ", "))")
        }

        return parts.isEmpty ? expression : parts.joined(separator: " ")
    }

    // MARK: - Parsing

    struct ParsedFields {
        let minute: CronField
        let hour: CronField
        let dayOfMonth: CronField
        let month: CronField
        let dayOfWeek: CronField
    }

    static func parseFields(_ expression: String) throws -> ParsedFields {
        let parts = expression.trimmingCharacters(in: .whitespaces).split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 5 else {
            throw CirrusError.invalidCronExpression(expression)
        }

        let minute = try parseField(String(parts[0]), range: 0...59)
        let hour = try parseField(String(parts[1]), range: 0...23)
        let dayOfMonth = try parseField(String(parts[2]), range: 1...31)
        let month = try parseField(String(parts[3]), range: 1...12)
        let dayOfWeek = try parseField(String(parts[4]), range: 0...6)

        return ParsedFields(
            minute: minute,
            hour: hour,
            dayOfMonth: dayOfMonth,
            month: month,
            dayOfWeek: dayOfWeek
        )
    }

    static func parseField(_ field: String, range: ClosedRange<Int>) throws -> CronField {
        var values = Set<Int>()

        let listParts = field.split(separator: ",")
        for part in listParts {
            let partStr = String(part)

            if partStr == "*" {
                values.formUnion(Set(range))
            } else if partStr.contains("/") {
                let stepParts = partStr.split(separator: "/")
                guard stepParts.count == 2, let step = Int(stepParts[1]), step > 0 else {
                    throw CirrusError.invalidCronExpression(field)
                }

                let base: ClosedRange<Int>
                if stepParts[0] == "*" {
                    base = range
                } else if stepParts[0].contains("-") {
                    base = try parseRange(String(stepParts[0]), fieldRange: range)
                } else if let start = Int(stepParts[0]), range.contains(start) {
                    base = start...range.upperBound
                } else {
                    throw CirrusError.invalidCronExpression(field)
                }

                var current = base.lowerBound
                while current <= base.upperBound {
                    values.insert(current)
                    current += step
                }
            } else if partStr.contains("-") {
                let rangeValues = try parseRange(partStr, fieldRange: range)
                values.formUnion(Set(rangeValues))
            } else if let value = Int(partStr), range.contains(value) {
                values.insert(value)
            } else {
                throw CirrusError.invalidCronExpression(field)
            }
        }

        guard !values.isEmpty else {
            throw CirrusError.invalidCronExpression(field)
        }

        return CronField(values: values)
    }

    private static func parseRange(_ rangeStr: String, fieldRange: ClosedRange<Int>) throws -> ClosedRange<Int> {
        let parts = rangeStr.split(separator: "-")
        guard parts.count == 2,
              let lower = Int(parts[0]), let upper = Int(parts[1]),
              fieldRange.contains(lower), fieldRange.contains(upper),
              lower <= upper else {
            throw CirrusError.invalidCronExpression(rangeStr)
        }
        return lower...upper
    }

    // MARK: - Human-readable helpers

    private static func describeField(_ field: CronField, range: ClosedRange<Int>) -> String {
        if field.values == Set(range) { return "all" }
        return "specific"
    }

    private static func formatTimes(minutes: Set<Int>, hours: Set<Int>) -> String {
        var times: [String] = []
        for hour in hours.sorted() {
            for minute in minutes.sorted() {
                let period = hour >= 12 ? "PM" : "AM"
                let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
                times.append(String(format: "%d:%02d %@", displayHour, minute, period))
            }
        }
        return times.joined(separator: " and ")
    }

    private static func detectStep(_ values: [Int], range: ClosedRange<Int>) -> Int? {
        guard values.count >= 2 else { return nil }
        let step = values[1] - values[0]
        guard step > 0 else { return nil }
        for i in 1..<values.count {
            if values[i] - values[i-1] != step { return nil }
        }
        // Verify it covers the range with this step
        if values[0] == range.lowerBound {
            return step
        }
        return nil
    }

    private static func dayName(_ day: Int) -> String {
        switch day {
        case 0: "Sunday"
        case 1: "Monday"
        case 2: "Tuesday"
        case 3: "Wednesday"
        case 4: "Thursday"
        case 5: "Friday"
        case 6: "Saturday"
        default: "Day \(day)"
        }
    }

    private static func monthName(_ month: Int) -> String {
        switch month {
        case 1: "January"
        case 2: "February"
        case 3: "March"
        case 4: "April"
        case 5: "May"
        case 6: "June"
        case 7: "July"
        case 8: "August"
        case 9: "September"
        case 10: "October"
        case 11: "November"
        case 12: "December"
        default: "Month \(month)"
        }
    }
}
