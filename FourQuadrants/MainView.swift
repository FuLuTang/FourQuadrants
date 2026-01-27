import SwiftUI

struct MainView: View {
    @StateObject private var taskManager = TaskManager() // 创建共享的 TaskManager 实例
    
    var body: some View {
        TabView {
            QuadrantViewContainer(taskManager: taskManager) // 传递共享的 TaskManager 实例
                .tabItem {
                    Image(systemName: "square.grid.2x2") // 四个方块的图标
                    Text("四象限")
                }
            
            ListView(taskManager: taskManager) // 传递共享的 TaskManager 实例
                .tabItem {
                    Image(systemName: "list.bullet") // 列表图标
                    Text("列表")
                }
            
            SettingsView() // 设置页面
                .tabItem {
                    Image(systemName: "gear") // 齿轮图标
                    Text("设置")
                }
        }
        // 🔥 关键修改点1：统一 TabBar 样式
        .toolbarBackground(.visible, for: .tabBar) // 强制显示背景
        .toolbarBackground(Color(.systemGray6), for: .tabBar) // 使用系统标准灰色
        .overlay(alignment: .top) {
            Divider()
                .frame(height: 0.5)
                .background(Color.gray.opacity(0.3))
        }
        // 🔥 关键修改点2：安全区域适配
        .ignoresSafeArea(.container, edges: [.bottom]) // 允许内容延伸到 TabBar 下方
    }
}

#Preview {
    MainView()
}