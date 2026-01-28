import SwiftUI

struct QuadrantViewContainer: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showingTaskFormView = false
    @State private var previewCategory: TaskCategory? = nil
    @Namespace private var previewNamespace
    
    var body: some View {
        ZStack {
            // Premium background: Fluid Mesh Gradient style
            AppTheme.Colors.backgroundGradient
                .ignoresSafeArea()
            
            NavigationStack {
                VStack(spacing: AppTheme.Padding.standard) {
                    HStack(spacing: AppTheme.Padding.standard) {
                        OverviewView(category: .importantAndUrgent, taskManager: taskManager, onZoom: { cat in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { previewCategory = cat }
                        })
                        
                        OverviewView(category: .importantButNotUrgent, taskManager: taskManager, onZoom: { cat in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { previewCategory = cat }
                        })
                    }
                    HStack(spacing: AppTheme.Padding.standard) {
                        OverviewView(category: .urgentButNotImportant, taskManager: taskManager, onZoom: { cat in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { previewCategory = cat }
                        })
                        
                        OverviewView(category: .notImportantAndNotUrgent, taskManager: taskManager, onZoom: { cat in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { previewCategory = cat }
                        })
                    }
                }
                .padding()
                .navigationTitle("四象限看板")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingTaskFormView = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28)) // Larger, bolder touch target
                                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(radius: 4)
                        }
                    }
                }
                .background(Color.clear)
                .sheet(isPresented: $showingTaskFormView) {
                    TaskFormView(taskManager: taskManager)
                }
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            
            // **Zoom** Overlay Layer
            if let cat = previewCategory {
                // Dimming background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial) // Added blur to background
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring()) { previewCategory = nil }
                    }
                
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        // Custom Header for Zoomed View
                        HStack {
                            Label(cat.displayName, systemImage: cat.icon)
                                .font(.title3.bold())
                                .foregroundColor(cat.themeColor)
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
                    .frame(width: proxy.size.width * 0.9, height: proxy.size.height * 0.8)
                    // Apply new Holographic Card style manually as it's a large container
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: cat.themeColor.opacity(0.3), radius: 40, x: 0, y: 20) // Colored shadow glow
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity)))
                }
                .ignoresSafeArea()
            }
        }
    }
}
