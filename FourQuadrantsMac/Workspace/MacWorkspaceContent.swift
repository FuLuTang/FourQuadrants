import SwiftUI

struct MacWorkspaceContent: View {
    let selection: MacWorkspaceRoute
    let tasks: [QuadrantTask]
    let taskStore: TaskStore
    let sortMethod: TaskStore.TaskSortMethod
    let sortDirection: TaskStore.TaskSortDirection
    let now: Date
    @Binding var selectedTaskID: UUID?
    let actions: MacTaskActions

    var body: some View {
        Group {
            switch selection {
            case .quadrants:
                MacQuadrantBoard(tasks: tasks, taskStore: taskStore, now: now, selectedTaskID: selectedTaskID, actions: actions)
            case .daily:
                MacDailyView()
            case .all:
                MacTaskList(title: String(localized: "全部任务"), tasks: taskStore.filteredTasks(tasks, in: .all, now: now), sortMethod: sortMethod, sortDirection: sortDirection, taskStore: taskStore, selectedTaskID: $selectedTaskID, actions: actions)
            case .completed:
                MacTaskList(title: String(localized: "已完成"), tasks: taskStore.filteredTasks(tasks, in: .completed, now: now), sortMethod: sortMethod, sortDirection: sortDirection, taskStore: taskStore, selectedTaskID: $selectedTaskID, actions: actions)
            case let .category(category):
                MacTaskList(title: category.displayName, category: category, tasks: taskStore.filteredTasks(tasks, in: category, now: now), sortMethod: sortMethod, sortDirection: sortDirection, taskStore: taskStore, selectedTaskID: $selectedTaskID, actions: actions)
            }
        }
        .navigationTitle(selection.navigationTitle)
    }
}
