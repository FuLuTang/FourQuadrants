import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TaskStore {
    enum QuadrantTaskMutation {
        case upsert(UUID)
        case delete(UUID)
    }

    private let modelContext: ModelContext
    private let saveOperation: () throws -> Void

    var lastErrorMessage: String?
    var quadrantTaskMutationHandler: ((QuadrantTaskMutation) -> Void)?

    init(modelContext: ModelContext, saveOperation: (() throws -> Void)? = nil) {
        self.modelContext = modelContext
        self.saveOperation = saveOperation ?? { try modelContext.save() }
    }

    @discardableResult
    func addTask(
        title: String,
        notes: String? = nil,
        importance: ImportanceLevel,
        isUrgent: Bool,
        isTop: Bool,
        dueAt: Date? = nil,
        urgentThresholdDays: Int? = nil,
        originalUrgentThresholdDays: Int? = nil,
        originalImportance: ImportanceLevel? = nil
    ) -> Bool {
        let task = QuadrantTask(
            title: title,
            notes: notes,
            dueAt: dueAt,
            importance: importance,
            isUrgent: isUrgent,
            urgentThresholdDays: urgentThresholdDays,
            originalUrgentThresholdDays: originalUrgentThresholdDays,
            originalImportance: originalImportance,
            isTop: isTop
        )
        modelContext.insert(task)
        let saved = saveChanges()
        if saved { quadrantTaskMutationHandler?(.upsert(task.id)) }
        return saved
    }

    @discardableResult
    func updateTask(
        _ task: QuadrantTask,
        title: String,
        notes: String? = nil,
        importance: ImportanceLevel,
        isUrgent: Bool,
        isTop: Bool,
        dueAt: Date?,
        urgentThresholdDays: Int? = nil,
        originalUrgentThresholdDays: Int? = nil,
        originalImportance: ImportanceLevel? = nil
    ) -> Bool {
        task.title = title
        task.notes = notes
        task.importance = importance
        task.manualIsUrgent = isUrgent
        task.dueAt = dueAt
        task.urgentThresholdDays = urgentThresholdDays
        task.originalUrgentThresholdDays = originalUrgentThresholdDays
        task.originalImportance = originalImportance
        task.isTop = isTop
        task.updatedAt = Date()
        let saved = saveChanges()
        if saved { quadrantTaskMutationHandler?(.upsert(task.id)) }
        return saved
    }

    @discardableResult
    func toggleTask(_ task: QuadrantTask) -> Bool {
        task.isCompleted.toggle()
        task.updatedAt = Date()
        let saved = saveChanges()
        if saved { quadrantTaskMutationHandler?(.upsert(task.id)) }
        return saved
    }

    @discardableResult
    func removeTask(_ task: QuadrantTask) -> Bool {
        let taskID = task.id
        modelContext.delete(task)
        let saved = saveChanges()
        if saved { quadrantTaskMutationHandler?(.delete(taskID)) }
        return saved
    }

    @discardableResult
    func createDailyTask(title: String, startAt: Date, duration: TimeInterval, colorHex: String?, notes: String? = nil, quadrantTask: QuadrantTask? = nil) -> DailyTask? {
        let task = DailyTask(title: title, startAt: startAt, duration: duration, colorHex: colorHex, notes: notes, quadrantTask: quadrantTask)
        modelContext.insert(task)
        return saveChanges() ? task : nil
    }

    @discardableResult
    func updateDailyTask(_ task: DailyTask, title: String, startAt: Date, duration: TimeInterval, colorHex: String?, notes: String?, quadrantTask: QuadrantTask? = nil) -> Bool {
        task.title = title
        task.startAt = startAt
        task.duration = duration
        task.colorHex = colorHex
        task.notes = notes
        task.quadrantTask = quadrantTask
        task.updatedAt = Date()
        return saveChanges()
    }

    @discardableResult
    func moveDailyTask(_ task: DailyTask, startAt: Date, duration: TimeInterval) -> Bool {
        task.startAt = startAt
        task.duration = duration
        task.updatedAt = Date()
        return saveChanges()
    }

    func previewDailyTaskLayout(_ task: DailyTask, startAt: Date, duration: TimeInterval) {
        task.startAt = startAt
        task.duration = duration
    }

    @discardableResult
    func commitDailyTaskLayout(_ task: DailyTask) -> Bool {
        task.updatedAt = Date()
        return saveChanges()
    }

    func restoreDailyTaskLayout(_ task: DailyTask, startAt: Date, duration: TimeInterval) {
        task.startAt = startAt
        task.duration = duration
    }

    @discardableResult
    func toggleDailyTask(_ task: DailyTask) -> Bool {
        task.isCompleted.toggle()
        task.updatedAt = Date()
        return saveChanges()
    }

    @discardableResult
    func removeDailyTask(_ task: DailyTask) -> Bool {
        modelContext.delete(task)
        return saveChanges()
    }

    @discardableResult
    func moveTask(_ task: QuadrantTask, to category: TaskCategory) -> Bool {
        let expectsUrgent: Bool
        let expectsImportant: Bool
        switch category {
        case .importantAndUrgent: (expectsUrgent, expectsImportant) = (true, true)
        case .importantButNotUrgent: (expectsUrgent, expectsImportant) = (false, true)
        case .urgentButNotImportant: (expectsUrgent, expectsImportant) = (true, false)
        case .notImportantAndNotUrgent: (expectsUrgent, expectsImportant) = (false, false)
        case .all, .completed: return false
        }

        if expectsUrgent && !task.isUrgent {
            if let dueAt = task.dueAt {
                let remaining = daysRemaining(to: dueAt)
                task.urgentThresholdDays = task.originalUrgentThresholdDays.flatMap { remaining <= $0 ? $0 : nil } ?? max(remaining, 0)
            }
            task.manualIsUrgent = true
        } else if !expectsUrgent && task.isUrgent {
            task.urgentThresholdDays = nil
            task.manualIsUrgent = false
        }

        if expectsImportant && !task.isImportantQuadrant {
            task.importance = .high
        } else if !expectsImportant && task.isImportantQuadrant {
            task.importance = task.originalImportance.map { $0 == .high ? .normal : $0 } ?? .normal
        }
        task.updatedAt = Date()
        let saved = saveChanges()
        if saved { quadrantTaskMutationHandler?(.upsert(task.id)) }
        return saved
    }

    func filteredTasks(_ tasks: [QuadrantTask], in category: TaskCategory, now: Date = Date()) -> [QuadrantTask] {
        let visible = tasks.filter { task in
            let isVisible = !task.isCompleted || now.timeIntervalSince(task.completedAt ?? now) <= 3
            switch category {
            case .all: return isVisible
            case .importantAndUrgent: return task.isImportantQuadrant && task.isUrgent && isVisible
            case .importantButNotUrgent: return task.isImportantQuadrant && !task.isUrgent && isVisible
            case .urgentButNotImportant: return !task.isImportantQuadrant && task.isUrgent && isVisible
            case .notImportantAndNotUrgent: return !task.isImportantQuadrant && !task.isUrgent && isVisible
            case .completed: return task.isCompleted
            }
        }
        return sortTasks(visible, by: .intelligence)
    }

    func sortTasks(_ tasks: [QuadrantTask], by method: TaskSortMethod) -> [QuadrantTask] {
        tasks.sorted { first, second in
            switch method {
            case .intelligence:
                if first.isTop != second.isTop { return first.isTop }
                if first.dueAt != second.dueAt { return (first.dueAt ?? .distantFuture) < (second.dueAt ?? .distantFuture) }
                let priority: [ImportanceLevel] = [.high, .normal, .low]
                if first.importance != second.importance { return priority.firstIndex(of: first.importance)! < priority.firstIndex(of: second.importance)! }
                return first.updatedAt < second.updatedAt
            case .byDueDate: return (first.dueAt ?? .distantFuture) < (second.dueAt ?? .distantFuture)
            case .byCreationDate: return first.createdAt < second.createdAt
            case .byName: return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }
        }
    }

    func dismissLastError() { lastErrorMessage = nil }

    private func saveChanges() -> Bool {
        do {
            try saveOperation()
            lastErrorMessage = nil
            return true
        } catch {
            modelContext.rollback()
            lastErrorMessage = "保存失败，请重试。"
            return false
        }
    }

    private func daysRemaining(to dueAt: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: dueAt)).day ?? 0
    }

    enum TaskSortMethod { case intelligence, byDueDate, byCreationDate, byName }
}
