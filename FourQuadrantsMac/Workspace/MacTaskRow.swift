import SwiftUI

struct MacTaskRow: View {
    let task: QuadrantTask
    let isSelected: Bool
    let taskStore: TaskStore
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Button(action: toggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "标记为未完成" : "标记为已完成")

            // 单击立即选中，双击打开编辑；不用 Button，避免双击被单击吞掉。
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
            .onTapGesture(count: 2, perform: onEdit)
            .simultaneousGesture(TapGesture().onEnded { onSelect() })

            Menu {
                actions
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
        .contextMenu { actions }
    }

    /// Shared by the row's "more" menu and its context menu.
    @ViewBuilder
    private var actions: some View {
        Button("编辑任务", systemImage: "pencil", action: onEdit)
        Button(task.isCompleted ? "标记为未完成" : "标记为已完成", systemImage: "checkmark", action: toggleCompletion)
        Button("添加所属象限ToDo便笺", systemImage: "note.text.badge.plus", action: onPin)
        Divider()
        Menu("移动到象限") {
            ForEach(TaskCategory.allQuadrants, id: \.self) { category in
                Button { _ = taskStore.moveTask(task, to: category) } label: {
                    Label {
                        MacQuadrantHeading(category: category, font: .body)
                    } icon: {
                        Image(systemName: category.icon)
                    }
                }
            }
        }
        Divider()
        Button("删除任务", systemImage: "trash", role: .destructive, action: onDelete)
    }

    private func toggleCompletion() {
        _ = taskStore.toggleTask(task)
    }
}
