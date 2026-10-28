import SwiftUI

struct MacQuadrantTaskPicker: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [QuadrantTask]
    let selectedID: UUID?
    let onSelect: (QuadrantTask?) -> Void

    @State private var searchText = ""

    private var filteredTasks: [QuadrantTask] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter {
            $0.title.localizedStandardContains(searchText) || ($0.notes ?? "").localizedStandardContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择四象限任务").font(.title2.weight(.semibold))
                    Text("手动选择始终可用，也可以取消关联。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            TextField("搜索任务标题或备注", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            List {
                Button {
                    onSelect(nil)
                } label: {
                    Label("不关联任务", systemImage: "link.badge.minus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if filteredTasks.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(filteredTasks, id: \.id) { task in
                        Button {
                            onSelect(task)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedID == task.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedID == task.id ? Color.accentColor : Color.secondary)
                                MacQuadrantTaskCard(task: task, isLinked: false)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
