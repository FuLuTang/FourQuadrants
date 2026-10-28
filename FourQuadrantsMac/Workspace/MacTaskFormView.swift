import SwiftUI

struct MacTaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    let taskStore: TaskStore
    let existingTask: QuadrantTask?

    @State private var draft: MacTaskDraft

    init(taskStore: TaskStore, existingTask: QuadrantTask? = nil) {
        self.taskStore = taskStore
        self.existingTask = existingTask
        _draft = State(initialValue: MacTaskDraft(task: existingTask))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingTask == nil ? "新建任务" : "编辑任务")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existingTask == nil ? "创建" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!draft.hasValidTitle)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            Divider()

            Form {
                MacTaskCommonFields(
                    draft: $draft,
                    showsCompletion: existingTask != nil,
                    onSubmitTitle: save,
                    autoFocusTitle: existingTask == nil
                )

                if draft.hasDueDate {
                    Section("自动紧急阈值") {
                        Toggle("按临近日期自动标记紧急", isOn: $draft.hasUrgentThreshold)
                        if draft.hasUrgentThreshold {
                            Stepper("提前 \(draft.urgentThresholdDays) 天", value: $draft.urgentThresholdDays, in: 1...30)
                            Text("截止日期进入此阈值范围后，任务会归入紧急象限。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("原始值") {
                    Picker("原始重要性", selection: $draft.originalImportance) {
                        Text("未记录").tag(ImportanceLevel?.none)
                        Text("低").tag(ImportanceLevel?.some(.low))
                        Text("普通").tag(ImportanceLevel?.some(.normal))
                        Text("高").tag(ImportanceLevel?.some(.high))
                    }
                    Toggle("记录原始紧急阈值", isOn: Binding(
                        get: { draft.originalUrgentThresholdDays != nil },
                        set: { draft.originalUrgentThresholdDays = $0 ? (draft.originalUrgentThresholdDays ?? draft.urgentThresholdDays) : nil }
                    ))
                    if let original = draft.originalUrgentThresholdDays {
                        Stepper("原始阈值：提前 \(original) 天", value: Binding(
                            get: { draft.originalUrgentThresholdDays ?? MacTaskDraft.defaultUrgentThresholdDays },
                            set: { draft.originalUrgentThresholdDays = $0 }
                        ), in: 1...30)
                    }
                    Text("原始值用于象限调整时恢复重要性和紧急阈值。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func save() {
        if draft.save(to: existingTask, using: taskStore) { dismiss() }
    }
}
