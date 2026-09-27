import SwiftUI

struct MacTaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    let taskStore: TaskStore
    let existingTask: QuadrantTask?

    @State private var title: String
    @State private var notes: String
    @State private var importance: ImportanceLevel
    @State private var isUrgent: Bool
    @State private var isTop: Bool
    @State private var isCompleted: Bool
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var hasUrgentThreshold: Bool
    @State private var urgentThresholdDays: Int
    @State private var originalUrgentThresholdDays: Int?
    @State private var originalImportance: ImportanceLevel?
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasAutomaticUrgency: Bool {
        hasDueDate && hasUrgentThreshold
    }

    private var effectiveUrgency: Bool {
        let calendar = Calendar.current
        let daysRemaining = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? .max
        return daysRemaining <= urgentThresholdDays
    }

    init(taskStore: TaskStore, existingTask: QuadrantTask? = nil) {
        self.taskStore = taskStore
        self.existingTask = existingTask
        _title = State(initialValue: existingTask?.title ?? "")
        _notes = State(initialValue: existingTask?.notes ?? "")
        _importance = State(initialValue: existingTask?.importance ?? .normal)
        _isUrgent = State(initialValue: existingTask?.manualIsUrgent ?? false)
        _isTop = State(initialValue: existingTask?.isTop ?? false)
        _isCompleted = State(initialValue: existingTask?.isCompleted ?? false)
        _hasDueDate = State(initialValue: existingTask?.effectiveDueDateKey != nil)
        _dueDate = State(initialValue: existingTask?.displayDueDate ?? .now)
        _hasUrgentThreshold = State(initialValue: existingTask?.urgentThresholdDays != nil)
        _urgentThresholdDays = State(initialValue: existingTask?.urgentThresholdDays ?? existingTask?.originalUrgentThresholdDays ?? 3)
        _originalUrgentThresholdDays = State(initialValue: existingTask?.originalUrgentThresholdDays)
        _originalImportance = State(initialValue: existingTask?.originalImportance)
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
                    .disabled(!canSave)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            Divider()

            Form {
                MacTaskCommonFields(
                    title: $title,
                    notes: $notes,
                    importance: $importance,
                    isUrgent: $isUrgent,
                    isTop: $isTop,
                    isCompleted: $isCompleted,
                    hasDueDate: $hasDueDate,
                    dueDate: $dueDate,
                    showsCompletion: existingTask != nil,
                    hasAutomaticUrgency: hasAutomaticUrgency,
                    effectiveUrgency: effectiveUrgency,
                    onSubmitTitle: save
                )

                if hasDueDate {
                    Section("自动紧急阈值") {
                        Toggle("按临近日期自动标记紧急", isOn: $hasUrgentThreshold)
                        if hasUrgentThreshold {
                            Stepper("提前 \(urgentThresholdDays) 天", value: $urgentThresholdDays, in: 1...30)
                            Text("截止日期进入此阈值范围后，任务会归入紧急象限。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("原始值") {
                    Picker("原始重要性", selection: $originalImportance) {
                        Text("未记录").tag(ImportanceLevel?.none)
                        Text("低").tag(ImportanceLevel?.some(.low))
                        Text("普通").tag(ImportanceLevel?.some(.normal))
                        Text("高").tag(ImportanceLevel?.some(.high))
                    }
                    Toggle("记录原始紧急阈值", isOn: Binding(
                        get: { originalUrgentThresholdDays != nil },
                        set: { originalUrgentThresholdDays = $0 ? (originalUrgentThresholdDays ?? urgentThresholdDays) : nil }
                    ))
                    if originalUrgentThresholdDays != nil {
                        Stepper("原始阈值：提前 \(originalUrgentThresholdDays ?? 3) 天", value: Binding(
                            get: { self.originalUrgentThresholdDays ?? 3 },
                            set: { self.originalUrgentThresholdDays = $0 }
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
        guard canSave else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetDate = hasDueDate ? dueDate : nil
        let threshold = hasDueDate && hasUrgentThreshold ? urgentThresholdDays : nil
        var succeeded: Bool

        if let existingTask {
            succeeded = taskStore.updateTask(
                existingTask,
                title: cleanTitle,
                notes: cleanNotes.isEmpty ? nil : cleanNotes,
                importance: importance,
                isUrgent: isUrgent,
                isTop: isTop,
                dueAt: targetDate,
                urgentThresholdDays: threshold,
                originalUrgentThresholdDays: originalUrgentThresholdDays,
                originalImportance: originalImportance
            )
            if succeeded, existingTask.isCompleted != isCompleted {
                succeeded = taskStore.toggleTask(existingTask)
            }
        } else {
            succeeded = taskStore.addTask(
                title: cleanTitle,
                notes: cleanNotes.isEmpty ? nil : cleanNotes,
                importance: importance,
                isUrgent: isUrgent,
                isTop: isTop,
                dueAt: targetDate,
                urgentThresholdDays: threshold,
                originalUrgentThresholdDays: originalUrgentThresholdDays ?? threshold,
                originalImportance: originalImportance ?? importance
            )
        }

        if succeeded { dismiss() }
    }
}
