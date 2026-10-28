import Foundation

enum MacDailyTimeMath {
    static let snapMinutes = 15
    static let minuteCount = 24 * 60
    static let minimumDuration: TimeInterval = 15 * 60
    static let maximumDuration: TimeInterval = 24 * 3600
    /// Latest start offered when creating a task by clicking the grid.
    static let latestNewTaskMinute = minuteCount - snapMinutes
    /// Start offered for a new task on days other than today.
    static let defaultNewTaskMinute = 9 * 60

    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func snapped(_ minute: Int) -> Int {
        let bounded = min(max(minute, 0), minuteCount)
        return min(max(((bounded + snapMinutes / 2) / snapMinutes) * snapMinutes, 0), minuteCount)
    }

    static func date(on day: Date, minute: Int, calendar: Calendar = .current) -> Date {
        let bounded = min(max(minute, 0), minuteCount - 1)
        return calendar.date(
            bySettingHour: bounded / 60,
            minute: bounded % 60,
            second: 0,
            of: day,
            matchingPolicy: .nextTime
        ) ?? day
    }

    /// Start of the day after `day`.
    static func dayEnd(of day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(maximumDuration)
    }

    /// "45 分钟", "2 小时", "1 小时 30 分钟".
    static func durationText(minutes: Int) -> String {
        let hours = minutes / 60
        let remaining = minutes % 60
        if hours == 0 { return String(localized: "\(remaining) 分钟") }
        if remaining == 0 { return String(localized: "\(hours) 小时") }
        return String(localized: "\(hours) 小时 \(remaining) 分钟")
    }
}
