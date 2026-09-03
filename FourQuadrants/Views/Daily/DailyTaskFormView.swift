import SwiftUI
import SwiftData

struct DailyTaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var taskStore
    @FocusState private var isTitleFocused: Bool
    
    // 编辑模式传入 task，新建模式为 nil
    var task: DailyTask?
    var selectedDate: Date // 新建时的默认日期
    var isNew: Bool = false
    var onSave: ((DailyTask) -> Void)? = nil
    
    // Form States
    @State private var title: String = ""
    @State private var startAt: Date = Date()
    @State private var endAt: Date = Date().addingTimeInterval(3600)
    @State private var colorHex: String = "#5E81F4"
    @State private var notes: String = ""
    
    // Delete Alert
    @State private var showDeleteAlert = false
    
    init(task: DailyTask? = nil, selectedDate: Date = Date(), isNew: Bool = false, onSave: ((DailyTask) -> Void)? = nil) {
        self.task = task
        self.selectedDate = selectedDate
        self.isNew = isNew
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. 标题与颜色
                Section {
                    TextField("daily_task_title", text: $title)
                        .font(.title3)
                        .focused($isTitleFocused)
                        .onSubmit {
                            isTitleFocused = false
                        }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .opacity(colorHex == color ? 1 : 0)
                                    )
                                    .onTapGesture {
                                        withAnimation {
                                            colorHex = color
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 2. 时间规划
                Section("daily_time_planning") {
                    DatePicker("daily_start_time", selection: $startAt, displayedComponents: .hourAndMinute)
                        .onChange(of: startAt) {
                            // 保持 duration 不变，自动推导 endAt
                            if let oldTask = task {
                                endAt = startAt.addingTimeInterval(oldTask.duration)
                            } else {
                                // 新建时默认 1 小时
                                if endAt <= startAt {
                                     endAt = startAt.addingTimeInterval(3600)
                                }
                            }
                        }
                    
                    DatePicker("daily_end_time", selection: $endAt, displayedComponents: .hourAndMinute)
                    
                    // 跨天任务提示
                    if endAt <= startAt {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.purple)
                            Text("daily_cross_day")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                
                    // 快速时长选择
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach([15, 30, 60, 90, 120], id: \.self) { min in
                                Button("\(min) \(String(localized: "daily_minutes"))") {
                                    withAnimation {
                                        endAt = startAt.addingTimeInterval(TimeInterval(min * 60))
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(Color(hex: colorHex))
                            }
                        }
                    }
                }
                
                // 3. 备注
                Section("daily_notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                // 4. 删除按钮
                if task != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("delete")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? String(localized: "daily_new_task") : String(localized: "daily_edit_task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        if saveTask() {
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
            .alert(String(localized: "confirm_delete_task_title"), isPresented: $showDeleteAlert) {
                Button("delete", role: .destructive) {
                    deleteTask()
                }
                Button("cancel", role: .cancel) { }
            } message: {
                Text("confirm_delete_task_message")
            }
            .onAppear {
                if let task = task {
                    // 编辑模式：填充数据
                    title = task.title
                    startAt = task.startAt
                    endAt = task.startAt.addingTimeInterval(task.duration)
                    colorHex = task.colorHex ?? "#5E81F4"
                    notes = task.notes ?? ""
                    
                } else {
                    // 新建模式：设置默认时间
                    let now = Date()
                    let calendar = Calendar.current
                    var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
                    if let hour = components.hour {
                        components.hour = hour + 1
                    }
                    startAt = calendar.date(from: components) ?? now
                    endAt = startAt.addingTimeInterval(3600)
                    
                    // 设置颜色为随机
                    colorHex = colors.randomElement() ?? "#5E81F4"
                }
            }
        }
    }
    
    // 预设颜色
    private let colors = [
        "#5E81F4", // Blue
        "#FF6B6B", // Red
        "#4ECDC4", // Teal
        "#FFD93D", // Yellow
        "#6C5CE7", // Purple
        "#A8E6CF", // Light Green
        "#FF8B94"  // Pink
    ]
    
    @discardableResult
    private func saveTask() -> Bool {
        var duration = endAt.timeIntervalSince(startAt)
        
        // 处理跨天任务：如果结束时间早于开始时间，说明跨越午夜
        // 例如 23:15 → 2:30，需要加 24 小时
        if duration <= 0 {
            duration += 24 * 3600  // +24小时
        }
        
        if let existingTask = task, !isNew {
            return taskStore.updateDailyTask(existingTask, title: title, startAt: startAt, duration: duration, colorHex: colorHex, notes: notes, quadrantTask: existingTask.quadrantTask)
        } else if let savedTask = taskStore.createDailyTask(title: title, startAt: startAt, duration: duration, colorHex: colorHex, notes: notes) {
            onSave?(savedTask)
            return true
        }
        return false
    }
    
    private func deleteTask() {
        guard let task = task else { return }
        if taskStore.removeDailyTask(task) {
            dismiss()
        }
    }
}


#Preview {
    DailyTaskFormView()
}
