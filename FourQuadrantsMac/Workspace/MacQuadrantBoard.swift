import SwiftUI

struct MacQuadrantBoard: View {
    let tasks: [QuadrantTask]
    let taskStore: TaskStore
    let now: Date
    let selectedTaskID: UUID?
    let actions: MacTaskActions

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(TaskCategory.allQuadrants, id: \.self) { category in
                    MacQuadrantCard(
                        category: category,
                        allTasks: tasks,
                        taskStore: taskStore,
                        now: now,
                        selectedTaskID: selectedTaskID,
                        actions: actions
                    )
                }
            }
            .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("四象限")
    }
}

private struct MacQuadrantCard: View {
    let category: TaskCategory
    let allTasks: [QuadrantTask]
    let taskStore: TaskStore
    let now: Date
    let selectedTaskID: UUID?
    let actions: MacTaskActions

    private var tasks: [QuadrantTask] {
        taskStore.filteredTasks(allTasks, in: category, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .foregroundStyle(category.themeColor)
                MacQuadrantHeading(category: category, font: .headline)
                    .lineLimit(1)
                Spacer()
                Text(tasks.count, format: .number)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.bottom, 2)

            if tasks.isEmpty {
                ContentUnavailableView("暂无任务", systemImage: category.icon, description: Text("将任务拖到此象限，或通过任务菜单调整分类。"))
                    .frame(minHeight: 126)
            } else {
                VStack(spacing: 1) {
                    ForEach(tasks) { task in
                        MacTaskRow(task: task, isSelected: selectedTaskID == task.id, actions: actions)
                            .draggable(TaskTransferItem(task: task))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(category.themeColor.opacity(0.7))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(category.themeColor.opacity(0.13), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .dropDestination(for: TaskTransferItem.self) { items, _ in
            guard let item = items.first,
                  let task = allTasks.first(where: { $0.id == item.taskId }),
                  // 已完成任务没有移动入口，拖放时同样拒绝。
                  !task.isCompleted else { return false }
            return actions.move(task, category)
        }
    }
}
