import SwiftUI

struct CronBuilderView: View {
    @Binding var schedule: CronSchedule?

    @State private var selectedPreset: CronPreset = .daily
    @State private var rawExpression = ""
    @State private var hour = 2
    @State private var minute = 0
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5]

    enum CronPreset: String, CaseIterable, Identifiable {
        case every5Min = "Every 5 minutes"
        case every15Min = "Every 15 minutes"
        case every30Min = "Every 30 minutes"
        case hourly = "Hourly"
        case every6Hours = "Every 6 hours"
        case daily = "Daily"
        case weekdays = "Weekdays"
        case custom = "Custom"

        var id: String { rawValue }

        var expression: String? {
            switch self {
            case .every5Min: "*/5 * * * *"
            case .every15Min: "*/15 * * * *"
            case .every30Min: "*/30 * * * *"
            case .hourly: "0 * * * *"
            case .every6Hours: "0 */6 * * *"
            case .daily: nil // uses hour/minute
            case .weekdays: nil // uses hour/minute + days
            case .custom: nil // uses rawExpression
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Frequency", selection: $selectedPreset) {
                ForEach(CronPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }

            if selectedPreset == .daily || selectedPreset == .weekdays {
                timePicker
            }

            if selectedPreset == .weekdays {
                dayOfWeekPicker
            }

            if selectedPreset == .custom {
                TextField("Cron expression (e.g., 0 2 * * *)", text: $rawExpression)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            // Summary
            let expr = currentExpression
            if CronParser.validate(expr) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CronParser.humanReadable(expr))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let nextFire = try? CronParser.nextFireDate(for: expr) {
                        Text("Next: \(nextFire.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if selectedPreset == .custom && !rawExpression.isEmpty {
                Text("Invalid cron expression")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: selectedPreset) { updateSchedule() }
        .onChange(of: hour) { updateSchedule() }
        .onChange(of: minute) { updateSchedule() }
        .onChange(of: selectedDays) { updateSchedule() }
        .onChange(of: rawExpression) { updateSchedule() }
        .onAppear { loadFromSchedule() }
    }

    private var timePicker: some View {
        HStack {
            Picker("Hour", selection: $hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(formatHour(h)).tag(h)
                }
            }
            .frame(width: 120)

            Picker("Minute", selection: $minute) {
                ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                    Text(String(format: ":%02d", m)).tag(m)
                }
            }
            .frame(width: 80)
        }
    }

    private var dayOfWeekPicker: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { day in
                Toggle(isOn: Binding(
                    get: { selectedDays.contains(day) },
                    set: { isOn in
                        if isOn { selectedDays.insert(day) }
                        else if selectedDays.count > 1 { selectedDays.remove(day) }
                    }
                )) {
                    Text(shortDayName(day))
                        .font(.caption)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
            }
        }
    }

    private var currentExpression: String {
        if let expr = selectedPreset.expression {
            return expr
        }
        switch selectedPreset {
        case .daily: return "\(minute) \(hour) * * *"
        case .weekdays:
            let days = selectedDays.sorted().map(String.init).joined(separator: ",")
            return "\(minute) \(hour) * * \(days)"
        case .custom: return rawExpression
        default: return rawExpression
        }
    }

    private func updateSchedule() {
        let expr = currentExpression
        if CronParser.validate(expr) {
            schedule = CronSchedule(expression: expr, enabled: true)
        } else {
            schedule = nil
        }
    }

    private func loadFromSchedule() {
        guard let schedule = schedule else { return }

        // Try to match to a preset
        let expr = schedule.expression
        switch expr {
        case "*/5 * * * *": selectedPreset = .every5Min
        case "*/15 * * * *": selectedPreset = .every15Min
        case "*/30 * * * *": selectedPreset = .every30Min
        case "0 * * * *": selectedPreset = .hourly
        case "0 */6 * * *": selectedPreset = .every6Hours
        default:
            if let fields = try? CronParser.parseFields(expr) {
                let minuteValues = fields.minute.values
                let hourValues = fields.hour.values
                let domValues = fields.dayOfMonth.values
                let monthValues = fields.month.values
                let dowValues = fields.dayOfWeek.values

                let validMinutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
                if domValues == Set(1...31) && monthValues == Set(1...12) {
                    if minuteValues.count == 1 && hourValues.count == 1,
                       validMinutes.contains(minuteValues.first!) {
                        hour = hourValues.first!
                        minute = minuteValues.first!
                        if dowValues == Set(0...6) {
                            selectedPreset = .daily
                        } else {
                            selectedDays = dowValues
                            selectedPreset = .weekdays
                        }
                        return
                    }
                }
            }
            rawExpression = expr
            selectedPreset = .custom
        }
    }

    private func formatHour(_ h: Int) -> String {
        let period = h >= 12 ? "PM" : "AM"
        let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(display) \(period)"
    }

    private func shortDayName(_ day: Int) -> String {
        switch day {
        case 0: "Su"
        case 1: "Mo"
        case 2: "Tu"
        case 3: "We"
        case 4: "Th"
        case 5: "Fr"
        case 6: "Sa"
        default: "?"
        }
    }
}
