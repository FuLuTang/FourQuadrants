import SwiftUI
import SwiftData

@main
struct FourQuadrantsApp: App {
    let modelContainer: ModelContainer
    @State private var showWhatsNew = false
    
    init() {
        // 尝试使用 App Group 共享路径，失败则回退到默认路径
        let container: ModelContainer
        do {
            let config = ModelConfiguration(
                groupContainer: .identifier("group.fulu.FourQuadrants")
            )
            container = try ModelContainer(
                for: QuadrantTask.self, DailyTask.self,
                configurations: config
            )
            print("✅ 数据库使用 App Group 路径")
        } catch {
            print("⚠️ App Group 路径失败，回退到默认路径: \(error)")
            // 回退到默认路径
            do {
                container = try ModelContainer(for: QuadrantTask.self, DailyTask.self)
                print("✅ 数据库使用默认路径")
            } catch {
                fatalError("❌ 数据库初始化完全失败: \(error)")
            }
        }
        self.modelContainer = container
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .task {
                    // 1. 执行升级检查（包括 Schema 迁移）
                    let shouldShowWhatsNew = AppLifecycleManager.shared.performUpdateIfNeeded(
                        modelContainer: modelContainer
                    )
                    if shouldShowWhatsNew {
                        // TODO: 可以在这里触发 What's New 弹窗
                        // showWhatsNew = true
                    }
                    
                    // 2. 请求通知权限
                    requestNotificationPermission()
                }
            // TODO: What's New 弹窗
            // .sheet(isPresented: $showWhatsNew) {
            //     WhatsNewView()
            // }
        }
        .modelContainer(modelContainer)
    }
    
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ 通知权限已获取")
            } else if let error = error {
                print("❌ 通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
}

