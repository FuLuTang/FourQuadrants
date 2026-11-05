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

    /// 只有任务列表类路由使用排序；四象限看板与日程不排序。
    var supportsSorting: Bool {
        switch self {
        case .all, .completed, .category: true
        case .quadrants, .daily: false
        }
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
