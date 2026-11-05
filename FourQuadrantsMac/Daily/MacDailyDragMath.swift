import CoreGraphics
import Foundation

/// A proposed start and length for a daily task while it is being dragged.
struct MacDailyLayoutProposal: Equatable {
    var startAt: Date
    var duration: TimeInterval
}

/// Pure translation of a vertical drag distance into a snapped time range.
/// Always computed from the values captured when the drag began.
enum MacDailyDragMath {
    static func minutes(forDeltaY deltaY: CGFloat, hourHeight: CGFloat) -> Int {
        Int((deltaY / hourHeight * 60).rounded())
    }

    /// Moves the whole block. `displayStart` is the (possibly day-clipped) start
    /// shown on screen; `duration` is the task's real length. Nil when the task
    /// is longer than a day and cannot be moved.
    static func moved(
        displayStart: Date,
        duration: TimeInterval,
        deltaY: CGFloat,
        hourHeight: CGFloat,
        day: Date,
        calendar: Calendar = .current
    ) -> MacDailyLayoutProposal? {
        guard duration <= MacDailyTimeMath.maximumDuration else { return nil }
        let latestStart = max(0, MacDailyTimeMath.minuteCount - Int((duration / 60).rounded(.up)))
        let snappedLatestStart = latestStart / MacDailyTimeMath.snapMinutes * MacDailyTimeMath.snapMinutes
        let delta = minutes(forDeltaY: deltaY, hourHeight: hourHeight)
        let requested = MacDailyTimeMath.snapped(MacDailyTimeMath.minuteOfDay(displayStart, calendar: calendar) + delta)
        let startMinute = min(max(requested, 0), snappedLatestStart)
        return MacDailyLayoutProposal(
            startAt: MacDailyTimeMath.date(on: day, minute: startMinute, calendar: calendar),
            duration: duration
        )
    }

    /// Drags the top edge; the end stays where it was.
    static func resizedTop(
        start: Date,
        duration: TimeInterval,
        deltaY: CGFloat,
        hourHeight: CGFloat,
        day: Date,
        calendar: Calendar = .current
    ) -> MacDailyLayoutProposal {
        let oldEnd = start.addingTimeInterval(duration)
        let requested = MacDailyTimeMath.snapped(
            MacDailyTimeMath.minuteOfDay(start, calendar: calendar) + minutes(forDeltaY: deltaY, hourHeight: hourHeight)
        )
        let latestStartMinute = MacDailyTimeMath.minuteOfDay(
            oldEnd.addingTimeInterval(-MacDailyTimeMath.minimumDuration),
            calendar: calendar
        )
        let newStart = MacDailyTimeMath.date(on: day, minute: max(min(requested, latestStartMinute), 0), calendar: calendar)
        return MacDailyLayoutProposal(
            startAt: newStart,
            duration: max(oldEnd.timeIntervalSince(newStart), MacDailyTimeMath.minimumDuration)
        )
    }

    /// Drags the bottom edge; the start stays where it was.
    static func resizedBottom(
        start: Date,
        duration: TimeInterval,
        deltaY: CGFloat,
        hourHeight: CGFloat,
        day: Date,
        calendar: Calendar = .current
    ) -> MacDailyLayoutProposal {
        let startMinute = MacDailyTimeMath.minuteOfDay(start, calendar: calendar)
        let requestedEnd = MacDailyTimeMath.snapped(
            startMinute + Int((duration / 60).rounded()) + minutes(forDeltaY: deltaY, hourHeight: hourHeight)
        )
        let endMinute = min(
            max(requestedEnd, startMinute + Int(MacDailyTimeMath.minimumDuration / 60)),
            MacDailyTimeMath.minuteCount
        )
        let end = endMinute == MacDailyTimeMath.minuteCount
            ? MacDailyTimeMath.dayEnd(of: day, calendar: calendar)
            : MacDailyTimeMath.date(on: day, minute: endMinute, calendar: calendar)
        return MacDailyLayoutProposal(
            startAt: start,
            duration: max(end.timeIntervalSince(start), MacDailyTimeMath.minimumDuration)
        )
    }
}
