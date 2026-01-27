import SwiftUI

struct ListView: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showingTaskFormView = false
    @State private var selectedCategory: TaskCategory? = .all
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                // 独立"全部"选项
                NavigationLink(value: TaskCategory.all) {
                    Text("全部未完成")
                }
                .listRowBackground(Color(.secondarySystemBackground))
                
                // 四象限分组
                Section(header: Text("四象限")) {
                    ForEach([TaskCategory.importantAndUrgent, TaskCategory.urgentButNotImportant, TaskCategory.importantButNotUrgent, TaskCategory.notImportantAndNotUrgent], id: \.self) { category in
                        NavigationLink(value: category) {
                            Text(category.rawValue)
                        }
                        .listRowBackground(Color(.secondarySystemBackground))
                    }
                }

                // 已完成分组
                Section(header: Text("已完成")) {
                    NavigationLink(value: TaskCategory.completed) {
                        Text(TaskCategory.completed.rawValue)
                    }
                    .listRowBackground(Color(.secondarySystemBackground))
                }
            }
            .navigationDestination(for: TaskCategory.self) { category in
                TaskListView(
                    category: category,
                    taskManager: taskManager,
                    selectedCategory: $selectedCategory
                )
            }
            .listStyle(.insetGrouped)
            .navigationTitle("分类")
            }
        detail: {
            if let category = selectedCategory {
                TaskListView(
                    category: category,
                    taskManager: taskManager,
                    selectedCategory: $selectedCategory
                )
            } else {
                Text("请选择分类")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear { selectedCategory = .all }
    }
}

struct TaskListView: View {
    let category: TaskCategory
    @ObservedObject var taskManager: TaskManager
    @Binding var selectedCategory: TaskCategory?
    @State private var showingTaskFormView = false
    @State private var showingEditTaskView = false
    @State private var selectedTaskForEditing: Task?
    @State private var showingTaskDetailsAlert = false
    @State private var taskDetails: String = ""

    var body: some View {
        List {
            ForEach(filteredTasks) { task in
                HStack {
                    // 左侧区域（用于切换任务完成状态）
                    HStack {
                        if task.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(5)
                    .contentShape(Rectangle()) // 确保整个 HStack 可点击
                    .onTapGesture {
                        taskManager.toggleTask(task)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if task.isTop {
                                Image(systemName: "chevron.up.2")
                                    .foregroundColor(.blue)
                            }
                            Text(task.title)
                        }
                        .padding(.bottom, 2)
                        if let targetDate = task.targetDate {
                            Text("目标日期: \(formattedDate(targetDate))")
                                .font(.caption)
                                .foregroundColor(task.isOverdue ? .red : .gray)
                        }
                    }
                    
                    Spacer()

                    // 右侧“圈 i”菜单按钮（不会触发 onTapGesture）
                    Menu {
                        Button {
                            selectedTaskForEditing = task
                            showingEditTaskView = true
                        } label: {
                            Label("修改", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            taskManager.removeTask(by: task.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }

                        Button {
                            taskDetails = """
                            标题: \(task.title)
                            创建日期: \(formattedDate(task.date))
                            目标日期: \(task.targetDate.map { formattedDate($0) } ?? "无")
                            是否完成: \(task.isCompleted ? "是" : "否")
                            重要性: \(task.importance.rawValue)
                            是否紧急: \(task.isUrgent ? "是" : "否")
                            是否置顶: \(task.isTop ? "是" : "否")   
                            完成日期: \(task.completionDate.map { formattedDate($0) } ?? "无")
                            """
                            showingTaskDetailsAlert = true
                        } label: {
                            Label("查看task数据", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        taskManager.removeTask(by: task.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    
                    Button {
                        selectedTaskForEditing = task
                        showingEditTaskView = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle(category.rawValue)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingTaskFormView = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $selectedTaskForEditing) { task in
            TaskFormView(taskManager: taskManager, existingTask: task)
        }
        .sheet(isPresented: $showingTaskFormView) {
            TaskFormView(taskManager: taskManager)
        }
        .alert(isPresented: $showingTaskDetailsAlert) {
            Alert(title: Text("任务详情"), message: Text(taskDetails), dismissButton: .default(Text("确定")))
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var filteredTasks: [Task] {
        let now = Date()
        let filtered = taskManager.tasks.filter { task in
            let isImportant = task.importance == .high  // 判断是否重要
            switch category {
            case .all:
                return !task.isCompleted || now.timeIntervalSince(task.completionDate ?? now) <= 3
            case .importantAndUrgent:
                return isImportant && task.isUrgent && (!task.isCompleted || now.timeIntervalSince(task.completionDate ?? now) <= 3)
            case .importantButNotUrgent:
                return isImportant && !task.isUrgent && (!task.isCompleted || now.timeIntervalSince(task.completionDate ?? now) <= 3)
            case .urgentButNotImportant:
                return !isImportant && task.isUrgent && (!task.isCompleted || now.timeIntervalSince(task.completionDate ?? now) <= 3)
            case .notImportantAndNotUrgent:
                return !isImportant && !task.isUrgent && (!task.isCompleted || now.timeIntervalSince(task.completionDate ?? now) <= 3)
            case .completed:
                return task.isCompleted
            }
        }
        return taskManager.sortTasks(filtered, by: .intelligence) // 选择排序方式
    }
}
