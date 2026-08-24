import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TaskStore.self) private var taskStore
    @State private var selectedTab: Tab = .quadrant

    private enum Tab: Hashable { case daily, quadrant, list, settings }

    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == selectedTab && newValue == .daily {
                    NotificationCenter.default.post(name: .scrollDailyToNow, object: nil)
                }
                selectedTab = newValue
            }
        )) {
            DailyView().tag(Tab.daily).tabItem { Label("tab_daily", systemImage: "calendar") }
            QuadrantViewContainer(taskStore: taskStore).tag(Tab.quadrant).tabItem { Label("tab_quadrants", systemImage: "square.grid.2x2") }
            ListView(taskStore: taskStore).tag(Tab.list).tabItem { Label("tab_list", systemImage: "list.bullet") }
            SettingsView().tag(Tab.settings).tabItem { Label("tab_settings", systemImage: "gear") }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(.systemGray6), for: .tabBar)
        .ignoresSafeArea(.container, edges: [.bottom])
        .onAppear { LiveActivityManager.shared.startTimerIfNeeded(container: modelContext.container) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                LiveActivityManager.shared.checkTask(context: modelContext)
                Task { await SyncService.shared.synchronize() }
            }
        }
        .alert("保存失败", isPresented: Binding(
            get: { taskStore.lastErrorMessage != nil },
            set: { if !$0 { taskStore.dismissLastError() } }
        )) {
            Button("好", role: .cancel) { taskStore.dismissLastError() }
        } message: {
            Text(taskStore.lastErrorMessage ?? "请重试。")
        }
    }
}

#Preview {
    let container = try! PersistenceController.inMemoryContainer()
    MainView().modelContainer(container).environment(TaskStore(modelContext: container.mainContext))
}
