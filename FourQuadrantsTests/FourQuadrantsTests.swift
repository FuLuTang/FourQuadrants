import Testing
import Foundation
import SwiftData
@testable import FourQuadrants

@MainActor
struct FourQuadrantsTests {

    // MARK: - Task 逾期逻辑测试 (isOverdue)
    
    @Test func testTaskOverdueLogic() async throws {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        // 1. 没有截止日期 → 不逾期
        let noTargetTask = QuadrantTask(title: "无日期", date: Date(), targetDate: nil)
        #expect(noTargetTask.isOverdue == false, "没有截止日期的任务不应显示逾期")
        
        // 2. 截止日期已过2天 → 逾期（逾期判断包含1天宽限）
        let theDayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: Date())!
        let overdueTask = QuadrantTask(title: "已逾期", date: Date(), targetDate: theDayBeforeYesterday, isCompleted: false)
        #expect(overdueTask.isOverdue == true, "过去日期的任务应显示逾期")
        
        // 3. 截止日期是明天 → 不逾期
        let upcomingTask = QuadrantTask(title: "未到期", date: Date(), targetDate: tomorrow, isCompleted: false)
        #expect(upcomingTask.isOverdue == false, "未来日期的任务不应显示逾期")
        
        // 4. 已完成 → 不逾期
        let completedOverdueTask = QuadrantTask(title: "已完成但日期过期", date: Date(), targetDate: theDayBeforeYesterday, isCompleted: true)
        #expect(completedOverdueTask.isOverdue == false, "已完成的任务不应显示逾期状态")
    }

    // MARK: - Task 紧急逻辑测试 (isUrgent)

    @Test func testTaskUrgencyLogic() async throws {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let inFiveDays = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        
        // 1. 手动设置紧急
        let manualTask = QuadrantTask(title: "手动紧急", date: now, isUrgent: true)
        #expect(manualTask.isUrgent == true)
        manualTask.manualIsUrgent = false
        #expect(manualTask.isUrgent == false)
        
        // 2. 阈值内 → 自动紧急
        let urgentAutoTask = QuadrantTask(title: "自动紧急", date: now, targetDate: tomorrow, urgentThresholdDays: 3)
        #expect(urgentAutoTask.isUrgent == true, "在阈值天数内应自动紧急")
        
        // 3. 阈值外 → 不紧急
        let notUrgentAutoTask = QuadrantTask(title: "自动不紧急", date: now, targetDate: inFiveDays, urgentThresholdDays: 3)
        #expect(notUrgentAutoTask.isUrgent == false, "在阈值天数外不应紧急")
    }

    // MARK: - 双紧急阈值测试 (新逻辑)

    // --- 1. 创建场景 ---

    @Test func testDualThresholdCreation() async throws {
        let now = Date()
        let inFiveDays = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        
        let task = QuadrantTask(title: "双阈值任务", date: now, targetDate: inFiveDays,
                       urgentThresholdDays: 3, originalUrgentThresholdDays: 3)
        #expect(task.urgentThresholdDays == 3)
        #expect(task.originalUrgentThresholdDays == 3)
        #expect(task.isUrgent == false, "5天后、阈值3天 → 不紧急")
    }

    @Test func testCreationWithoutThreshold() async throws {
        let task = QuadrantTask(title: "无阈值", date: Date())
        #expect(task.urgentThresholdDays == nil)
        #expect(task.originalUrgentThresholdDays == nil)
        #expect(task.isUrgent == false)
    }

    // --- 2. isUrgent 始终读取 urgentThresholdDays ---

    @Test func testIsUrgentReadsAutoThreshold() async throws {
        let now = Date()
        let inFiveDays = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        
        // auto=5（紧急），original=3
        let task = QuadrantTask(title: "读自动阈值", date: now, targetDate: inFiveDays,
                       urgentThresholdDays: 5, originalUrgentThresholdDays: 3)
        #expect(task.isUrgent == true, "auto=5, 5<=5 → 紧急")
        
        task.urgentThresholdDays = 3
        #expect(task.isUrgent == false, "auto=3, 5>3 → 不紧急")
        #expect(task.originalUrgentThresholdDays == 3, "原始阈值不变")
    }

    // --- 3. 紧急→不紧急：统一 threshold = nil ---

    @Test func testDragUrgentToNotUrgent_AlwaysNilThreshold() async throws {
        // 新逻辑：拖到不紧急 → 一律 threshold = nil, manual = false
        let now = Date()
        let inFiveDays = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        
        // 场景 A：原始阈值下本就不紧急 (original=3, remaining≈5)
        let taskA = QuadrantTask(title: "A", date: now, targetDate: inFiveDays,
                       urgentThresholdDays: 5, originalUrgentThresholdDays: 3)
        taskA.urgentThresholdDays = nil
        taskA.manualIsUrgent = false
        #expect(taskA.isUrgent == false)
        #expect(taskA.urgentThresholdDays == nil, "阈值开关应为 OFF")
        #expect(taskA.originalUrgentThresholdDays == 3, "原始阈值保留")
        
        // 场景 B：原始阈值下仍紧急 (original=3, remaining≈2)
        let inTwoDays = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        let taskB = QuadrantTask(title: "B", date: now, targetDate: inTwoDays,
                       urgentThresholdDays: 3, originalUrgentThresholdDays: 3)
        taskB.urgentThresholdDays = nil
        taskB.manualIsUrgent = false
        #expect(taskB.isUrgent == false)
        #expect(taskB.urgentThresholdDays == nil, "阈值开关应为 OFF")
        #expect(taskB.originalUrgentThresholdDays == 3, "原始阈值保留")
        
        // 场景 C：无原始阈值
        let taskC = QuadrantTask(title: "C", date: now, isUrgent: true)
        taskC.urgentThresholdDays = nil
        taskC.manualIsUrgent = false
        #expect(taskC.isUrgent == false)
        #expect(taskC.originalUrgentThresholdDays == nil)
    }

    // --- 4. 不紧急→紧急：优先恢复原始阈值 ---

    @Test func testDragNotUrgentToUrgent_OriginalQualifies() async throws {
        // 场景：2天后任务，original=5 → remaining(2) <= original(5) → 恢复 original
        let now = Date()
        let inTwoDays = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        
        let task = QuadrantTask(title: "恢复原始", date: now, targetDate: inTwoDays,
                       originalUrgentThresholdDays: 5)
        // 模拟之前拖到不紧急（threshold=nil）
        task.urgentThresholdDays = nil
        task.manualIsUrgent = false
        #expect(task.isUrgent == false)
        
        // 拖回紧急：remaining=2 <= original=5 → 用 original
        let remaining = daysRemaining(to: inTwoDays)
        let original = task.originalUrgentThresholdDays!
        if remaining <= original {
            task.urgentThresholdDays = original
        } else {
            task.urgentThresholdDays = max(remaining, 0)
        }
        task.manualIsUrgent = true
        
        #expect(task.urgentThresholdDays == 5, "应恢复原始阈值 5，而不是重算为 2")
        #expect(task.isUrgent == true)
        #expect(task.originalUrgentThresholdDays == 5, "原始阈值不变")
    }

    @Test func testDragNotUrgentToUrgent_OriginalNotEnough() async throws {
        // 场景：5天后任务，original=3 → remaining(5) > original(3) → 强算 remaining
        let now = Date()
        let inFiveDays = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        
        let task = QuadrantTask(title: "强算", date: now, targetDate: inFiveDays,
                       originalUrgentThresholdDays: 3)
        task.urgentThresholdDays = nil
        task.manualIsUrgent = false
        
        let remaining = daysRemaining(to: inFiveDays)
        let original = task.originalUrgentThresholdDays!
        if remaining <= original {
            task.urgentThresholdDays = original
        } else {
            task.urgentThresholdDays = max(remaining, 0)
        }
        task.manualIsUrgent = true
        
        #expect(task.urgentThresholdDays == 5, "original(3)不够，强算为 remaining(5)")
        #expect(task.isUrgent == true)
    }

    @Test func testDragNotUrgentToUrgent_NoOriginal() async throws {
        // 无原始阈值 → 强算为 remaining
        let now = Date()
        let inFiveDays = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        
        let task = QuadrantTask(title: "无原始", date: now, targetDate: inFiveDays)
        
        // 拖入紧急，无 original → 按 remaining 算
        let remaining = daysRemaining(to: inFiveDays)
        task.urgentThresholdDays = max(remaining, 0)
        task.manualIsUrgent = true
        
        #expect(task.urgentThresholdDays == 5)
        #expect(task.isUrgent == true)
    }

    @Test func testDragNotUrgentToUrgent_NoTargetDate() async throws {
        let task = QuadrantTask(title: "无日期", date: Date())
        task.manualIsUrgent = true
        
        #expect(task.isUrgent == true)
        #expect(task.urgentThresholdDays == nil, "无目标日期不设阈值")
    }

    // --- 5. 完整来回拖拽 ---

    @Test func testFullRoundTripDrag() async throws {
        let now = Date()
        let inTwoDays = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        
        // 创建：original=5, auto=5, remaining≈2, 2<=5 → 紧急
        let task = QuadrantTask(title: "来回", date: now, targetDate: inTwoDays,
                       urgentThresholdDays: 5, originalUrgentThresholdDays: 5)
        #expect(task.isUrgent == true)
        
        // Step 1: 拖到不紧急 → threshold=nil
        task.urgentThresholdDays = nil
        task.manualIsUrgent = false
        #expect(task.isUrgent == false)
        #expect(task.urgentThresholdDays == nil, "阈值开关 OFF")
        
        // Step 2: 拖回紧急 → remaining(2) <= original(5) → 恢复 5
        let remaining = daysRemaining(to: inTwoDays)
        task.urgentThresholdDays = (remaining <= task.originalUrgentThresholdDays!) ? task.originalUrgentThresholdDays! : max(remaining, 0)
        task.manualIsUrgent = true
        #expect(task.urgentThresholdDays == 5, "恢复原始阈值 5")
        #expect(task.isUrgent == true)
        
        // 原始阈值从始至终不变
        #expect(task.originalUrgentThresholdDays == 5)
    }

    @Test func testMultipleRoundTripDrags() async throws {
        let now = Date()
        let inTwoDays = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        
        let task = QuadrantTask(title: "多次", date: now, targetDate: inTwoDays,
                       urgentThresholdDays: 5, originalUrgentThresholdDays: 5)
        
        for _ in 1...3 {
            // 拖出：threshold = nil
            task.urgentThresholdDays = nil
            task.manualIsUrgent = false
            #expect(task.isUrgent == false)
            
            // 拖回：恢复 original
            task.urgentThresholdDays = task.originalUrgentThresholdDays!
            task.manualIsUrgent = true
            #expect(task.isUrgent == true)
        }
        
        #expect(task.originalUrgentThresholdDays == 5, "多次拖拽后原始阈值不变")
        #expect(task.urgentThresholdDays == 5)
    }

    // --- 6. 边界场景 ---

    @Test func testThresholdWithPastTargetDate() async throws {
        let now = Date()
        let pastDate = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        
        let task = QuadrantTask(title: "过期任务", date: now, targetDate: pastDate,
                       urgentThresholdDays: 3, originalUrgentThresholdDays: 3)
        #expect(task.isUrgent == true, "过期任务在阈值下应为紧急")
    }

    @Test func testThresholdExactlyOnBoundary() async throws {
        let now = Date()
        let inThreeDays = Calendar.current.date(byAdding: .day, value: 3, to: now)!
        
        let task = QuadrantTask(title: "边界", date: now, targetDate: inThreeDays,
                       urgentThresholdDays: 3, originalUrgentThresholdDays: 3)
        #expect(task.isUrgent == true, "daysRemaining=3, threshold=3, 3<=3 → 紧急")
    }

    // MARK: - 重要性双轨追踪测试 (originalImportance)

    @Test func testOriginalImportanceCreation() async throws {
        let task = QuadrantTask(title: "测试", date: Date(), importance: .low, originalImportance: .low)
        #expect(task.importance == .low)
        #expect(task.originalImportance == .low)
    }

    @Test func testDragImportantToNotImportant_OriginalLow() async throws {
        // original = .low → 拖到不重要 → 恢复 .low
        let task = QuadrantTask(title: "low恢复", date: Date(), importance: .high, originalImportance: .low)
        #expect(task.isImportantQuadrant == true)
        
        // 拖到不重要：恢复 originalImportance
        if let original = task.originalImportance {
            task.importance = (original == .high) ? .normal : original
        }
        
        #expect(task.importance == .low, "原始是 .low → 恢复 .low")
        #expect(task.originalImportance == .low, "原始重要性不变")
    }

    @Test func testDragImportantToNotImportant_OriginalNormal() async throws {
        // original = .normal → 拖到不重要 → 恢复 .normal
        let task = QuadrantTask(title: "normal恢复", date: Date(), importance: .high, originalImportance: .normal)
        
        if let original = task.originalImportance {
            task.importance = (original == .high) ? .normal : original
        }
        
        #expect(task.importance == .normal, "原始是 .normal → 恢复 .normal")
    }

    @Test func testDragImportantToNotImportant_OriginalHigh() async throws {
        // original = .high → 拖到不重要 → 没法恢复 → 降为 .normal
        let task = QuadrantTask(title: "high降级", date: Date(), importance: .high, originalImportance: .high)
        
        if let original = task.originalImportance {
            task.importance = (original == .high) ? .normal : original
        }
        
        #expect(task.importance == .normal, "原始是 .high → 降为 .normal")
        #expect(task.originalImportance == .high, "原始重要性不变")
    }

    @Test func testDragNotImportantToImportant() async throws {
        // 拖到重要 → importance = .high
        let task = QuadrantTask(title: "升级", date: Date(), importance: .low, originalImportance: .low)
        task.importance = .high
        
        #expect(task.importance == .high)
        #expect(task.originalImportance == .low, "原始重要性不变")
        #expect(task.isImportantQuadrant == true)
    }

    @Test func testImportanceRoundTrip() async throws {
        // .low → 拖到重要(.high) → 拖回不重要(.low) → 完整来回
        let task = QuadrantTask(title: "重要性来回", date: Date(), importance: .low, originalImportance: .low)
        
        // 拖到重要
        task.importance = .high
        #expect(task.isImportantQuadrant == true)
        
        // 拖回不重要
        if let original = task.originalImportance {
            task.importance = (original == .high) ? .normal : original
        }
        #expect(task.importance == .low, "应恢复为原始 .low")
        #expect(task.isImportantQuadrant == false)
    }

    // MARK: - TaskManager 排序算法测试 (Intelligence)

    @Test func testTaskManagerSorting() async throws {
        let now = Date()
        let tomorrow = calendarDate(daysFromNow: 1)
        let dayAfterTomorrow = calendarDate(daysFromNow: 2)
        
        let lowPrio = QuadrantTask(title: "普通任务", date: now, importance: .normal)
        let highPrio = QuadrantTask(title: "高优任务", date: now, importance: .high)
        let pinnedTask = QuadrantTask(title: "置顶任务", date: now, isTop: true)
        let earlierTarget = QuadrantTask(title: "早期限任务", date: now, targetDate: tomorrow)
        let laterTarget = QuadrantTask(title: "晚期限任务", date: now, targetDate: dayAfterTomorrow)
        
        let testTasks = [lowPrio, laterTarget, pinnedTask, earlierTarget, highPrio]
        
        let sorted = testTasks.sorted { a, b in
            if a.isTop != b.isTop { return a.isTop }
            if let aTarget = a.targetDate, let bTarget = b.targetDate {
                return aTarget < bTarget
            }
            if a.targetDate != nil && b.targetDate == nil { return true }
            if a.targetDate == nil && b.targetDate != nil { return false }
            if a.importance != b.importance { return a.importance == .high }
            return a.dateLatestModified > b.dateLatestModified
        }
        
        #expect(sorted[0].title == "置顶任务")
        #expect(sorted[1].title == "早期限任务")
        #expect(sorted[2].title == "晚期限任务")
        #expect(sorted[3].title == "高优任务")
        #expect(sorted[4].title == "普通任务")
    }
    
    // MARK: - 助手函数
    
    private func calendarDate(daysFromNow: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
    }
    
    private func daysRemaining(to targetDate: Date) -> Int {
        let now = Calendar.current.startOfDay(for: Date())
        let targetDay = Calendar.current.startOfDay(for: targetDate)
        return Calendar.current.dateComponents([.day], from: now, to: targetDay).day ?? 0
    }
}
