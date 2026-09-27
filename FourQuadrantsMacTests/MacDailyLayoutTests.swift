import CoreGraphics
import Foundation
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacDailyLayoutTests {
    @Test func overlappingTasksUseDistinctColumns() throws {
        let start = Calendar.current.startOfDay(for: Date())
        let end = try #require(Calendar.current.date(byAdding: .day, value: 1, to: start))
        let first = DailyTask(title: "第一项", startAt: start.addingTimeInterval(10 * 3600), duration: 90 * 60)
        let second = DailyTask(title: "第二项", startAt: start.addingTimeInterval(11 * 3600), duration: 3600)
        let items = MacDailyTimelineLayout.calculate(tasks: [first, second], dayStart: start, dayEnd: end, hourHeight: 60)
        let firstFrame = try #require(items.first { $0.id == first.id }).frame
        let secondFrame = try #require(items.first { $0.id == second.id }).frame
        #expect(firstFrame.width == 0.5)
        #expect(secondFrame.width == 0.5)
        #expect(firstFrame.maxX <= secondFrame.minX || secondFrame.maxX <= firstFrame.minX)
    }

    @Test func midnightClippingDoesNotChangeUnderlyingTask() throws {
        let start = Calendar.current.startOfDay(for: Date())
        let end = try #require(Calendar.current.date(byAdding: .day, value: 1, to: start))
        let originalStart = start.addingTimeInterval(-1800)
        let task = DailyTask(title: "跨天任务", startAt: originalStart, duration: 7200)
        let item = try #require(MacDailyTimelineLayout.calculate(tasks: [task], dayStart: start, dayEnd: end, hourHeight: 60).first)
        #expect(item.startAt == start)
        #expect(item.duration == 5400)
        #expect(item.frame.minY == 0)
        #expect(task.startAt == originalStart)
        #expect(task.duration == 7200)
    }

    @Test func pointerSnapIsBoundedAtDayEdges() {
        #expect(MacDailyTimeMath.snapped(-80) == 0)
        #expect(MacDailyTimeMath.snapped(1448) == 1440)
        #expect(MacDailyTimeMath.snapped(608) == 615)
    }
}
