import SwiftUI
import SwiftData

private enum TaskEditorRoute: Identifiable {
    case create
    case edit(QuadrantTask)

    var id: String {
        switch self {
        case .create:
            return "create"
        case let .edit(task):
            return task.id.uuidString
        }
    }
}

struct QuadrantViewContainer: View {
    let taskStore: TaskStore
    @Environment(\.modelContext) private var modelContext
    @State private var showingTaskFormView = false
    @State private var activeSheetCategory: TaskCategory? = nil
    @State private var pendingTaskEditor: TaskEditorRoute?
    @State private var taskEditor: TaskEditorRoute?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 左上：重要且紧急
                quadrant(for: .importantAndUrgent, title: "category_important_urgent", color: .red)
                
                // 右上：重要不紧急
                quadrant(for: .importantButNotUrgent, title: "category_important_not_urgent", color: .blue)
            }
            HStack(spacing: 12) {
                // 左下：紧急不重要
                quadrant(for: .urgentButNotImportant, title: "category_urgent_not_important", color: .green)
                
                // 右下：不重要不紧急
                quadrant(for: .notImportantAndNotUrgent, title: "category_not_important_not_urgent", color: .gray)
            }
        }
        .padding(12)
        
        // 自定义顶部 Header
        .safeAreaInset(edge: .top) {
            headerView
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        
        // --- 上拉菜单 Sheet ---
        .sheet(item: $activeSheetCategory, onDismiss: presentPendingTaskEditor) { category in
            NavigationStack {
                TaskListView(
                    category: category,
                    taskStore: taskStore,
                    selectedCategory: .constant(category),
                    onCreate: { requestTaskEditor(.create) },
                    onEdit: { requestTaskEditor(.edit($0)) }
                )
                    .navigationTitle(category.displayName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "alert_ok")) { activeSheetCategory = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTaskFormView) {
            TaskFormView(taskStore: taskStore)
        }
        .sheet(item: $taskEditor) { route in
            switch route {
            case .create:
                TaskFormView(taskStore: taskStore)
            case let .edit(task):
                TaskFormView(taskStore: taskStore, existingTask: task)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetRoute)) { notification in
            guard let route = notification.object as? WidgetRoute else { return }
            switch route {
            case let .quadrant(category):
                activeSheetCategory = category
            case let .task(id):
                let descriptor = FetchDescriptor<QuadrantTask>(predicate: #Predicate { $0.id == id })
                if let task = try? modelContext.fetch(descriptor).first {
                    taskEditor = .edit(task)
                }
            case .today:
                break
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func quadrant(for category: TaskCategory, title: String, color: Color) -> some View {
        OverviewView(
            title: String(localized: String.LocalizationValue(title)),
            color: color,
            category: category,
            taskStore: taskStore,
            onZoom: { cat in
                handleExpansion(for: cat)
            }
        )
    }
    
    private var headerView: some View {
        HStack {
            Text("quadrant_board_title")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .padding(.leading, 8)
            
            Spacer()
            
            Button {
                showingTaskFormView = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .clipShape(Circle())
                    .glassEffect(
                        .clear.tint(.blue).interactive(),
                        in: .circle
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea(edges: .top))
    }
    
    // MARK: - Logic
    
    private func handleExpansion(for category: TaskCategory) {
        activeSheetCategory = category
    }

    private func requestTaskEditor(_ route: TaskEditorRoute) {
        pendingTaskEditor = route
        activeSheetCategory = nil
    }

    private func presentPendingTaskEditor() {
        taskEditor = pendingTaskEditor
        pendingTaskEditor = nil
    }
}

// MARK: - Preview
#Preview {
    let container = try! ModelContainer(
        for: QuadrantTask.self, DailyTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return QuadrantViewContainer(taskStore: TaskStore(modelContext: container.mainContext))
        .modelContainer(container)
}
