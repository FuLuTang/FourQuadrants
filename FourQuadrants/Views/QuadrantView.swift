import SwiftUI

struct QuadrantViewContainer: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showingTaskFormView = false
    @State private var previewCategory: TaskCategory? = nil
    
    var body: some View {
        ZStack {
            // Transparent background to let AppContainer's gradient shine through
            Color.clear
            
            VStack(spacing: 0) {
                // Custom Immersive Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Matrix")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .overlay {
                                Text("Matrix")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.primary, .primary.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .mask {
                                        Rectangle().fill(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                                    }
                            }
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text("Focus on what matters")
                            .font(.callout)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingTaskFormView = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(LinearGradient(colors: [AppTheme.Colors.importantNotUrgent, AppTheme.Colors.urgentImportant], startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .shadow(color: AppTheme.Colors.importantNotUrgent.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .floatOnTap()
                }
                .padding(.horizontal, AppTheme.Padding.loose)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // Matrix Grid
                GeometryReader { geo in
                    let w = (geo.size.width - AppTheme.Padding.standard * 3) / 2
                    let h = (geo.size.height - AppTheme.Padding.standard * 2) / 2
                    
                    VStack(spacing: AppTheme.Padding.standard) {
                        HStack(spacing: AppTheme.Padding.standard) {
                            OverviewView(category: .importantAndUrgent, taskManager: taskManager, onZoom: zoom(into:))
                                .frame(width: w, height: h)
                            OverviewView(category: .importantButNotUrgent, taskManager: taskManager, onZoom: zoom(into:))
                                .frame(width: w, height: h)
                        }
                        
                        HStack(spacing: AppTheme.Padding.standard) {
                            OverviewView(category: .urgentButNotImportant, taskManager: taskManager, onZoom: zoom(into:))
                                .frame(width: w, height: h)
                            OverviewView(category: .notImportantAndNotUrgent, taskManager: taskManager, onZoom: zoom(into:))
                                .frame(width: w, height: h)
                        }
                    }
                    .padding(.horizontal, AppTheme.Padding.standard)
                }
            }
            // Sheet
            .sheet(isPresented: $showingTaskFormView) {
                TaskFormView(taskManager: taskManager)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(30)
            }
            
            // Zoom Overlay
            zoomOverlay
        }
    }
    
    private func zoom(into category: TaskCategory) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            previewCategory = category
        }
    }
    
    @ViewBuilder
    var zoomOverlay: some View {
        if let cat = previewCategory {
            ZStack {
                // Dimming
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { previewCategory = nil }
                    }
                
                // Card
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Image(systemName: cat.icon)
                                .font(.title2)
                                .foregroundStyle(cat.themeColor)
                            Text(cat.displayName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Spacer()
                            Button {
                                withAnimation { previewCategory = nil }
                            } label: {
                                Image(systemName: "xmark")
                                    .padding(8)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        
                        Divider()
                        
                        TaskListView(category: cat, taskManager: taskManager, selectedCategory: .constant(cat))
                    }
                    .frame(width: proxy.size.width * 0.9, height: proxy.size.height * 0.75)
                    .background(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(.thickMaterial)
                            .shadow(color: cat.themeColor.opacity(0.2), radius: 50, x: 0, y: 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .zIndex(100)
        }
    }
}
