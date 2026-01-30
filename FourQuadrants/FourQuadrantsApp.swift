import SwiftUI
import SwiftData

@main
struct FourQuadrantsApp: App {
    let modelContainer: ModelContainer
    
    init() {
        print("📁 数据库路径: \(URL.applicationSupportDirectory.path(percentEncoded: false))")
        
        // Initialize ModelContainer with both models
        do {
            modelContainer = try ModelContainer(for: QuadrantTask.self, DailyTask.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(modelContainer)
    }
}
