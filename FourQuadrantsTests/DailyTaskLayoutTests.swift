import Testing
import Foundation
@testable import FourQuadrants

struct DailyTaskLayoutTests {
    
    // Helper to create a dummy task
    private func createTask(id: UUID = UUID(), startHour: Int, durationHours: Double) -> DailyTask {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        components.hour = startHour
        components.minute = 0
        
        let start = calendar.date(from: components)!
        
        return DailyTask(
            title: "Test Task",
            scheduledDate: start,
            startTime: start,
            duration: durationHours * 3600,
            colorHex: "#000000"
        )
    }

    @Test func testNoOverlap() {
        // Task A: 9:00 - 10:00
        // Task B: 10:00 - 11:00
        let taskA = createTask(startHour: 9, durationHours: 1)
        let taskB = createTask(startHour: 10, durationHours: 1)
        
        let tasks = [taskA, taskB]
        let layout = DailyTaskLayout.calculateLayout(for: tasks, hourHeight: 60)
        
        // Both should check full width
        guard let layoutA = layout[taskA.id], let layoutB = layout[taskB.id] else {
            #expect(Bool(false), "Layout missing for tasks")
            return
        }
        
        #expect(layoutA.frame.width == 1.0)
        #expect(layoutA.frame.origin.x == 0.0)
        
        #expect(layoutB.frame.width == 1.0)
        #expect(layoutB.frame.origin.x == 0.0)
    }
    
    @Test func testSimpleOverlap() {
        // Task A: 9:00 - 10:00
        // Task B: 9:00 - 10:00
        // Should split width 50/50
        let taskA = createTask(startHour: 9, durationHours: 1)
        let taskB = createTask(startHour: 9, durationHours: 1)
        
        // Sort order might affect who is left/right, but widths should be 0.5
        let tasks = [taskA, taskB]
        let layout = DailyTaskLayout.calculateLayout(for: tasks, hourHeight: 60)
        
        guard let layoutA = layout[taskA.id], let layoutB = layout[taskB.id] else {
            #expect(Bool(false), "Layout missing for tasks")
            return
        }
        
        #expect(layoutA.frame.width == 0.5)
        #expect(layoutB.frame.width == 0.5)
        
        // One is at 0, one is at 0.5
        let xPositions = Set([layoutA.frame.origin.x, layoutB.frame.origin.x])
        #expect(xPositions.contains(0.0))
        #expect(xPositions.contains(0.5))
    }
    
    @Test func testTripleOverlap() {
        // Task A: 9:00 - 12:00
        // Task B: 9:30 - 10:30
        // Task C: 10:00 - 11:00
        // All three overlap at 10:00-10:30 window
        // Should share width (1/3 each roughly, or depending on column packing)
        
        let taskA = createTask(startHour: 9, durationHours: 3)
        let taskB = createTask(id: UUID(), startHour: 9, durationHours: 0.5) // Starts at 9:00 actually in helper, let's adjust manuall if needed but helper is hour based.
        // Let's stick to simple hour blocks for helper simplicity or adjust helper.
        // Re-using helper:
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 9, minute: 0))!
        
        let task1 = DailyTask(title: "1", scheduledDate: baseDate, startTime: baseDate, duration: 3600*3, colorHex: "") // 9-12
        let task2 = DailyTask(title: "2", scheduledDate: baseDate, startTime: baseDate.addingTimeInterval(1800), duration: 3600, colorHex: "") // 9:30-10:30
        let task3 = DailyTask(title: "3", scheduledDate: baseDate, startTime: baseDate.addingTimeInterval(3600), duration: 3600, colorHex: "") // 10:00-11:00
        
        let tasks = [task1, task2, task3]
        let layout = DailyTaskLayout.calculateLayout(for: tasks, hourHeight: 60)
        
        // Max overlap is 3 (at 10:00-10:30). So columns should be 3. width should be 1/3?
        // Standard algorithm:
        // A (9-12) -> Col 0
        // B (9:30-10:30) -> Col 1
        // C (10-11) -> Col 2 (overlaps A and B)
        // So max columns = 3. Width = 1/3.
        
        for task in tasks {
            guard let l = layout[task.id] else {
                #expect(Bool(false))
                continue
            }
            #expect(abs(l.frame.width - (1.0/3.0)) < 0.01, "Width should be approx 0.33")
        }
    }
}
