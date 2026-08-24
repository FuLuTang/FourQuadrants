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
    
    // 智能关联模拟状态
    @State private var isCalculatingLink = false
    @State private var showRecommendation = false
    @State private var isLinked = false
    @State private var linkedTaskTitle: String = ""
    @State private var linkedTaskInfo: String = ""
    
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
                            // 按回车时触发推荐
                            triggerLinkCalculation()
                        }
                        .onChange(of: isTitleFocused) { oldValue, newValue in
                            // 失去焦点且内容非空时触发
                            if !newValue && !title.isEmpty {
                                triggerLinkCalculation()
                            }
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
                
                // 3. 智能关联 (Placeholder UI)
                Section("daily_smart_link_section") {
                    if isLinked {
                        // 已关联状态
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                Text("daily_linked_quadrant_task")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                            }
                            
                            // 关联任务卡片
                            HStack {
                                Circle()
                                    .fill(AppTheme.Colors.urgentImportant)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(linkedTaskTitle)
                                        .font(.subheadline.bold())
                                    Text(linkedTaskInfo)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(12)
                            
                            Button(role: .destructive) {

                                withAnimation {
                                    isLinked = false
                                    showRecommendation = true
                                }
                            } label: {
                                Label("daily_unlink", systemImage: "xmark.circle")
                                    .font(.caption)
                            }
                        }
                        .transition(.opacity)
                        
                    } else if isCalculatingLink {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("daily_analyzing")
                                .foregroundColor(.secondary)
                        }
                    } else if showRecommendation {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("daily_related_tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // 模拟推荐卡片
                            HStack {
                                Circle()
                                    .fill(AppTheme.Colors.urgentImportant)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading) {
                                    Text("daily_mock_task_title")
                                        .font(.subheadline.bold())
                                    Text("daily_mock_task_info")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    // 点击关联
                                    withAnimation {
                                        isLinked = true
                                        linkedTaskTitle = String(localized: "daily_mock_task_title")
                                        linkedTaskInfo = String(localized: "daily_mock_task_info")
                                        showRecommendation = false
                                    }
                                } label: {
                                    Text("daily_link")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .controlSize(.small)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            Button {
                                // Todo: 手动选择逻辑
                            } label: {
                                Text("daily_select_other")
                            }
                            .font(.caption)
                        }
                        .transition(.opacity)
                    } else if !title.isEmpty {
                         Text("daily_auto_recommend")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }


                
                // 4. 备注
                Section("daily_notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                // 5. 删除按钮
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
                        saveTask()
                        dismiss()
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
                    
                    // 检查是否已有关联
                    if task.quadrantTask != nil {
                        // Todo: 根据 linkedQuadrantTaskID 查询 QuadrantTask 的信息
                        // 这里先模拟
                        isLinked = true
                        linkedTaskTitle = String(localized: "daily_linked_quadrant_task_title")
                        linkedTaskInfo = String(localized: "daily_loading")
                    }
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
    
    private func saveTask() {
        var duration = endAt.timeIntervalSince(startAt)
        
        // 处理跨天任务：如果结束时间早于开始时间，说明跨越午夜
        // 例如 23:15 → 2:30，需要加 24 小时
        if duration <= 0 {
            duration += 24 * 3600  // +24小时
        }
        
        if let existingTask = task, !isNew {
            _ = taskStore.updateDailyTask(existingTask, title: title, startAt: startAt, duration: duration, colorHex: colorHex, notes: notes, quadrantTask: existingTask.quadrantTask)
        } else if let savedTask = taskStore.createDailyTask(title: title, startAt: startAt, duration: duration, colorHex: colorHex, notes: notes) {
            onSave?(savedTask)
        }
    }
    
    private func deleteTask() {
        guard let task = task else { return }
        _ = taskStore.removeDailyTask(task)
        dismiss()
    }
    
    private func triggerLinkCalculation() {
        guard !title.isEmpty else { return }
        
        // 避免重复触发
        guard !isCalculatingLink && !showRecommendation else { return }
        
        withAnimation {
            isCalculatingLink = true
        }
        
        // 模拟计算延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCalculatingLink = false
                showRecommendation = true
            }
        }
    }
}


#Preview {
    DailyTaskFormView()
}
