import SwiftUI

enum MacWorkspaceRoute: Hashable {
    case quadrants
    case daily
    case all
    case completed
    case category(TaskCategory)

    var supportsInspector: Bool {
        self != .daily
    }

    var navigationTitle: Text {
        switch self {
        case .quadrants: Text("四象限")
        case .daily: Text("日程")
        case .all: Text("全部任务")
        case .completed: Text("已完成")
        case let .category(category): MacQuadrantHeading.styledText(category: category, font: .headline)
        }
    }
}
