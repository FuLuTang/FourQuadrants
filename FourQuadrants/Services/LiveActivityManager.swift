@preconcurrency import ActivityKit
import SwiftData
import Foundation

/// 灵动岛管理器 - 负责启动/更新/结束 Live Activity
@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<FourQuadrantsWidgetAttributes>?
    private var timer: Timer?
    private var modelContainer: ModelContainer?
    
    // 缓存上一次的状态，用于判断是否需要更新
    private var lastTaskId: String?
    private var lastTaskName: String?
    private var lastStartTime: Date?
    private var lastEndTime: Date?
    private var lastColorHex: String?
    
    private init() {}
    
    // MARK: - 定时器
    
    func startTimerIfNeeded(container: ModelContainer) {
        self.modelContainer = container
        guard timer == nil else { return }

        reconcileExistingActivities()
        checkTask(context: container.mainContext)
        
        // 每60秒检查一次
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self, container] _ in
            Task { @MainActor [weak self] in
                self?.checkTask(context: container.mainContext)
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Reconnect to activities that outlive this process and remove stale duplicates.
    private func reconcileExistingActivities() {
        let activities = Activity<FourQuadrantsWidgetAttributes>.activities
        guard let primaryActivity = activities.first else { return }

        currentActivity = primaryActivity

        for duplicateActivity in activities.dropFirst() {
            Task {
                await duplicateActivity.end(
                    duplicateActivity.content,
                    dismissalPolicy: .immediate
                )
            }
        }
    }
    
    // MARK: - 核心逻辑 (基于伪代码)
    
    func checkTask(context: ModelContext) {
        // 0. 检查用户设置
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        // 注意: AppStorage 默认值为 true，但 UserDefaults.bool 默认返回 false
        // 所以我们需要检查是否是首次运行（没有设置过）
        let hasSetNotificationPref = UserDefaults.standard.object(forKey: "notificationsEnabled") != nil
        let isEnabled = hasSetNotificationPref ? notificationsEnabled : true
        
        guard isEnabled else {
            endActivityIfNeeded()
            return
        }
        
        // 1. 检查系统权限
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            endActivityIfNeeded()
            return
        }
        
        // 1. 查询：今天、未完成、正在进行的任务
        let now = Date()
        let activeTasks = fetchActiveTasks(context: context, now: now)
        
        // 2. 没有当前任务：结束灵动岛
        guard !activeTasks.isEmpty else {
            endActivityIfNeeded()
            return
        }
        
        // 3. 选择主任务（最先结束的优先）
        let selected = activeTasks.min { $0.endAt < $1.endAt }!
        let overlapCount = activeTasks.count - 1
        
        // 4. 构建显示名称
        var displayName = selected.title
        if overlapCount > 0 {
            displayName = "\(selected.title) +\(overlapCount)"
        }
        
        let newState = FourQuadrantsWidgetAttributes.ContentState(
            taskId: selected.id.uuidString,
            taskName: displayName,
            startAt: selected.startAt,
            endAt: selected.endAt,
            colorHex: selected.colorHex
        )
        
        // 5. 没有活动就启动，有活动就更新（仅变化时）
        if currentActivity == nil {
            startActivity(state: newState, staleDate: selected.endAt.addingTimeInterval(600))
        } else if lastTaskId != newState.taskId 
                    || lastTaskName != newState.taskName
                    || lastStartTime != newState.startAt
                    || lastEndTime != newState.endAt
                    || lastColorHex != newState.colorHex {
            updateActivity(state: newState, staleDate: selected.endAt.addingTimeInterval(600))
        }
        
        lastTaskId = newState.taskId
        lastTaskName = newState.taskName
        lastStartTime = newState.startAt
        lastEndTime = newState.endAt
        lastColorHex = newState.colorHex
    }
    
    // MARK: - SwiftData 查询
    
    private func fetchActiveTasks(context: ModelContext, now: Date) -> [DailyTask] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        let predicate = #Predicate<DailyTask> { task in
            task.startAt >= todayStart &&
            task.startAt < todayEnd &&
            task.completedAt == nil &&
            task.startAt <= now
        }
        
        let descriptor = FetchDescriptor<DailyTask>(predicate: predicate)
        
        do {
            let tasks = try context.fetch(descriptor)
            // 过滤：endAt > now (计算属性无法放入 Predicate)
            return tasks.filter { $0.endAt > now }
        } catch {
            print("❌ LiveActivityManager fetch error: \(error)")
            return []
        }
    }
    
    // MARK: - Activity 操作
    
    private func startActivity(state: FourQuadrantsWidgetAttributes.ContentState, staleDate: Date) {
        let attributes = FourQuadrantsWidgetAttributes()
        let content = ActivityContent(state: state, staleDate: staleDate)
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("✅ LiveActivity started: \(state.taskName)")
        } catch {
            print("❌ Failed to start LiveActivity: \(error)")
        }
    }
    
    private func updateActivity(state: FourQuadrantsWidgetAttributes.ContentState, staleDate: Date) {
        Task {
            let content = ActivityContent(state: state, staleDate: staleDate)
            await currentActivity?.update(content)
        }
    }
    
    private func endActivityIfNeeded() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
        
        currentActivity = nil
        lastTaskId = nil
        lastTaskName = nil
        lastStartTime = nil
        lastEndTime = nil
        lastColorHex = nil
    }
}
