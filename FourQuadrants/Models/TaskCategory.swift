import Foundation
import SwiftUI

enum TaskCategory: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case all = "all"
    case importantAndUrgent = "important_urgent"
    case importantButNotUrgent = "important_not_urgent"
    case urgentButNotImportant = "urgent_not_important"
    case notImportantAndNotUrgent = "not_important_not_urgent"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .all: return String(localized: "category_all")
        case .importantAndUrgent: return String(localized: "category_important_urgent")
        case .importantButNotUrgent: return String(localized: "category_important_not_urgent")
        case .urgentButNotImportant: return String(localized: "category_urgent_not_important")
        case .notImportantAndNotUrgent: return String(localized: "category_not_important_not_urgent")
        case .completed: return String(localized: "category_completed")
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
