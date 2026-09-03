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
    /// Records a durable Microsoft operation before the task context is committed.
    var quadrantTaskMutationRecorder: ((QuadrantTaskMutation) throws -> Void)?
    /// Starts background delivery only after the local task and its outbox record are durable.
    var quadrantTaskMutationDidCommit: (() -> Void)?

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
        return commitQuadrantTaskMutation(.upsert(task.id)) {
            task.setDueDate(dueAt)
            modelContext.insert(task)
        }
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
        commitQuadrantTaskMutation(.upsert(task.id)) {
            task.title = title
            task.notes = notes
            task.importance = importance
            task.manualIsUrgent = isUrgent
            task.setDueDate(dueAt)
            task.urgentThresholdDays = urgentThresholdDays
            task.originalUrgentThresholdDays = originalUrgentThresholdDays
            task.originalImportance = originalImportance
            task.isTop = isTop
            task.updatedAt = Date()
        }
    }

    @discardableResult
    func toggleTask(_ task: QuadrantTask) -> Bool {
        commitQuadrantTaskMutation(.upsert(task.id)) {
            task.isCompleted.toggle()
            task.updatedAt = Date()
        }
    }

    @discardableResult
    func removeTask(_ task: QuadrantTask) -> Bool {
        commitQuadrantTaskMutation(.delete(task.id)) {
            modelContext.delete(task)
        }
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
            if let dueAt = task.displayDueDate {
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
        return commitQuadrantTaskMutation(.upsert(task.id)) {
            task.updatedAt = Date()
        }
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
                if first.effectiveDueDateKey != second.effectiveDueDateKey {
                    return (first.effectiveDueDateKey ?? "9999-12-31") < (second.effectiveDueDateKey ?? "9999-12-31")
                }
                let priority: [ImportanceLevel] = [.high, .normal, .low]
                if first.importance != second.importance { return priority.firstIndex(of: first.importance)! < priority.firstIndex(of: second.importance)! }
                return first.updatedAt < second.updatedAt
            case .byDueDate: return (first.effectiveDueDateKey ?? "9999-12-31") < (second.effectiveDueDateKey ?? "9999-12-31")
            case .byCreationDate: return first.createdAt < second.createdAt
            case .byName: return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }
        }
    }

    func dismissLastError() { lastErrorMessage = nil }

    private func commitQuadrantTaskMutation(
        _ mutation: QuadrantTaskMutation,
        changes: () throws -> Void
    ) -> Bool {
        do {
            try changes()
            try quadrantTaskMutationRecorder?(mutation)
            try saveOperation()
            lastErrorMessage = nil
            quadrantTaskMutationDidCommit?()
            return true
        } catch {
            modelContext.rollback()
            lastErrorMessage = "保存失败，请重试。"
            return false
        }
    }

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
