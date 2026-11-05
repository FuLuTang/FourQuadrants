import Foundation
import SwiftData

@Model
final class DailyTask {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var startAt: Date = Date()
    var duration: TimeInterval = 3600
    var completedAt: Date?
    var colorHex: String?
    var notes: String?
    var quadrantTask: QuadrantTask?

    @Transient var isCompleted: Bool {
        get { completedAt != nil }
        set { completedAt = newValue ? (completedAt ?? Date()) : nil }
    }

    @Transient var endAt: Date {
        startAt.addingTimeInterval(duration)
    }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        startAt: Date = Date(),
        duration: TimeInterval = 3600,
        completedAt: Date? = nil,
        colorHex: String? = nil,
        notes: String? = nil,
        quadrantTask: QuadrantTask? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startAt = startAt
        self.duration = duration
        self.completedAt = completedAt
        self.colorHex = colorHex
        self.notes = notes
        self.quadrantTask = quadrantTask
    }
}
