import SwiftData
import SwiftUI

struct MacTaskInspector: View {
    let task: QuadrantTask?
    let taskStore: TaskStore
    let onEditDetails: (QuadrantTask) -> Void
    let onPin: (QuadrantTask) -> Void

    var body: some View {
        Group {
            if let task {
                MacTaskInspectorEditor(task: task, taskStore: taskStore, onEditDetails: { onEditDetails(task) }, onPin: { onPin(task) })
                    .id(task.id)
            } else {
                ContentUnavailableView("选择一个任务", systemImage: "sidebar.right", description: Text("标题、备注、分类和日期可以直接在检查器中修改。"))
            }
        }
        .navigationTitle("检查器")
    }
}

private struct MacTaskInspectorEditor: View {
    let task: QuadrantTask
    let taskStore: TaskStore
    let onEditDetails: () -> Void
    let onPin: () -> Void

    @State private var session: MacTaskDraftSession

    init(task: QuadrantTask, taskStore: TaskStore, onEditDetails: @escaping () -> Void, onPin: @escaping () -> Void) {
        self.task = task
        self.taskStore = taskStore
        self.onEditDetails = onEditDetails
        self.onPin = onPin
        _session = State(initialValue: MacTaskDraftSession(task: task))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("任务检查器").font(.headline)
                    MacQuadrantHeading(category: task.category, font: .caption)
                        .foregroundStyle(task.category.themeColor)
                }
                Spacer()
                Button(action: onPin) {
                    Label("添加所属象限ToDo便笺", systemImage: "note.text.badge.plus")
                }
                .help("创建展示此任务所属象限的ToDo便笺浮窗")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()

            Form {
                if session.hasExternalUpdate {
                    Section {
                        Label("此任务已在别处更改。继续保存会覆盖那些更改。", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                            .font(.callout)
                        Button("放弃编辑并载入最新") { session.reload(from: task) }
                    }
                }

                MacTaskCommonFields(
                    draft: $session.draft,
                    showsCompletion: true,
                    onSubmitTitle: nil
                )

                if session.draft.hasAutomaticUrgency {
                    Section("自动紧急") {
                        LabeledContent("触发阈值", value: "提前 \(session.draft.urgentThresholdDays) 天")
                        Text("可在详细编辑中调整当前阈值和原始阈值。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("保存更改", action: { _ = save() })
                        .buttonStyle(.borderedProminent)
                        .disabled(!session.isDirty || !session.draft.hasValidTitle)
                    Button("详细编辑…") {
                        if !session.isDirty || save() { onEditDetails() }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .onChange(of: task.updatedAt) { _, _ in session.taskDidChange(task) }
        // 切换到其他任务时编辑器会被 `.id(task.id)` 重建，这里先保存未提交的修改。
        .onDisappear {
            guard session.shouldAutosave, task.modelContext != nil, !task.isDeleted else { return }
            _ = save()
        }
    }

    private func save() -> Bool {
        session.save(to: task, using: taskStore)
    }
}
