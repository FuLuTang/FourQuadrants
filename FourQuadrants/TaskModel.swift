import Foundation

enum ImportanceLevel: String, Codable {
    case low, normal, high
}

import SwiftData

@Model
final class Task {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var dateLatestModified: Date = Date()
    var targetDate: Date? = nil
    var isCompleted: Bool = false
    var importance: ImportanceLevel = ImportanceLevel.normal
    
    // Mapping: High -> Important; Normal/Low -> Not Important
    @Transient var isImportantQuadrant: Bool {
        return importance == .high
    }
    
    // Renamed backing storage for manual urgency
    var manualIsUrgent: Bool = false
    
    var urgentThresholdDays: Int? = nil
    var completionDate: Date?
    var isTop: Bool = false
    
    // Computed property for auto-urgency
    @Transient var isUrgent: Bool {
        get {
            if let threshold = urgentThresholdDays, let target = targetDate {
                let now = Calendar.current.startOfDay(for: Date())
                let targetDay = Calendar.current.startOfDay(for: target)
                let daysRemaining = Calendar.current.dateComponents([.day], from: now, to: targetDay).day ?? Int.max
                return daysRemaining <= threshold
            } else {
                return manualIsUrgent
            }
        }
        set {
            manualIsUrgent = newValue
        }
    }
    
    @Transient var isOverdue: Bool {
        guard !isCompleted, let targetDate = targetDate else { return false }
        // Use targetDate + 1 day as the deadline
        return targetDate.advanced(by: 86400) < Date()
    }
    
    // Custom initializer to match existing calls that use 'isUrgent'
    init(id: UUID = UUID(), title: String, date: Date, dateLatestModified: Date = Date(), targetDate: Date? = nil, isCompleted: Bool = false, importance: ImportanceLevel = ImportanceLevel.normal, isUrgent: Bool = false, urgentThresholdDays: Int? = nil, completionDate: Date? = nil, isTop: Bool = false) {
        self.id = id
        self.title = title
        self.date = date
        self.dateLatestModified = dateLatestModified
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.importance = importance
        self.manualIsUrgent = isUrgent
        self.urgentThresholdDays = urgentThresholdDays
        self.completionDate = completionDate
        self.isTop = isTop
    }
}

