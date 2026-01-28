import Testing
import Foundation
import SwiftData
@testable import FourQuadrants

@MainActor
struct FourQuadrantsTests {

    // MARK: - Task 逾期逻辑测试 (isOverdue)
    
    @Test func testTaskOverdueLogic() async throws {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        // 1. 预期：没有截止日期的任务永远不逾期
        let noTargetTask = Task(title: "无日期", date: Date(), targetDate: nil)
        #expect(noTargetTask.isOverdue == false, "没有截止日期的任务不应显示逾期")
        
        // 2. 预期：截止日期设为昨天，且未完成，应显示逾期 (逾期判断包含 1 天宽限)
        // 注意：目前逻辑是 targetDate.advanced(by: 86400) < Date()
        // 如果 targetDate 是昨天此时，+24小时正好是现在。为了确保逾期，用前天。
        let theDayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: Date())!
        let overdueTask = Task(title: "已逾期", date: Date(), targetDate: theDayBeforeYesterday, isCompleted: false)
        #expect(overdueTask.isOverdue == true, "过去日期的任务应显示逾期")
        
        // 3. 预期：截止日期是明天，不应逾期
        let upcomingTask = Task(title: "未到期", date: Date(), targetDate: tomorrow, isCompleted: false)
        #expect(upcomingTask.isOverdue == false, "未来日期的任务不应显示逾期")
        
        // 4. 预期：已完成的任务永远不显示逾期
        let completedOverdueTask = Task(title: "已完成但日期过期", date: Date(), targetDate: theDayBeforeYesterday, isCompleted: true)
        #expect(completedOverdueTask.isOverdue == false, "已完成的任务不应显示逾期状态")
    }

    // MARK: - Task 紧急逻辑测试 (isUrgent)

    @Test func testTaskUrgencyLogic() async throws {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let inFiveDays = calendar.date(byAdding: .day, value: 5, to: now)!
        
        // 1. 预期：手动设置紧急状态应生效
        let manualTask = Task(title: "手动紧急", date: now, isUrgent: true)
        #expect(manualTask.isUrgent == true, "手动设置的紧急状态应为 true")
        manualTask.isUrgent = false
        manualTask.manualIsUrgent = false // 确保 backing property 也更新，虽然 setter 应该处理
        #expect(manualTask.isUrgent == false, "手动取消后的紧急状态应为 false")
        
        // 2. 预期：设置了紧急阈值且日期在范围内，自动判定为紧急
        // 目标日期在 1 天后，阈值是 3 天 -> 应该紧急
        let urgentAutoTask = Task(title: "自动紧急", date: now, targetDate: tomorrow, urgentThresholdDays: 3)
        #expect(urgentAutoTask.isUrgent == true, "在阈值天数内的任务应自动判定为紧急")
        
        // 3. 预期：设置了紧急阈值但日期在范围外，自动判定为不紧急
        // 目标日期在 5 天后，阈值是 3 天 -> 不应该紧急
        let notUrgentAutoTask = Task(title: "自动不紧急", date: now, targetDate: inFiveDays, urgentThresholdDays: 3)
        #expect(notUrgentAutoTask.isUrgent == false, "在阈值天数外的任务不应自动判定为紧急")
    }

    // MARK: - TaskManager 排序算法测试 (Intelligence)

    @Test func testTaskManagerSorting() async throws {
        // SwiftData 需要上下文，但对于纯逻辑测试 sortTasks，我们可以通过创建内存容器来规避持久化副作用，
        // 或者直接测试 sortTasks 函数本身，因为它只依赖于 Task 对象数组，不依赖 Context。
        let manager = TaskManager()
        // 由于 TaskManager 初始化会自动加载数据，测试时我们可以直接传递一个新的数组给 sortTasks 函数，
        // 而不必依赖 manager.tasks 的状态。
        
        let now = Date()
        let tomorrow = calendarDate(daysFromNow: 1)
        let dayAfterTomorrow = calendarDate(daysFromNow: 2)
        
        // 创建不同种类的任务
        // 注意：Task 现在是 class，引用类型
        let lowPrio = Task(title: "普通任务", date: now, importance: .normal)
        let highPrio = Task(title: "高优任务", date: now, importance: .high)
        let pinnedTask = Task(title: "置顶任务", date: now, isTop: true)
        let earlierTarget = Task(title: "早期限任务", date: now, targetDate: tomorrow)
        let laterTarget = Task(title: "晚期限任务", date: now, targetDate: dayAfterTomorrow)
        
        let testTasks = [lowPrio, laterTarget, pinnedTask, earlierTarget, highPrio]
        
        let sorted = manager.sortTasks(testTasks, by: .intelligence)
        
        // 预期排序优先级：1.置顶 > 2.目标日期(由近到远) > 3.重要性(High > Normal) > 4.最后修改日期
        
        // 1. 预期：置顶任务排在第一位
        #expect(sorted[0].title == "置顶任务")
        
        // 2. 预期：有截止日期的紧随其后，且早期限的在前
        #expect(sorted[1].title == "早期限任务")
        #expect(sorted[2].title == "晚期限任务")
        
        // 3. 预期：剩下的按重要性排序
        #expect(sorted[3].title == "高优任务")
        #expect(sorted[4].title == "普通任务")
    }
    
    // 助手函数：获取相对日期
    private func calendarDate(daysFromNow: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
    }
}
