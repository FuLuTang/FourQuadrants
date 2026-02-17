import SwiftUI
import SwiftData

struct QuadrantViewContainer: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showingTaskFormView = false
    
    // 现代状态管理：对分两类动效
    @State private var navPath = NavigationPath()
    @State private var activeSheetCategory: TaskCategory? = nil
    
    @Namespace private var previewNamespace
    
    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // 左上：重要且紧急 -> Zoom
                    quadrant(for: .importantAndUrgent, title: "category_important_urgent", color: .red)
                    
                    // 右上：重要不紧急 -> Sheet
                    quadrant(for: .importantButNotUrgent, title: "category_important_not_urgent", color: .blue)
                }
                HStack(spacing: 12) {
                    // 左下：紧急不重要 -> Sheet
                    quadrant(for: .urgentButNotImportant, title: "category_urgent_not_important", color: .green)
                    
                    // 右下：不重要不紧急 -> Zoom
                    quadrant(for: .notImportantAndNotUrgent, title: "category_not_important_not_urgent", color: .gray)
                }
            }
            .padding(12)
            .toolbar(.hidden, for: .navigationBar)
            
            // 自定义顶部 Header
            .safeAreaInset(edge: .top) {
                headerView
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            
            // --- 实现原生的 Zoom 动效目标 ---
            .navigationDestination(for: TaskCategory.self) { category in
                TaskListView(category: category, taskManager: taskManager, selectedCategory: .constant(category))
                    .navigationTransition(.zoom(sourceID: category, in: previewNamespace))
            }
        }
        // --- 实现原生的 Sheet + Detents 目标 ---
        .sheet(item: $activeSheetCategory) { category in
            NavigationStack {
                TaskListView(category: category, taskManager: taskManager, selectedCategory: .constant(category))
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
            TaskFormView(taskManager: taskManager)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func quadrant(for category: TaskCategory, title: String, color: Color) -> some View {
        OverviewView(
            title: String(localized: String.LocalizationValue(title)),
            color: color,
            category: category,
            taskManager: taskManager,
            onZoom: { cat in
                handleExpansion(for: cat)
            }
        )
        // 关键：将此 View 标记为 Zoom 的动画源
        .matchedTransitionSource(id: category, in: previewNamespace)
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
        // 对角线逻辑：左上 & 右下使用 Zoom
        if category == .importantAndUrgent || category == .notImportantAndNotUrgent {
            navPath.append(category)
        } else {
            // 右上 & 左下使用 Sheet
            activeSheetCategory = category
        }
    }
}

// MARK: - Preview
#Preview {
    let container = try! ModelContainer(
        for: QuadrantTask.self, DailyTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return QuadrantViewContainer(taskManager: TaskManager(modelContext: container.mainContext))
        .modelContainer(container)
}
