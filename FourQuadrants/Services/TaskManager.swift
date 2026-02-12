import SwiftUI
import Combine
import SwiftData

@MainActor
class TaskManager: ObservableObject {
    @Published var tasks: [QuadrantTask] = []
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        fetchTasks()
        
        // Initial setup for empty state (Demo data)
        if tasks.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy.MM.dd"
            
            let demoTasks = [
                QuadrantTask(title: "重要且紧急任务", date: dateFormatter.date(from: "2023.01.01")!, isCompleted: false, importance: .high, isUrgent: true),
                QuadrantTask(title: "重要不紧急任务", date: dateFormatter.date(from: "2023.06.01")!, targetDate: dateFormatter.date(from: "2025.01.02")!, isCompleted: false, importance: .high, isUrgent: false),
                QuadrantTask(title: "紧急不重要任务", date: dateFormatter.date(from: "2024.01.01")!, targetDate: dateFormatter.date(from: "2025.03.02")!, isCompleted: false, importance: .normal, isUrgent: true),
                QuadrantTask(title: "不重要不紧急任务", date: dateFormatter.date(from: "2024.06.01")!, isCompleted: false, isUrgent: false),
                QuadrantTask(title: "额外任务", date: dateFormatter.date(from: "2025.01.01")!, isCompleted: false, isUrgent: false),
                QuadrantTask(title: "安装日期+1", date: Date(), targetDate: Date().addingTimeInterval(86400), isCompleted: false, isUrgent: false),
                QuadrantTask(title: "安装日期-1", date: Date(), targetDate: Date().addingTimeInterval(-86400), isCompleted: false, isUrgent: false),
                QuadrantTask(title: "置顶", date: Date(), targetDate: Date().addingTimeInterval(-86400), isCompleted: false, isUrgent: false, isTop: true)
            ]
            
