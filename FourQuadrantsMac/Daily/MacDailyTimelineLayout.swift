import Foundation
import SwiftUI

/// Thin macOS adapter over the platform-independent, tested `DailyTaskLayout`.
/// Its frame has a 10pt iOS-oriented top inset; the Mac grid starts at y = 0.
enum MacDailyTimelineLayout {
    struct Item: Identifiable {
        let task: DailyTask
        let startAt: Date
        let duration: TimeInterval
        let frame: CGRect

        var id: UUID { task.id }
    }

    static func calculate(
        tasks: [DailyTask],
        dayStart: Date,
        dayEnd: Date,
        hourHeight: CGFloat
    ) -> [Item] {
        let layout = DailyTaskLayout.calculateLayout(
            for: tasks,
            hourHeight: hourHeight,
            visibleStart: dayStart,
            visibleEnd: dayEnd
        )
        return tasks.compactMap { task in
            guard let result = layout[task.id] else { return nil }
            var frame = result.frame
            frame.origin.y -= 10
            return Item(task: task, startAt: result.startAt, duration: result.duration, frame: frame)
        }
    }
}

enum MacDailyPalette {
    static let taskColors = ["#5E81F4", "#FF6B6B", "#4ECDC4", "#FFD93D", "#6C5CE7", "#A8E6CF", "#FF8B94"]

    static func color(hex: String?) -> Color {
        let value = (hex ?? taskColors[0]).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6, let number = UInt64(value, radix: 16) else { return .blue }
        return Color(
            .sRGB,
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum MacDailyTimeMath {
    static let snapMinutes = 15
    static let minimumDuration: TimeInterval = 15 * 60

    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func snapped(_ minute: Int) -> Int {
        let bounded = min(max(minute, 0), 24 * 60)
        return min(max(((bounded + snapMinutes / 2) / snapMinutes) * snapMinutes, 0), 24 * 60)
    }

    static func date(on day: Date, minute: Int, calendar: Calendar = .current) -> Date {
        let bounded = min(max(minute, 0), 24 * 60 - 1)
        return calendar.date(
            bySettingHour: bounded / 60,
            minute: bounded % 60,
            second: 0,
            of: day,
            matchingPolicy: .nextTime
        ) ?? day
    }
}
