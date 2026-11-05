import SwiftUI

struct MacTaskList: View {
    let title: String
    var category: TaskCategory? = nil
    let tasks: [QuadrantTask]
    let sortMethod: TaskStore.TaskSortMethod
    let sortDirection: TaskStore.TaskSortDirection
    let taskStore: TaskStore
    @Binding var selectedTaskID: UUID?
    let actions: MacTaskActions

    @State private var orderedTasks: [QuadrantTask] = []

    private var orderSignature: [MacTaskSortSignature] {
        tasks.map {
            MacTaskSortSignature(
                id: $0.id,
                title: $0.title,
                dueDateKey: $0.effectiveDueDateKey,
                importance: $0.importance,
                isTop: $0.isTop,
                isCompleted: $0.isCompleted,
                updatedAt: $0.updatedAt
            )
        }
    }

    var body: some View {
        Group {
            if orderedTasks.isEmpty {
                ContentUnavailableView {
                    Label {
                        if let category {
                            MacQuadrantHeading(category: category, font: .title2)
                        } else {
                            Text(title)
                        }
                    } icon: {
                        Image(systemName: "tray")
                    }
                } description: {
                    Text("这里还没有任务。可以新建任务，或从其他象限切换查看。")
                }
            } else {
                List(selection: $selectedTaskID) {
                    ForEach(orderedTasks) { task in
                        // List 自带选中高亮，这里传 false 避免双重高亮。
                        MacTaskRow(task: task, isSelected: false, actions: actions)
                            .tag(task.id)
                            .draggable(TaskTransferItem(task: task))
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(category.map { MacQuadrantHeading.styledText(category: $0, font: .headline) } ?? Text(title))
        .onAppear(perform: updateOrder)
        .onChange(of: orderSignature) { _, _ in updateOrder() }
        .onChange(of: sortMethod) { _, _ in updateOrder() }
        .onChange(of: sortDirection) { _, _ in updateOrder() }
    }

    private func updateOrder() {
        orderedTasks = taskStore.sortTasks(tasks, by: sortMethod, direction: sortDirection)
    }
}

private struct MacTaskSortSignature: Equatable {
    let id: UUID
    let title: String
    let dueDateKey: String?
    let importance: ImportanceLevel
    let isTop: Bool
    let isCompleted: Bool
    let updatedAt: Date
}
