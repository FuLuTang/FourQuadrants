import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

enum ImportanceLevel: String, Codable, CaseIterable {
    case low, normal, high
}

/// A task due date is a calendar day, not an absolute instant in time.
/// `dueAt` remains stored for the existing UI while `dueDateKey` is the sync source of truth.
enum TaskDueDate {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            preconditionFailure("A calendar date must contain year, month, and day components.")
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(for key: String, calendar: Calendar = .current) -> Date? {
        let components = key.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        let requested = DateComponents(year: components[0], month: components[1], day: components[2])
        guard let date = calendar.date(from: requested) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == requested.year,
              resolved.month == requested.month,
              resolved.day == requested.day else { return nil }
        return date
    }

    static func isValid(_ key: String) -> Bool {
        date(for: key, calendar: Calendar(identifier: .gregorian)) != nil
    }
}

@Model
final class QuadrantTask {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Legacy display value retained for the existing UI and V2 migration.
    var dueAt: Date?
    /// Stable civil-date representation used for sync and cross-time-zone comparisons.
    var dueDateKey: String?
    var completedAt: Date?
    var importance: ImportanceLevel = ImportanceLevel.normal
    var manualIsUrgent: Bool = false
    var urgentThresholdDays: Int?
    var originalUrgentThresholdDays: Int?
    var originalImportance: ImportanceLevel?
    var isTop: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \DailyTask.quadrantTask)
    var dailyTasks: [DailyTask]?

    @Transient var isCompleted: Bool {
        get { completedAt != nil }
        set { completedAt = newValue ? (completedAt ?? Date()) : nil }
    }

    @Transient var isImportantQuadrant: Bool {
        importance == .high
    }

    @Transient var isUrgent: Bool {
        get {
            guard let threshold = urgentThresholdDays,
                  let dueDateKey,
                  let dueDate = TaskDueDate.date(for: dueDateKey) else {
                return manualIsUrgent
            }
            let calendar = Calendar.current
            let remaining = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: Date()),
                to: dueDate
            ).day ?? .max
            return remaining <= threshold
        }
        set { manualIsUrgent = newValue }
    }

    @Transient var isOverdue: Bool {
        guard !isCompleted,
              let dueDateKey,
              let dueDate = TaskDueDate.date(for: dueDateKey) else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    @Transient var effectiveDueDateKey: String? {
        dueDateKey ?? dueAt.map { TaskDueDate.key(for: $0) }
    }

    @Transient var displayDueDate: Date? {
        effectiveDueDateKey.flatMap { TaskDueDate.date(for: $0) }
    }

    @Transient var category: TaskCategory {
        guard !isCompleted else { return .completed }
        switch (isImportantQuadrant, isUrgent) {
        case (true, true): return .importantAndUrgent
        case (true, false): return .importantButNotUrgent
        case (false, true): return .urgentButNotImportant
        case (false, false): return .notImportantAndNotUrgent
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        dueAt: Date? = nil,
        completedAt: Date? = nil,
        importance: ImportanceLevel = .normal,
        isUrgent: Bool = false,
        urgentThresholdDays: Int? = nil,
        originalUrgentThresholdDays: Int? = nil,
        originalImportance: ImportanceLevel? = nil,
        isTop: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueAt = dueAt
        self.dueDateKey = dueAt.map { TaskDueDate.key(for: $0) }
        self.completedAt = completedAt
        self.importance = importance
        self.manualIsUrgent = isUrgent
        self.urgentThresholdDays = urgentThresholdDays
        self.originalUrgentThresholdDays = originalUrgentThresholdDays
        self.originalImportance = originalImportance
        self.isTop = isTop
    }

    func setDueDate(_ date: Date?, calendar: Calendar = .current) {
        dueDateKey = date.map { TaskDueDate.key(for: $0, calendar: calendar) }
        dueAt = dueDateKey.flatMap { TaskDueDate.date(for: $0, calendar: calendar) }
    }

    func restoreLegacyDueDateKeyIfNeeded(calendar: Calendar = .current) {
        guard dueDateKey == nil, let dueAt else { return }
        dueDateKey = TaskDueDate.key(for: dueAt, calendar: calendar)
    }
}

struct TaskTransferItem: Codable, Transferable {
    let taskId: UUID
    let title: String
    let isCompleted: Bool
    let dueAt: Date?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }

    init(task: QuadrantTask) {
        taskId = task.id
        title = task.title
        isCompleted = task.isCompleted
        dueAt = task.displayDueDate
    }
}
