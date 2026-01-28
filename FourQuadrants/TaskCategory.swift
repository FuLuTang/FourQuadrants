import Foundation

enum TaskCategory: String, CaseIterable, Codable {
    case all = "all"
    case importantAndUrgent = "important_urgent"
    case importantButNotUrgent = "important_not_urgent"
    case urgentButNotImportant = "urgent_not_important"
    case notImportantAndNotUrgent = "not_important_not_urgent"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .all: return "所有"
        case .importantAndUrgent: return "重要 & 紧急\t❗️⏰"
        case .importantButNotUrgent: return "重要 不紧急\t❗️ —"
        case .urgentButNotImportant: return "紧急 不重要\t — ⏰"
        case .notImportantAndNotUrgent: return "不重要不紧急\t —  —"
        case .completed: return "已完成"
        }
    }
}

