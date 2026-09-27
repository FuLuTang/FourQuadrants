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

    @State private var title: String
    @State private var notes: String
    @State private var importance: ImportanceLevel
    @State private var isUrgent: Bool
    @State private var isTop: Bool
    @State private var isCompleted: Bool
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: QuadrantTask, taskStore: TaskStore, onEditDetails: @escaping () -> Void, onPin: @escaping () -> Void) {
        self.task = task
        self.taskStore = taskStore
        self.onEditDetails = onEditDetails
        self.onPin = onPin
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes ?? "")
        _importance = State(initialValue: task.importance)
        _isUrgent = State(initialValue: task.manualIsUrgent)
        _isTop = State(initialValue: task.isTop)
        _isCompleted = State(initialValue: task.isCompleted)
        _hasDueDate = State(initialValue: task.effectiveDueDateKey != nil)
        _dueDate = State(initialValue: task.displayDueDate ?? .now)
    }

    private var automaticUrgencyEnabled: Bool {
        hasDueDate && task.urgentThresholdDays != nil
    }

    private var effectiveUrgency: Bool {
        guard automaticUrgencyEnabled, let threshold = task.urgentThresholdDays else { return isUrgent }
        let calendar = Calendar.current
        let remaining = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? .max
        return remaining <= threshold
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("任务检查器").font(.headline)
                    Text(task.category.displayName).font(.caption).foregroundStyle(task.category.themeColor)
                }
                Spacer()
                Button(action: onPin) {
                    Label("放到桌面", systemImage: "pin")
                }
                .help("将此任务固定到桌面便笺")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

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
                    showsCompletion: true,
                    hasAutomaticUrgency: automaticUrgencyEnabled,
                    effectiveUrgency: effectiveUrgency,
                    onSubmitTitle: nil
                )

                if automaticUrgencyEnabled {
                    Section("自动紧急") {
                        LabeledContent("触发阈值", value: "提前 \(task.urgentThresholdDays ?? 0) 天")
                        Text("可在详细编辑中调整当前阈值和原始阈值。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("保存更改", action: { _ = save() })
                        .buttonStyle(.borderedProminent)
                        .disabled(!isDirty || !hasValidTitle)
                    Button("详细编辑…") {
                        if !isDirty || save() { onEditDetails() }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .onChange(of: task.updatedAt) { _, _ in reloadDraft() }
    }

    private var hasValidTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDirty: Bool {
        title != task.title
            || notes != (task.notes ?? "")
            || importance != task.importance
            || isUrgent != task.manualIsUrgent
            || isTop != task.isTop
            || isCompleted != task.isCompleted
            || hasDueDate != (task.effectiveDueDateKey != nil)
            || (hasDueDate && !Calendar.current.isDate(dueDate, inSameDayAs: task.displayDueDate ?? .distantPast))
    }

    @discardableResult
    private func save() -> Bool {
        guard hasValidTitle else { return false }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let succeeded = taskStore.updateTask(
            task,
            title: cleanTitle,
            notes: cleanNotes.isEmpty ? nil : cleanNotes,
            importance: importance,
            isUrgent: isUrgent,
            isTop: isTop,
            dueAt: hasDueDate ? dueDate : nil,
            urgentThresholdDays: hasDueDate ? task.urgentThresholdDays : nil,
            originalUrgentThresholdDays: task.originalUrgentThresholdDays,
            originalImportance: task.originalImportance
        )
        guard succeeded else { return false }
        if task.isCompleted != isCompleted, !taskStore.toggleTask(task) { return false }
        return true
    }

    private func reloadDraft() {
        title = task.title
        notes = task.notes ?? ""
        importance = task.importance
        isUrgent = task.manualIsUrgent
        isTop = task.isTop
        isCompleted = task.isCompleted
        hasDueDate = task.effectiveDueDateKey != nil
        dueDate = task.displayDueDate ?? .now
    }
}
