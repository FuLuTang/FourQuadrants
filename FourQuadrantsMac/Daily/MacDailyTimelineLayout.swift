import Foundation
import SwiftUI

/// Thin macOS adapter over the platform-independent, tested `DailyTaskLayout`.
/// Its frame has an iOS-oriented top inset; the Mac grid starts at y = 0.
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
            frame.origin.y -= MacDailyTimelineMetrics.sharedLayoutTopInset
            return Item(task: task, startAt: result.startAt, duration: result.duration, frame: frame)
        }
    }

    /// Frame of a block while it is being dragged: keeps the column assigned by
    /// the layout but follows the proposed time range vertically.
    static func previewFrame(
        columnFrame: CGRect,
        startAt: Date,
        duration: TimeInterval,
        dayStart: Date,
        hourHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: columnFrame.minX,
            y: startAt.timeIntervalSince(dayStart) / 3600 * hourHeight,
            width: columnFrame.width,
            height: duration / 3600 * hourHeight
        )
    }
}
