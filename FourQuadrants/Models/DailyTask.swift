import SwiftUI
import SwiftData

@Model
final class DailyTask {
    // MARK: - 基本信息
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date() // 创建日期
    
    // MARK: - 时间规划
    var scheduledDate: Date = Date() // 规划在哪一天
    var startTime: Date = Date()     // 开始时间
    var duration: TimeInterval = 3600 // 持续时长（秒），默认1小时
    
    // MARK: - 状态
    var isCompleted: Bool = false
    var completedAt: Date?
    
    // MARK: - 智能关联
    var linkedQuadrantTaskID: UUID? // 关联的四象限任务 ID
    var embeddingData: Data?        // 预留给向量数据
    
    // MARK: - 视觉样式
    var colorHex: String?           // 自定义颜色
    var notes: String?
    
    // MARK: - 计算属性
    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }
    
    init(
        title: String,
        scheduledDate: Date,
        startTime: Date,
        duration: TimeInterval = 3600,
        colorHex: String? = nil
    ) {
        self.title = title
        self.scheduledDate = scheduledDate
        self.startTime = startTime
        self.duration = duration
        self.colorHex = colorHex
        self.date = Date()
    }
}
