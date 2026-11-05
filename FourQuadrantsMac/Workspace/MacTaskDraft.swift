import Foundation

/// Editable copy of a task's fields. The inspector and the task form edit the
/// same draft, so validation, automatic urgency and saving live in one place.
struct MacTaskDraft: Equatable {
    static let defaultUrgentThresholdDays = 3

    var title = ""
    var notes = ""
    var importance: ImportanceLevel = .normal
    var isUrgent = false
    var isTop = false
    var isCompleted = false
    var hasDueDate = false
    var dueDate: Date = .now
    var hasUrgentThreshold = false
    var urgentThresholdDays = MacTaskDraft.defaultUrgentThresholdDays
    var originalUrgentThresholdDays: Int?
    var originalImportance: ImportanceLevel?

    /// An empty draft for a new task.
    init() {}

    init(task: QuadrantTask?) {
        guard let task else { return }
        title = task.title
        notes = task.notes ?? ""
        importance = task.importance
        isUrgent = task.manualIsUrgent
        isTop = task.isTop
        isCompleted = task.isCompleted
        hasDueDate = task.effectiveDueDateKey != nil
        dueDate = task.displayDueDate ?? .now
        hasUrgentThreshold = task.urgentThresholdDays != nil
        urgentThresholdDays = task.urgentThresholdDays
            ?? task.originalUrgentThresholdDays
            ?? Self.defaultUrgentThresholdDays
        originalUrgentThresholdDays = task.originalUrgentThresholdDays
        originalImportance = task.originalImportance
    }

    var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var cleanNotes: String { notes.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasValidTitle: Bool { !cleanTitle.isEmpty }
    var hasAutomaticUrgency: Bool { hasDueDate && hasUrgentThreshold }

    /// The urgency the task would have if saved now.
    func effectiveUrgency(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard hasAutomaticUrgency else { return isUrgent }
        let remaining = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? .max
        return remaining <= urgentThresholdDays
    }

    /// Value equality that ignores fields hidden by their toggles and compares
    /// due dates by calendar day, matching what the UI can actually edit.
    static func == (lhs: MacTaskDraft, rhs: MacTaskDraft) -> Bool {
        guard lhs.title == rhs.title,
              lhs.notes == rhs.notes,
              lhs.importance == rhs.importance,
              lhs.isUrgent == rhs.isUrgent,
              lhs.isTop == rhs.isTop,
              lhs.isCompleted == rhs.isCompleted,
              lhs.hasDueDate == rhs.hasDueDate,
              lhs.hasUrgentThreshold == rhs.hasUrgentThreshold,
              lhs.originalUrgentThresholdDays == rhs.originalUrgentThresholdDays,
              lhs.originalImportance == rhs.originalImportance else { return false }
        if lhs.hasDueDate, !Calendar.current.isDate(lhs.dueDate, inSameDayAs: rhs.dueDate) { return false }
        if lhs.hasUrgentThreshold, lhs.urgentThresholdDays != rhs.urgentThresholdDays { return false }
        return true
    }

    /// Creates a task, or updates `task` when given. Returns whether every step succeeded.
    @discardableResult
    func save(to task: QuadrantTask?, using store: TaskStore) -> Bool {
        guard hasValidTitle else { return false }
        let notes = cleanNotes.isEmpty ? nil : cleanNotes
        let dueAt = hasDueDate ? dueDate : nil
        let threshold = hasAutomaticUrgency ? urgentThresholdDays : nil

        guard let task else {
            return store.addTask(
                title: cleanTitle,
                notes: notes,
                importance: importance,
                isUrgent: isUrgent,
                isTop: isTop,
                dueAt: dueAt,
                urgentThresholdDays: threshold,
                originalUrgentThresholdDays: originalUrgentThresholdDays ?? threshold,
                originalImportance: originalImportance ?? importance
            )
        }

        guard store.updateTask(
            task,
            title: cleanTitle,
            notes: notes,
            importance: importance,
            isUrgent: isUrgent,
            isTop: isTop,
            dueAt: dueAt,
            urgentThresholdDays: threshold,
            originalUrgentThresholdDays: originalUrgentThresholdDays,
            originalImportance: originalImportance
        ) else { return false }
        if task.isCompleted != isCompleted { return store.toggleTask(task) }
        return true
    }
}

/// A draft plus the snapshot it was loaded from, so the inspector can tell
/// unsaved edits apart from a plain refresh when the task changes elsewhere.
struct MacTaskDraftSession: Equatable {
    var draft: MacTaskDraft
    private(set) var baseline: MacTaskDraft
    /// The task changed elsewhere while unsaved edits were being kept.
    private(set) var hasExternalUpdate = false

    init(task: QuadrantTask?) {
        let snapshot = MacTaskDraft(task: task)
        draft = snapshot
        baseline = snapshot
    }

    var isDirty: Bool { draft != baseline }

    /// 有未保存修改、标题有效且没有外部更新冲突时，离开检查器前应自动保存。
    var shouldAutosave: Bool { isDirty && draft.hasValidTitle && !hasExternalUpdate }

    /// Discards edits and loads the task's current values.
    mutating func reload(from task: QuadrantTask) {
        let snapshot = MacTaskDraft(task: task)
        draft = snapshot
        baseline = snapshot
        hasExternalUpdate = false
    }

    /// Call when the task changed (sync, sticky note). Refreshes silently when
    /// nothing is unsaved; otherwise keeps the edits and flags the conflict.
    mutating func taskDidChange(_ task: QuadrantTask) {
        if isDirty {
            hasExternalUpdate = true
        } else {
            reload(from: task)
        }
    }

    @discardableResult
    mutating func save(to task: QuadrantTask, using store: TaskStore) -> Bool {
        guard draft.save(to: task, using: store) else { return false }
        reload(from: task)
        return true
    }
}
