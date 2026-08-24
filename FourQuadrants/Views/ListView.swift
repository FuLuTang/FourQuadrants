import SwiftUI
import SwiftData

struct ListView: View {
    let taskStore: TaskStore
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
                    taskStore: taskStore,
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
                    taskStore: taskStore,
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
    let taskStore: TaskStore
    @Query(sort: \QuadrantTask.updatedAt, order: .reverse) private var tasks: [QuadrantTask]
    @Binding var selectedCategory: TaskCategory?
    var onCreate: (() -> Void)? = nil
    var onEdit: ((QuadrantTask) -> Void)? = nil
    @State private var showingTaskFormView = false
    @State private var selectedTaskForEditing: QuadrantTask?

    var body: some View {
        List {
            ForEach(taskStore.filteredTasks(tasks, in: category)) { task in
                TaskRow(task: task, onToggle: {
                    taskStore.toggleTask(task)
                }, onEdit: {
                    edit(task)
                }, onDelete: {
                    taskStore.removeTask(task)
                })
                .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                .listRowSeparator(.visible)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)) // 紧凑的行内边距
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        taskStore.removeTask(task)
                    } label: {
                        Label("menu_delete", systemImage: "trash")
                    }
                    
                    Button {
                        edit(task)
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
                    createTask()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $selectedTaskForEditing) { task in
            TaskFormView(taskStore: taskStore, existingTask: task)
        }
        .sheet(isPresented: $showingTaskFormView) {
            TaskFormView(taskStore: taskStore)
        }
    }

    private func createTask() {
        if let onCreate {
            onCreate()
        } else {
            showingTaskFormView = true
        }
    }

    private func edit(_ task: QuadrantTask) {
        if let onEdit {
            onEdit(task)
        } else {
            selectedTaskForEditing = task
        }
    }
}

// MARK: - Preview
#Preview {
    let container = try! ModelContainer(
        for: QuadrantTask.self, DailyTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ListView(taskStore: TaskStore(modelContext: container.mainContext))
        .modelContainer(container)
}