            // Batch insert
            for task in demoTasks {
                modelContext.insert(task)
            }
            saveContext()
            fetchTasks()
        }
        
        // Auto-sync on launch (skip in previews to avoid hangs)
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            triggerSync()
        }
    }
    
    // MARK: - Sync
    
    func triggerSync() {
        Task {
            await SyncService.shared.startSync(context: modelContext)
            // Refresh UI after sync
            fetchTasks()
        }
    }
    
    // MARK: - Core Data Operations
    
    func fetchTasks() {
        do {
            let descriptor = FetchDescriptor<QuadrantTask>(sortBy: [SortDescriptor(\.dateLatestModified, order: .reverse)])
            tasks = try modelContext.fetch(descriptor)
        } catch {
            print("Fetch failed: \(error)")
        }
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
            fetchTasks() // Refresh local array after save
        } catch {
            print("Save failed: \(error)")
        }
    }

    func addTask(title: String, importance: ImportanceLevel, isUrgent: Bool, isTop: Bool, targetDate: Date? = nil, urgentThresholdDays: Int? = nil, originalUrgentThresholdDays: Int? = nil, originalImportance: ImportanceLevel? = nil, dateLatestModified: Date) {
        let newTask = QuadrantTask(
            title: title,
            date: Date(), // Creation date
            dateLatestModified: Date(),
            targetDate: targetDate,
            isCompleted: false,
            importance: importance,
            isUrgent: isUrgent,
            urgentThresholdDays: urgentThresholdDays,
            originalUrgentThresholdDays: originalUrgentThresholdDays,
            originalImportance: originalImportance,
            isTop: isTop
        )
        modelContext.insert(newTask)
        saveContext()
    }

    func updateTask(_ task: QuadrantTask, title: String, importance: ImportanceLevel, isUrgent: Bool, isTop: Bool, targetDate: Date?, urgentThresholdDays: Int? = nil, originalUrgentThresholdDays: Int? = nil, originalImportance: ImportanceLevel? = nil, dateLatestModified: Date) {
        // SwiftData objects are reference types (classes). We can modify them directly.
        task.title = title
        task.importance = importance
        task.originalImportance = originalImportance
        task.manualIsUrgent = isUrgent // Directly update backing property
        task.targetDate = targetDate
        task.urgentThresholdDays = urgentThresholdDays
        task.originalUrgentThresholdDays = originalUrgentThresholdDays
        task.isTop = isTop
        task.dateLatestModified = Date()
        
        saveContext()
        objectWillChange.send()
    }
    
    func toggleTask(_ task: QuadrantTask) {
        withAnimation(.easeInOut) {
            task.isCompleted.toggle()
            task.completionDate = task.isCompleted ? Date() : nil
            saveContext()
            objectWillChange.send()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut) {
                self.objectWillChange.send()
            }
        }
    }

    func removeTask(by id: UUID) {
        if let taskToDelete = tasks.first(where: { $0.id == id }) {
            modelContext.delete(taskToDelete)
            saveContext()
        }
    }

    // MARK: - Sorting Logic
    
    enum TaskSortMethod {
        case intelligence   // 现置顶 -> 目标日 -> 创建日
        case byTargetDate   // 仅按目标日排序
        case byCreationDate // 仅按创建日期排序
        case byName
    }
    
    func sortTasks(_ tasks: [QuadrantTask], by method: TaskSortMethod) -> [QuadrantTask] {
        return tasks.sorted { task1, task2 in
            switch method {
            case .intelligence:
                // 1. 置顶任务优先
                if task1.isTop != task2.isTop {
                    return task1.isTop && !task2.isTop
                }
                // 2. 目标日期优先
                if let date1 = task1.targetDate, let date2 = task2.targetDate {
                    return date1 < date2
                } else if task1.targetDate != nil {
                    return true
                } else if task2.targetDate != nil {
                    return false
                }
                // 3. 按重要度排序（high > normal > low）
                let importanceOrder: [ImportanceLevel] = [.high, .normal, .low]
                if let index1 = importanceOrder.firstIndex(of: task1.importance),
                   let index2 = importanceOrder.firstIndex(of: task2.importance) {
                    return index1 < index2
                }
                // 4. 修改日期排序（较早创建的任务排前）
                return task1.dateLatestModified < task2.dateLatestModified

            case .byTargetDate:
                return (task1.targetDate ?? .distantFuture) < (task2.targetDate ?? .distantFuture)

            case .byCreationDate:
                return task1.date < task2.date
            
            case .byName:
                return task1.title < task2.title
            }
        }
    }

    func dragTaskChangeCategory(task: QuadrantTask, targetCategory: TaskCategory) {
        // --- 判定目标象限的期望状态 ---
        let expectsUrgent: Bool = {
            switch targetCategory {
            case .importantAndUrgent, .urgentButNotImportant: return true
            case .importantButNotUrgent, .notImportantAndNotUrgent: return false
            default: return task.isUrgent
            }
        }()
        let expectsImportant: Bool = {
            switch targetCategory {
            case .importantAndUrgent, .importantButNotUrgent: return true
            case .urgentButNotImportant, .notImportantAndNotUrgent: return false
            default: return task.isImportantQuadrant
            }
        }()
        
        // === 紧急性处理 ===
        let wasUrgent = task.isUrgent
        
        if expectsUrgent && !wasUrgent {
            // 不紧急 → 紧急：优先尝试恢复原始阈值
            if let targetDate = task.targetDate {
                let remaining = daysRemaining(to: targetDate)
                if let original = task.originalUrgentThresholdDays, remaining <= original {
                    // 原始阈值放到现在算 = 紧急 → 恢复原始值
                    task.urgentThresholdDays = original
                } else {
                    // 原始阈值不存在或不够紧急 → 强算为剩余天数
                    task.urgentThresholdDays = max(remaining, 0)
                }
                task.manualIsUrgent = true
            } else {
                // 无目标日期，仅靠手动标记
                task.manualIsUrgent = true
            }
        } else if !expectsUrgent && wasUrgent {
            // 紧急 → 不紧急：关闭阈值开关，保留原始阈值数据
            task.urgentThresholdDays = nil
            task.manualIsUrgent = false
            // 注意：originalUrgentThresholdDays 不动
        }
        // 如果紧急状态不变，不做任何操作
        
        // === 重要性处理 ===
        let wasImportant = task.isImportantQuadrant
        
        if expectsImportant && !wasImportant {
            // 不重要 → 重要
            task.importance = .high
        } else if !expectsImportant && wasImportant {
            // 重要 → 不重要：尝试恢复原始重要性
            if let original = task.originalImportance {
                // 原始是 .high → 没法恢复（否则又变重要），降为 .normal
                // 原始是 .normal → 恢复 .normal
                // 原始是 .low → 恢复 .low
                task.importance = (original == .high) ? .normal : original
            } else {
                task.importance = .normal
            }
        }
        // 如果重要性不变，不做任何操作
        
        // **更新最后编辑日期**
        task.dateLatestModified = Date()
        
        saveContext()
        objectWillChange.send()
    }
    
    // MARK: - 辅助方法
    
    /// 计算从今天到目标日期的剩余天数
    private func daysRemaining(to targetDate: Date) -> Int {
        let now = Calendar.current.startOfDay(for: Date())
        let targetDay = Calendar.current.startOfDay(for: targetDate)
        return Calendar.current.dateComponents([.day], from: now, to: targetDay).day ?? 0
    }

    func filteredTasks(in category: TaskCategory) -> [QuadrantTask] {
        let now = Date()
        let filtered = tasks.filter { task in
            let isImportant = task.isImportantQuadrant
            
            // Logic to keep completed tasks visible for 3 seconds
            let isVisible = !task.isCompleted || now.timeIntervalSince(task.completionDate ?? now) <= 3.0
            
            switch category {
            case .all:
                return isVisible
            case .importantAndUrgent:
                return isImportant && task.isUrgent && isVisible
            case .importantButNotUrgent:
                return isImportant && !task.isUrgent && isVisible
            case .urgentButNotImportant:
                return !isImportant && task.isUrgent && isVisible
            case .notImportantAndNotUrgent:
                return !isImportant && !task.isUrgent && isVisible
            case .completed:
                return task.isCompleted
            }
        }
        return sortTasks(filtered, by: .intelligence)
    }
}
