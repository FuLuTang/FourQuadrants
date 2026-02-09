import ActivityKit
import Foundation

/// Live Activity 的数据结构定义
/// 需要被 Main App 和 Widget 共享
struct FourQuadrantsWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskId: String        // DailyTask.id.uuidString
        var taskName: String      // 包含 "+N" 重叠标识
        var startTime: Date
        var endTime: Date
        var colorHex: String?     // 任务颜色 (e.g., "#FF5733")
    }
    
    // 静态属性（留空，所有数据走 ContentState）
}
