import SwiftUI
import SwiftData

struct ListView: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showingTaskFormView = false
    @State private var selectedCategory: TaskCategory? = .all
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                // 独立"全部"选项
                NavigationLink(value: TaskCategory.all) {
                    Text("category_all_incomplete")
                }
                .listRowBackground(Color(.secondarySystemBackground))
                
                // 四象限分组
                Section(header: Text("category_quadrants_section")) {
                    ForEach([TaskCategory.importantAndUrgent, TaskCategory.urgentButNotImportant, TaskCategory.importantButNotUrgent, TaskCategory.notImportantAndNotUrgent], id: \.self) { category in
                        NavigationLink(value: category) {
                            Text(category.displayName)
                        }
                        .listRowBackground(Color(.secondarySystemBackground))
                    }
                }

                // 已完成分组
                Section(header: Text("category_completed_section")) {
                    NavigationLink(value: TaskCategory.completed) {
                        Text(TaskCategory.completed.displayName)
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
            .navigationTitle("category_title")
            }
        detail: {
            if let category = selectedCategory {
                TaskListView(
                    category: category,
                    taskManager: taskManager,
                    selectedCategory: $selectedCategory
                )
            } else {
                Text("select_category_prompt")
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
    @State private var selectedTaskForEditing: QuadrantTask?
    @State private var showingTaskDetailsAlert = false
    @State private var taskDetails: String = ""

    var body: some View {
        List {
            ForEach(taskManager.filteredTasks(in: category)) { task in
                TaskRow(task: task, onToggle: {
                    taskManager.toggleTask(task)
                }, onEdit: {
                    selectedTaskForEditing = task
                    showingEditTaskView = true
                }, onDelete: {
                    taskManager.removeTask(by: task.id)
                })
                .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                .listRowSeparator(.visible)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)) // 紧凑的行内边距
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTaskForEditing = task
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        taskManager.removeTask(by: task.id)
                    } label: {
                        Label("menu_delete", systemImage: "trash")
                    }
                    
                    Button {
                        selectedTaskForEditing = task
                        showingEditTaskView = true
                    } label: {
                        Label("menu_edit", systemImage: "pencil")
                    }
                    .tint(category.themeColor)
                }
            }
        }
        .listStyle(.plain) // 使用 plain 样式，去掉 insetGrouped 的额外间距
        .navigationTitle(category.displayName)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
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
            Alert(title: Text("alert_task_details_title"), message: Text(taskDetails), dismissButton: .default(Text("alert_ok")))
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }


}

// MARK: - Preview
#Preview {
    let container = try! ModelContainer(
        for: QuadrantTask.self, DailyTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ListView(taskManager: TaskManager(modelContext: container.mainContext))
        .modelContainer(container)
}
