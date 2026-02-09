import SwiftUI

struct QuadrantViewContainer: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showingTaskFormView = false
    @State private var previewCategory: TaskCategory? = nil
    @Namespace private var previewNamespace
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    OverviewView(title: String(localized: "category_important_urgent"), color: .red, category: .importantAndUrgent, taskManager: taskManager, onZoom: { cat in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { previewCategory = cat }
                    })
                    
                    OverviewView(title: String(localized: "category_important_not_urgent"), color: .blue, category: .importantButNotUrgent, taskManager: taskManager, onZoom: { cat in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { previewCategory = cat }
                    })
                }
                HStack(spacing: 12) {
                    OverviewView(title: String(localized: "category_urgent_not_important"), color: .green, category: .urgentButNotImportant, taskManager: taskManager, onZoom: { cat in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { previewCategory = cat }
                    })
                    
                    OverviewView(title: String(localized: "category_not_important_not_urgent"), color: .gray, category: .notImportantAndNotUrgent, taskManager: taskManager, onZoom: { cat in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { previewCategory = cat }
                    })
                }
            }
            .padding(12)
            // 隐藏系统导航栏，消除分色块
            .toolbar(.hidden, for: .navigationBar)
            
            // 自定义顶部 Header (以替代系统导航栏)
            .safeAreaInset(edge: .top) {
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
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .glassEffect()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea(edges: .top)) // 延伸到状态栏
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $showingTaskFormView) {
                TaskFormView(taskManager: taskManager)
            }
            .overlay {
                if let cat = previewCategory {
                    zoomOverlay(for: cat)
                }
            }
        }
    }
    
    @ViewBuilder
    private func zoomOverlay(for cat: TaskCategory) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    withAnimation(.spring()) { previewCategory = nil }
                }
            
            VStack(spacing: 0) {
                HStack {
                    Text(cat.displayName)
                        .font(.title3.bold())
                    Spacer()
                    Button {
                        withAnimation(.spring()) { previewCategory = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                TaskListView(category: cat, taskManager: taskManager, selectedCategory: .constant(cat))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .padding(24)
            .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
            .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity)))
        }
    }
}
