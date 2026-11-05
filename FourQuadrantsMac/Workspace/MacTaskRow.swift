import SwiftUI

struct MacTaskRow: View {
    let task: QuadrantTask
    let isSelected: Bool
    let actions: MacTaskActions

    var body: some View {
        HStack(spacing: 9) {
            Button { actions.toggleCompletion(task) } label: {
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
            .onTapGesture(count: 2) { actions.edit(task) }
            .simultaneousGesture(TapGesture().onEnded { actions.select(task) })

            Menu {
                rowMenuItems
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
        .contextMenu { rowMenuItems }
    }

    /// 「更多」菜单与右键菜单共用的操作项。
    @ViewBuilder
    private var rowMenuItems: some View {
        Button("编辑任务", systemImage: "pencil") { actions.edit(task) }
        Button(task.isCompleted ? "标记为未完成" : "标记为已完成", systemImage: "checkmark") { actions.toggleCompletion(task) }
        Button("添加所属象限ToDo便笺", systemImage: "note.text.badge.plus") { actions.pin(task) }
        // 已完成任务不再参与象限划分，因此不提供移动入口（与 iOS 一致）。
        if !task.isCompleted {
            Divider()
            Menu("移动到象限") {
                ForEach(TaskCategory.allQuadrants, id: \.self) { category in
                    Button { _ = actions.move(task, category) } label: {
                        Label {
                            MacQuadrantHeading(category: category, font: .body)
                        } icon: {
                            Image(systemName: category.icon)
                        }
                    }
                }
            }
        }
        Divider()
        Button("删除任务", systemImage: "trash", role: .destructive) { actions.delete(task) }
    }
}
