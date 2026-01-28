import SwiftUI

struct AppContainer: View {
    @StateObject private var taskManager = TaskManager()
    @State private var selectedTab: Tab = .quadrants
    
    enum Tab {
        case quadrants
        case list
        case settings
    }
    
    var body: some View {
        ZStack {
            // Unify background across the app
            AppTheme.Colors.backgroundGradient
                .ignoresSafeArea()
            
            // Content Layer
            ZStack {
                switch selectedTab {
                case .quadrants:
                    QuadrantViewContainer(taskManager: taskManager)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                case .list:
                    ListView(taskManager: taskManager)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .settings:
                    SettingsView()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .animation(.smooth(duration: 0.3), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Extra padding at bottom for floating bar
            .safeAreaInset(edge: .bottom) {
                 Color.clear.frame(height: 80)
            }
            
            // Floating Tab Bar Layer
            VStack {
                Spacer()
                FloatingTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.light) // Force light mode primarily for the mesh gradients, or make adaptive
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: AppContainer.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "square.grid.2x2.fill", label: "Matrix", isSelected: selectedTab == .quadrants) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .quadrants
                }
            }
            
            Spacer(minLength: 0)
                .frame(width: 20)
                
            TabBarButton(icon: "list.bullet.rectangle.portrait.fill", label: "List", isSelected: selectedTab == .list) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .list
                }
            }
            
            Spacer(minLength: 0)
                .frame(width: 20)
            
            TabBarButton(icon: "gearshape.fill", label: "Settings", isSelected: selectedTab == .settings) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .settings
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.5), lineWidth: 0.5)
                )
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .blur(radius: 10)
                            .opacity(0.4)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(height: 30)
                
//                if isSelected {
//                    Text(label)
//                        .font(.caption2)
//                        .fontWeight(.semibold)
//                        .foregroundStyle(.primary)
//                        .transition(.move(edge: .bottom).combined(with: .opacity))
//                }
            }
            .frame(width: 60)
        }
        .buttonStyle(FloatButtonStyle())
    }
}

#Preview {
    AppContainer()
}
