import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var taskManager: TaskManager?
    
    var body: some View {
        Group {
            if let taskManager = taskManager {
                TabView {
                    QuadrantViewContainer(taskManager: taskManager)
                        .tabItem {
                            Image(systemName: "square.grid.2x2")
                            Text("四象限")
                        }
                    
                    DailyView()
                        .tabItem {
                            Image(systemName: "calendar")
                            Text("今日")
                        }
                    
                    ListView(taskManager: taskManager)
                        .tabItem {
                            Image(systemName: "list.bullet")
                            Text("列表")
                        }
                    
                    SettingsView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("设置")
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
        }
    }
}

#Preview {
    MainView()
}