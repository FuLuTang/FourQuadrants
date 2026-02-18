import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var taskManager: TaskManager?
    @State private var selectedTab: Tab = .quadrant
    @State private var previousTab: Tab = .quadrant

    private enum Tab: Hashable {
        case daily
        case quadrant
        case list
        case settings
    }
    
    var body: some View {
        Group {
            if let taskManager = taskManager {
                TabView(selection: Binding(
                    get: { selectedTab },
                    set: { newValue in
                        // 检测是否重复点击同一个 tab
                        if newValue == selectedTab && newValue == .daily {
                            // 重复点击 daily tab，发送通知滚动到当前时间
                            NotificationCenter.default.post(name: .scrollDailyToNow, object: nil)
                        }
                        previousTab = selectedTab
                        selectedTab = newValue
                    }
                )) {
                    DailyView()
                        .tag(Tab.daily)
                        .tabItem {
                            Image(systemName: "calendar")
                            Text("tab_daily")
                        }
                    
                    QuadrantViewContainer(taskManager: taskManager)
                        .tag(Tab.quadrant)
                        .tabItem {
                            Image(systemName: "square.grid.2x2")
                            Text("tab_quadrants")
                        }
                    
                    ListView(taskManager: taskManager)
                        .tag(Tab.list)
                        .tabItem {
                            Image(systemName: "list.bullet")
                            Text("tab_list")
                        }
                    
                    SettingsView()
                        .tag(Tab.settings)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("tab_settings")
                        }
                }
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(Color(.systemGray6), for: .tabBar)
                .ignoresSafeArea(.container, edges: [.bottom])
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if taskManager == nil {
                taskManager = TaskManager(modelContext: modelContext)
            }
            // 启动灵动岛检查定时器
            LiveActivityManager.shared.startTimerIfNeeded(container: modelContext.container)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // App 从后台回到前台时，立即触发灵动岛检查
            if newPhase == .active {
                LiveActivityManager.shared.checkTask(context: modelContext)
            }
        }
    }
}

#Preview {
    MainView()
}
