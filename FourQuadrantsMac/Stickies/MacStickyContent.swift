import AppKit
import SwiftData
import SwiftUI

// MARK: - 内容

struct MacStickyTaskList: View {
    let tasks: [QuadrantTask]
    let showDetails: Bool
    /// 智能排列：每条任务用对应象限的纸色作行底。
    let tintsRows: Bool
    let onToggle: (QuadrantTask) -> Void
    let onOpen: (QuadrantTask) -> Void

    var body: some View {
        if tasks.isEmpty {
            Text("没有任务")
                .font(.system(size: 11))
                .foregroundStyle(MacStickyPalette.ink.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: tintsRows ? 2 : 0) {
                    ForEach(tasks, id: \.id) { task in
                        MacStickyTaskRow(task: task, showDetails: showDetails, tintsRow: tintsRows, onToggle: { onToggle(task) }, onOpen: { onOpen(task) })
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }
}

/// 2×2 四合一：每格 14pt 小标题（象限名 + 数量），格间 1pt 分隔线。
struct MacStickyCombinedGrid: View {
    /// 每格的任务与单象限便笺一致（含刚完成、仍在可见期内的任务），格内计数只数未完成。
    let tasksFor: (TaskCategory) -> [QuadrantTask]
    let showDetails: Bool
    let onToggle: (QuadrantTask) -> Void
    let onOpen: (QuadrantTask) -> Void

    private let divider = MacStickyPalette.ink.opacity(0.18)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                quadrant(.importantAndUrgent)
                Rectangle().fill(divider).frame(width: 1)
                quadrant(.importantButNotUrgent)
            }
            Rectangle().fill(divider).frame(height: 1)
            HStack(spacing: 0) {
                quadrant(.urgentButNotImportant)
                Rectangle().fill(divider).frame(width: 1)
                quadrant(.notImportantAndNotUrgent)
            }
        }
    }

    private func quadrant(_ category: TaskCategory) -> some View {
        let tasks = tasksFor(category)
        let openCount = tasks.filter { !$0.isCompleted }.count
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                Rectangle().fill(category.themeColor).frame(width: 6, height: 6)
                MacQuadrantHeading(category: category, font: .system(size: 10))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(openCount)").font(.system(size: 10)).monospacedDigit()
            }
            .foregroundStyle(MacStickyPalette.ink.opacity(0.75))
            .padding(.horizontal, 6)
            .frame(height: 14)
            .background(MacStickyPalette.bar(for: category))
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(tasks, id: \.id) { task in
                        MacStickyTaskRow(task: task, showDetails: showDetails, tintsRow: false, onToggle: { onToggle(task) }, onOpen: { onOpen(task) })
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MacStickyPalette.body(for: category))
    }
}

/// 紧凑任务行：12pt 标题、12pt 勾选圈、行高约 20pt。双击或右键「在主窗口中打开」。
private struct MacStickyTaskRow: View {
    let task: QuadrantTask
    let showDetails: Bool
    /// 为 true 时用任务所属象限的纸色作圆角行底。
    let tintsRow: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(MacStickyPalette.ink.opacity(task.isCompleted ? 0.5 : 0.8))
                    .frame(width: 14, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "重新打开任务：\(task.title)" : "完成任务：\(task.title)")

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 12))
                    .lineLimit(showDetails ? 2 : 1)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(MacStickyPalette.ink.opacity(task.isCompleted ? 0.5 : 1))
                    .frame(minHeight: 20, alignment: .leading)
                if showDetails {
                    if let notes = task.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 10))
                            .lineLimit(2)
                            .foregroundStyle(MacStickyPalette.ink.opacity(0.65))
                    }
                    if let dueDate = task.displayDueDate {
                        Text(dueDate, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10))
                            .foregroundStyle(MacStickyPalette.ink.opacity(task.isOverdue ? 0.9 : 0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .background {
            if tintsRow {
                RoundedRectangle(cornerRadius: 3).fill(MacStickyPalette.body(for: task.category))
            }
        }
        .padding(.horizontal, tintsRow ? 3 : 0)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpen)
        .contextMenu {
            Button("在主窗口中打开", action: onOpen)
        }
    }
}
