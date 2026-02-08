import Foundation
import SwiftUI

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
        case .importantAndUrgent: return "重要 & 紧急"
        case .importantButNotUrgent: return "重要 不紧急"
        case .urgentButNotImportant: return "紧急 不重要"
        case .notImportantAndNotUrgent: return "不重要不紧急"
        case .completed: return "已完成"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .importantAndUrgent: return "exclamationmark.triangle.fill"
        case .importantButNotUrgent: return "clock.fill"
        case .urgentButNotImportant: return "bolt.fill"
        case .notImportantAndNotUrgent: return "leaf.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .importantAndUrgent: return AppTheme.Colors.urgentImportant
        case .importantButNotUrgent: return AppTheme.Colors.importantNotUrgent
        case .urgentButNotImportant: return AppTheme.Colors.urgentNotImportant
        case .notImportantAndNotUrgent: return AppTheme.Colors.normal
        case .all: return .primary
        case .completed: return .secondary
        }
    }
}
