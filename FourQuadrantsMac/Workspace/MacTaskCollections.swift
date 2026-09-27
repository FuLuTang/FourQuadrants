import SwiftUI

struct MacQuadrantBoard: View {
    let tasks: [QuadrantTask]
    let taskStore: TaskStore
    let now: Date
    @Binding var selectedTaskID: UUID?
    let onEdit: (QuadrantTask) -> Void
    let onDelete: (QuadrantTask) -> Void
    let onPin: (QuadrantTask) -> Void

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    private let categories: [TaskCategory] = [
        .importantAndUrgent,
        .urgentButNotImportant,
        .importantButNotUrgent,
        .notImportantAndNotUrgent
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(categories, id: \.self) { category in
                    MacQuadrantCard(
                        category: category,
                        allTasks: tasks,
                        taskStore: taskStore,
                        now: now,
                        selectedTaskID: $selectedTaskID,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onPin: onPin
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
    @Binding var selectedTaskID: UUID?
    let onEdit: (QuadrantTask) -> Void
    let onDelete: (QuadrantTask) -> Void
    let onPin: (QuadrantTask) -> Void

    private var tasks: [QuadrantTask] {
        taskStore.filteredTasks(allTasks, in: category, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .foregroundStyle(category.themeColor)
                Text(category.displayName)
                    .font(.headline)
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
                        MacTaskRow(task: task, isSelected: selectedTaskID == task.id, onSelect: { selectedTaskID = task.id }, onToggle: { _ = taskStore.toggleTask(task) }, onEdit: { onEdit(task) }, onDelete: { onDelete(task) }, onPin: { onPin(task) }, onMove: { _ = taskStore.moveTask(task, to: $0) })
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
                  let task = allTasks.first(where: { $0.id == item.taskId }) else { return false }
            return taskStore.moveTask(task, to: category)
        }
    }
}

struct MacTaskList: View {
    let title: String
    let tasks: [QuadrantTask]
    let sortMethod: TaskStore.TaskSortMethod
    let taskStore: TaskStore
    @Binding var selectedTaskID: UUID?
    let onEdit: (QuadrantTask) -> Void
    let onDelete: (QuadrantTask) -> Void
    let onPin: (QuadrantTask) -> Void

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
                ContentUnavailableView(title, systemImage: "tray", description: Text("这里还没有任务。可以新建任务，或从其他象限切换查看。"))
            } else {
                List(selection: $selectedTaskID) {
                    ForEach(orderedTasks) { task in
                        MacTaskRow(task: task, isSelected: selectedTaskID == task.id, onSelect: { selectedTaskID = task.id }, onToggle: { _ = taskStore.toggleTask(task) }, onEdit: { onEdit(task) }, onDelete: { onDelete(task) }, onPin: { onPin(task) }, onMove: { _ = taskStore.moveTask(task, to: $0) })
                            .tag(task.id)
                            .draggable(TaskTransferItem(task: task))
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(title)
        .onAppear(perform: updateOrder)
        .onChange(of: orderSignature) { _, _ in updateOrder() }
        .onChange(of: sortMethod) { _, _ in updateOrder() }
    }

    private func updateOrder() {
        orderedTasks = taskStore.sortTasks(tasks, by: sortMethod)
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

private struct MacTaskRow: View {
    let task: QuadrantTask
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void
    let onMove: (TaskCategory) -> Void

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "标记为未完成" : "标记为已完成")

            Button(action: onSelect) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .lineLimit(1)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        if let notes = task.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if task.isTop {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let dueDate = task.displayDueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("编辑任务", systemImage: "pencil", action: onEdit)
                Button(task.isCompleted ? "标记为未完成" : "标记为已完成", systemImage: "checkmark", action: onToggle)
                Button("放到桌面", systemImage: "pin", action: onPin)
                Divider()
                Menu("移动到象限") {
                    ForEach([TaskCategory.importantAndUrgent, .urgentButNotImportant, .importantButNotUrgent, .notImportantAndNotUrgent], id: \.self) { category in
                        Button(category.displayName, systemImage: category.icon) { onMove(category) }
                    }
                }
                Divider()
                Button("删除任务", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("更多任务操作")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .contextMenu {
            Button("编辑任务", systemImage: "pencil", action: onEdit)
            Button(task.isCompleted ? "标记为未完成" : "标记为已完成", systemImage: "checkmark", action: onToggle)
            Button("放到桌面", systemImage: "pin", action: onPin)
            Menu("移动到象限") {
                ForEach([TaskCategory.importantAndUrgent, .urgentButNotImportant, .importantButNotUrgent, .notImportantAndNotUrgent], id: \.self) { category in
                    Button(category.displayName, systemImage: category.icon) { onMove(category) }
                }
            }
            Divider()
            Button("删除任务", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
