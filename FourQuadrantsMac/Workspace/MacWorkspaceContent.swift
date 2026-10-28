import SwiftUI

struct MacWorkspaceContent: View {
    let selection: MacWorkspaceRoute
    let tasks: [QuadrantTask]
    let taskStore: TaskStore
    let sortMethod: TaskStore.TaskSortMethod
    let now: Date
    @Binding var selectedTaskID: UUID?
    let onEdit: (QuadrantTask) -> Void
    let onDelete: (QuadrantTask) -> Void
    let onPin: (QuadrantTask) -> Void

    var body: some View {
        Group {
            switch selection {
            case .quadrants:
                MacQuadrantBoard(tasks: tasks, taskStore: taskStore, now: now, selectedTaskID: $selectedTaskID, onEdit: onEdit, onDelete: onDelete, onPin: onPin)
            case .daily:
                MacDailyView()
            case .all:
                MacTaskList(title: String(localized: "全部任务"), tasks: taskStore.filteredTasks(tasks, in: .all, now: now), sortMethod: sortMethod, taskStore: taskStore, selectedTaskID: $selectedTaskID, onEdit: onEdit, onDelete: onDelete, onPin: onPin)
            case .completed:
                MacTaskList(title: String(localized: "已完成"), tasks: taskStore.filteredTasks(tasks, in: .completed, now: now), sortMethod: sortMethod, taskStore: taskStore, selectedTaskID: $selectedTaskID, onEdit: onEdit, onDelete: onDelete, onPin: onPin)
            case let .category(category):
                MacTaskList(title: category.displayName, category: category, tasks: taskStore.filteredTasks(tasks, in: category, now: now), sortMethod: sortMethod, taskStore: taskStore, selectedTaskID: $selectedTaskID, onEdit: onEdit, onDelete: onDelete, onPin: onPin)
            }
        }
        .navigationTitle(selection.navigationTitle)
    }
}
