import CoreGraphics
import Foundation
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacDailyDragMathTests {
    /// 60pt per hour makes one point equal one minute.
    private let hourHeight: CGFloat = 60
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))! }

    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        MacDailyTimeMath.date(on: day, minute: hour * 60 + minute, calendar: calendar)
    }

    @Test func moveSnapsToQuarterHours() {
        let result = MacDailyDragMath.moved(displayStart: time(10), duration: 3600, deltaY: 32, hourHeight: hourHeight, day: day, calendar: calendar)
        #expect(result?.startAt == time(10, 30))
        #expect(result?.duration == 3600)
    }

    @Test func moveIsBoundedByDayEdges() {
        let late = MacDailyDragMath.moved(displayStart: time(23), duration: 7200, deltaY: 600, hourHeight: hourHeight, day: day, calendar: calendar)
        #expect(late?.startAt == time(22))
        let early = MacDailyDragMath.moved(displayStart: time(1), duration: 3600, deltaY: -600, hourHeight: hourHeight, day: day, calendar: calendar)
        #expect(early?.startAt == time(0))
    }

    @Test func tasksLongerThanADayCannotMove() {
        #expect(MacDailyDragMath.moved(displayStart: time(0), duration: 25 * 3600, deltaY: 30, hourHeight: hourHeight, day: day, calendar: calendar) == nil)
    }

    @Test func topResizeKeepsEndAndMinimumLength() {
        let shorter = MacDailyDragMath.resizedTop(start: time(10), duration: 7200, deltaY: 30, hourHeight: hourHeight, day: day, calendar: calendar)
        #expect(shorter.startAt == time(10, 30))
        #expect(shorter.startAt.addingTimeInterval(shorter.duration) == time(12))

        let clamped = MacDailyDragMath.resizedTop(start: time(10), duration: 7200, deltaY: 200, hourHeight: hourHeight, day: day, calendar: calendar)
        #expect(clamped.startAt == time(11, 45))
        #expect(clamped.duration == MacDailyTimeMath.minimumDuration)
    }

    @Test func bottomResizeKeepsStartAndReachesMidnight() {
        let clamped = MacDailyDragMath.resizedBottom(start: time(10), duration: 3600, deltaY: -100, hourHeight: hourHeight, day: day, calendar: calendar)
        #expect(clamped.startAt == time(10))
        #expect(clamped.duration == MacDailyTimeMath.minimumDuration)

        let toMidnight = MacDailyDragMath.resizedBottom(start: time(10), duration: 3600, deltaY: 2000, hourHeight: hourHeight, day: day, calendar: calendar)
        #expect(toMidnight.duration == 14 * 3600)
    }

    @Test func resultDependsOnlyOnOriginAndTotalDelta() {
        // Recomputing from the same origin must not accumulate error.
        let direct = MacDailyDragMath.moved(displayStart: time(9), duration: 1800, deltaY: 95, hourHeight: hourHeight, day: day, calendar: calendar)
        var last: MacDailyLayoutProposal?
        for step in stride(from: 5, through: 95, by: 5) {
            last = MacDailyDragMath.moved(displayStart: time(9), duration: 1800, deltaY: CGFloat(step), hourHeight: hourHeight, day: day, calendar: calendar)
        }
        #expect(last == direct)
    }

    @Test func previewFrameFollowsTimeRangeAndKeepsColumn() {
        let column = CGRect(x: 0.5, y: 0, width: 0.5, height: 10)
        let frame = MacDailyTimelineLayout.previewFrame(columnFrame: column, startAt: time(2), duration: 5400, dayStart: day, hourHeight: hourHeight)
        #expect(frame.minX == 0.5)
        #expect(frame.width == 0.5)
        #expect(frame.minY == 120)
        #expect(frame.height == 90)
    }

    @Test func durationTextFormatsHoursAndMinutes() {
        #expect(MacDailyTimeMath.durationText(minutes: 45) == "45 分钟")
        #expect(MacDailyTimeMath.durationText(minutes: 120) == "2 小时")
        #expect(MacDailyTimeMath.durationText(minutes: 90) == "1 小时 30 分钟")
    }
}
