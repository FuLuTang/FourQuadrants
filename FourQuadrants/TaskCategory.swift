import Foundation

enum TaskCategory: String, CaseIterable {
    case all = "所有"
    case importantAndUrgent = "重要 & 紧急\t❗️⏰"
    case importantButNotUrgent = "重要 不紧急\t❗️ —"
    case urgentButNotImportant = "紧急 不重要\t — ⏰"
    case notImportantAndNotUrgent = "不重要不紧急\t —  —"
    case completed = "已完成"
}

