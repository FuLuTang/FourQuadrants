import SwiftUI

struct TaskFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var taskManager: TaskManager
    var existingTask: Task?
    
    // 状态变量
    @State private var title: String
    @State private var importance: ImportanceLevel
    @State private var isUrgent: Bool
    @State private var hasTargetDate: Bool   // 是否设置目标日期
    @State private var targetDate: Date      // 目标日期
    // **新增紧急阈值相关变量**
    @State private var hasUrgentThreshold: Bool
    @State private var urgentThresholdDays: Int
    @State private var isTop: Bool = false
    
    init(taskManager: TaskManager, existingTask: Task? = nil) {
        self.taskManager = taskManager
        self.existingTask = existingTask
        _title = State(initialValue: existingTask?.title ?? "")
        _importance = State(initialValue: existingTask?.importance ?? .normal)
        _isUrgent = State(initialValue: existingTask?.isUrgent ?? false)
        _isTop = State(initialValue: existingTask?.isTop ?? false)
        _hasTargetDate = State(initialValue: existingTask?.targetDate != nil)
        _targetDate = State(initialValue: existingTask?.targetDate ?? Date())
        _hasUrgentThreshold = State(initialValue: existingTask?.urgentThresholdDays != nil)
        _urgentThresholdDays = State(initialValue: existingTask?.urgentThresholdDays ?? 3)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("任务详情")) {
                    TextField("任务名称", text: $title)
                    Section(header: Text("重要性")) {
                        Picker("重要性", selection: $importance) {
                            Text("低").tag(ImportanceLevel.low)
                            Text("普通").tag(ImportanceLevel.normal)
                            Text("高").tag(ImportanceLevel.high)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    Toggle("紧急", isOn: $isUrgent)
                        .disabled(hasUrgentThreshold) // **紧急阈值开启时禁用紧急开关**
                    Toggle("置顶", isOn: $isTop)
                }
                
                // 新增：目标日期选择
                Section(header: Text("目标日期")) {
                    Toggle("设置目标日期", isOn: $hasTargetDate)
                    
                    if hasTargetDate {
                        DatePicker(
                            "选择日期",
                            selection: $targetDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        
                        // **只有设置了目标日期才显示紧急阈值选项**
                        Toggle("设置紧急阈值", isOn: $hasUrgentThreshold)
                        if hasUrgentThreshold {
                            Stepper("紧急阈值天数: \(urgentThresholdDays) 天", value: $urgentThresholdDays, in: 1...30)
                        }
                    }
                }
            }
            .navigationTitle(existingTask == nil ? "添加任务" : "编辑任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTask == nil ? "添加" : "保存") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    // **统一保存逻辑**
    private func saveTask() {
        let finalTargetDate = hasTargetDate ? targetDate : nil
        let finalUrgentThreshold = (hasTargetDate && hasUrgentThreshold) ? urgentThresholdDays : nil
        let now = Date()  // 获取当前时间

        if let task = existingTask {
            taskManager.updateTask(
                task,
                title: title,
                importance: importance,
                isUrgent: isUrgent,
                isTop: isTop,
                targetDate: finalTargetDate,
                urgentThresholdDays: finalUrgentThreshold,
                dateLatestModified: now // 更新最后修改时间
            )
        } else {
            taskManager.addTask(
                title: title,
                importance: importance,
                isUrgent: isUrgent,
                isTop: isTop,
                targetDate: finalTargetDate,
                urgentThresholdDays: finalUrgentThreshold,
                dateLatestModified: now // 新建任务时记录创建时间
            )
        }
        dismiss()
    }
}