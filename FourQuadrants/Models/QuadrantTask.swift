import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

enum ImportanceLevel: String, Codable {
    case low, normal, high
}

@Model
final class QuadrantTask {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dueAt: Date?
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
            guard let threshold = urgentThresholdDays, let dueAt else {
                return manualIsUrgent
            }
            let calendar = Calendar.current
            let remaining = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: Date()),
                to: calendar.startOfDay(for: dueAt)
            ).day ?? .max
            return remaining <= threshold
        }
        set { manualIsUrgent = newValue }
    }

    @Transient var isOverdue: Bool {
        guard !isCompleted, let dueAt else { return false }
        return dueAt < Calendar.current.startOfDay(for: Date())
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
        self.completedAt = completedAt
        self.importance = importance
        self.manualIsUrgent = isUrgent
        self.urgentThresholdDays = urgentThresholdDays
        self.originalUrgentThresholdDays = originalUrgentThresholdDays
        self.originalImportance = originalImportance
        self.isTop = isTop
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
        dueAt = task.dueAt
    }
}
