import SwiftUI

struct MacDailyLinkedTaskSection: View {
    let linkedTask: QuadrantTask?
    let suggestions: [MacDailyTaskSuggestions.Suggestion]
    let hasSearchableTasks: Bool
    let onChoose: (QuadrantTask) -> Void
    let onUnlink: () -> Void
    let onOpenPicker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let linkedTask {
                MacQuadrantTaskCard(task: linkedTask, isLinked: true)
                Button("取消关联", systemImage: "link.badge.minus", action: onUnlink)
                    .buttonStyle(.borderless)
            } else {
                Label("尚未关联四象限任务", systemImage: "link")
                    .foregroundStyle(.secondary)
                Text("可先选择一条已有任务；这不会影响日程的独立创建与完成。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label("标题与备注关键词建议", systemImage: "sparkle.magnifyingglass")
                        .font(.subheadline.weight(.medium))
                    ForEach(suggestions) { suggestion in
                        Button {
                            onChoose(suggestion.task)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(suggestion.task.isCompleted ? Color.secondary : Color.accentColor)
                                    .frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.task.title)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                    Text("匹配：\(suggestion.matches.formatted())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if suggestion.task.isCompleted {
                                    Text("已完成").font(.caption).foregroundStyle(.secondary)
                                }
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if !hasSearchableTasks {
                ContentUnavailableView {
                    Label("还没有四象限任务", systemImage: "square.grid.2x2")
                } description: {
                    Text("你仍可保存这条日程，之后再从四象限任务中关联。")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } else {
                Text("输入标题或备注后，这里会显示关键词匹配建议。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(hasSearchableTasks ? "搜索并手动选择…" : "选择关联任务…", systemImage: "magnifyingglass", action: onOpenPicker)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
