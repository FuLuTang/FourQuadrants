import SwiftUI

struct QuadrantViewContainer: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showingTaskFormView = false
    @State private var previewCategory: TaskCategory? = nil
    @Namespace private var previewNamespace
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        OverviewView(title: "重要且紧急", color: .red, category: .importantAndUrgent, taskManager: taskManager, onZoom: { cat in
                            withAnimation { previewCategory = cat }
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        OverviewView(title: "重要不紧急", color: .blue, category: .importantButNotUrgent, taskManager: taskManager, onZoom: { cat in
                            withAnimation { previewCategory = cat }
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    HStack(spacing: 10) {
                        OverviewView(title: "紧急不重要", color: .green, category: .urgentButNotImportant, taskManager: taskManager, onZoom: { cat in
                            withAnimation { previewCategory = cat }
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        OverviewView(title: "不重要不紧急", color: .gray, category: .notImportantAndNotUrgent, taskManager: taskManager, onZoom: { cat in
                            withAnimation { previewCategory = cat }
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
                .navigationTitle("任务管理")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingTaskFormView = true
                        } label: {
                            Image(systemName: "plus")
                                .padding(8)
                                .background(Color.accentColor.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                }
                .sheet(isPresented: $showingTaskFormView) {
                    TaskFormView(taskManager: taskManager)
                }
            }
            
            // **弹窗**叠加层
            if let cat = previewCategory {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) { previewCategory = nil }
                    }
                GeometryReader { proxy in
                    TaskListView(category: cat, taskManager: taskManager, selectedCategory: .constant(cat))
                        .matchedGeometryEffect(id: "preview\(cat.rawValue)", in: previewNamespace)
                        .frame(width: proxy.size.width * 0.8, height: proxy.size.height * 0.8)
                        .background(Color.white)
                        .cornerRadius(16)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .transition(.scale)
                }
                .ignoresSafeArea()
            }
        }
    }
}
