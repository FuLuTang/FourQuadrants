import SwiftUI

struct TaskFormView: View {
    @Environment(\.dismiss) var dismiss
    let taskStore: TaskStore
    var existingTask: QuadrantTask?
    
    // 状态变量
    @State private var title: String
    @State private var notes: String
    @State private var importance: ImportanceLevel
    @State private var isUrgent: Bool
    @State private var hasTargetDate: Bool   // 是否设置目标日期
    @State private var dueAt: Date      // 目标日期
    // **新增紧急阈值相关变量**
    @State private var hasUrgentThreshold: Bool
    @State private var urgentThresholdDays: Int
    @State private var isTop: Bool = false
    
    // 键盘焦点状态 - 修复第三方输入法卡死问题
    @FocusState private var isTitleFocused: Bool
    
    init(taskStore: TaskStore, existingTask: QuadrantTask? = nil) {
        self.taskStore = taskStore
        self.existingTask = existingTask
        _title = State(initialValue: existingTask?.title ?? "")
        _notes = State(initialValue: existingTask?.notes ?? "")
        _importance = State(initialValue: existingTask?.importance ?? .normal)
        _isUrgent = State(initialValue: existingTask?.isUrgent ?? false)
        _isTop = State(initialValue: existingTask?.isTop ?? false)
        _hasTargetDate = State(initialValue: existingTask?.effectiveDueDateKey != nil)
        _dueAt = State(initialValue: existingTask?.displayDueDate ?? Date())
        _hasUrgentThreshold = State(initialValue: existingTask?.urgentThresholdDays != nil)
        _urgentThresholdDays = State(initialValue: existingTask?.urgentThresholdDays ?? existingTask?.originalUrgentThresholdDays ?? 3)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("task_details")) {
                    TextField("task_name", text: $title)
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isTitleFocused = false
                        }
                    MarkdownTaskNotesEditor(text: $notes)
                }

                Section(header: Text("importance")) {
                    Picker("importance", selection: $importance) {
                        Text("low").tag(ImportanceLevel.low)
                        Text("normal").tag(ImportanceLevel.normal)
                        Text("high").tag(ImportanceLevel.high)
                    }
                    .pickerStyle(.segmented)
                    Toggle("urgent", isOn: $isUrgent)
                        .disabled(hasUrgentThreshold)
                    Toggle("top", isOn: $isTop)
                }
                
                // 新增：目标日期选择
                Section(header: Text("target_date")) {
                    Toggle("set_target_date", isOn: $hasTargetDate)
                    
                    if hasTargetDate {
                        DatePicker(
                            "select_date",
                            selection: $dueAt,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        
                        // **只有设置了目标日期才显示紧急阈值选项**
                        Toggle("set_urgent_threshold", isOn: $hasUrgentThreshold)
                        if hasUrgentThreshold {
                            Stepper(String(format: String(localized: "urgent_threshold_days"), urgentThresholdDays), value: $urgentThresholdDays, in: 1...30)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(existingTask == nil ? "add_task" : "edit_task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        isTitleFocused = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTask == nil ? "add" : "save") {
                        if saveTask() {
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
                // 键盘工具栏 Done 按钮
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTitleFocused = false
                    }
                }
            }
        }
        .presentationDetents([.large]) // 使用 .large 避免键盘冲突
    }
    
    // **统一保存逻辑**
    @discardableResult
    private func saveTask() -> Bool {
        // 先关闭键盘
        isTitleFocused = false
        
        let finalTargetDate = hasTargetDate ? dueAt : nil
        let finalUrgentThreshold = (hasTargetDate && hasUrgentThreshold) ? urgentThresholdDays : nil
        if let task = existingTask {
            return taskStore.updateTask(
                task,
                title: title,
                notes: notes.isEmpty ? nil : notes,
                importance: importance,
                isUrgent: isUrgent,
                isTop: isTop,
                dueAt: finalTargetDate,
                urgentThresholdDays: finalUrgentThreshold,
                originalUrgentThresholdDays: finalUrgentThreshold,
                originalImportance: importance
            )
        } else {
            return taskStore.addTask(
                title: title,
                notes: notes.isEmpty ? nil : notes,
                importance: importance,
                isUrgent: isUrgent,
                isTop: isTop,
                dueAt: finalTargetDate,
                urgentThresholdDays: finalUrgentThreshold,
                originalUrgentThresholdDays: finalUrgentThreshold,
                originalImportance: importance
            )
        }
    }
}
