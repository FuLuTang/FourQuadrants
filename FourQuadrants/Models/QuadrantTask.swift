import Foundation
import CoreTransferable
import UniformTypeIdentifiers

enum ImportanceLevel: String, Codable {
    case low, normal, high
}

import SwiftData

// MARK: - ⚠️ Schema 版本提醒
// 修改 @Model 结构（添加/删除/重命名字段）时，必须同步操作：
// 1. 在 AppLifecycleManager.swift 中递增 currentSchemaVersion
// 2. 添加对应的 migrateSchemaToVX() 迁移函数
// 3. 在 performSchemaMigrationIfNeeded() 中调用新迁移
//
// 当前 Schema 版本：V3
// - V1: 初始版本 (QuadrantTask + DailyTask)
// - V2: 新增 originalUrgentThresholdDays
// - V3: 新增 originalImportance

@Model
final class QuadrantTask {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var dateLatestModified: Date = Date()
    var targetDate: Date? = nil
    var isCompleted: Bool = false
    var importance: ImportanceLevel = ImportanceLevel.normal
    
    // Mapping: High -> Important; Normal/Low -> Not Important
    @Transient var isImportantQuadrant: Bool {
        return importance == .high
    }
    
    // Renamed backing storage for manual urgency
    var manualIsUrgent: Bool = false
    
    var urgentThresholdDays: Int? = nil
    var originalUrgentThresholdDays: Int? = nil
    var originalImportance: ImportanceLevel? = nil
    var completionDate: Date?
    var isTop: Bool = false
    
    // MARK: - 智能关联 (New)
    var linkedDailyTaskIDs: [UUID]? = [] // 关联的每日任务 (反向引用)
    var embeddingData: Data?             // 语义向量数据 (预留)
    
    // Computed property for auto-urgency
    @Transient var isUrgent: Bool {
        get {
            if let threshold = urgentThresholdDays, let target = targetDate {
                let now = Calendar.current.startOfDay(for: Date())
                let targetDay = Calendar.current.startOfDay(for: target)
                let daysRemaining = Calendar.current.dateComponents([.day], from: now, to: targetDay).day ?? Int.max
                return daysRemaining <= threshold
            } else {
                return manualIsUrgent
            }
        }
        set {
            manualIsUrgent = newValue
        }
    }
    
    @Transient var isOverdue: Bool {
        guard !isCompleted, let targetDate = targetDate else { return false }
        // Use targetDate + 1 day as the deadline
        return targetDate.advanced(by: 86400) < Date()
    }
    
    /// 根据紧急和重要状态计算所属象限
    @Transient var category: TaskCategory {
        if isCompleted {
            return .completed
        }
        switch (isImportantQuadrant, isUrgent) {
        case (true, true): return .importantAndUrgent
        case (true, false): return .importantButNotUrgent
        case (false, true): return .urgentButNotImportant
        case (false, false): return .notImportantAndNotUrgent
        }
    }
    
    // Sync metadata
    var msTodoId: String? = nil
    var msLastModified: Date? = nil
    
    // Custom initializer to match existing calls that use 'isUrgent'
    init(id: UUID = UUID(), title: String, date: Date, dateLatestModified: Date = Date(), targetDate: Date? = nil, isCompleted: Bool = false, importance: ImportanceLevel = ImportanceLevel.normal, isUrgent: Bool = false, urgentThresholdDays: Int? = nil, originalUrgentThresholdDays: Int? = nil, originalImportance: ImportanceLevel? = nil, completionDate: Date? = nil, isTop: Bool = false, msTodoId: String? = nil, msLastModified: Date? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.dateLatestModified = dateLatestModified
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.importance = importance
        self.manualIsUrgent = isUrgent
        self.urgentThresholdDays = urgentThresholdDays
        self.originalUrgentThresholdDays = originalUrgentThresholdDays
        self.originalImportance = originalImportance
        self.completionDate = completionDate
        self.isTop = isTop
        self.msTodoId = msTodoId
        self.msLastModified = msLastModified
    }
}

// MARK: - 轻量级传输对象（用于拖放）
// SwiftData @Model 不能直接遵循 Codable，因此使用独立的结构体
struct TaskTransferItem: Codable, Transferable {
    let taskId: UUID
    let title: String
    let isCompleted: Bool
    let targetDate: Date?
    
    static var transferRepresentation: some TransferRepresentation {
        // 使用简单的 Codable 表示，避免复杂的多重表示可能导致的问题
        CodableRepresentation(contentType: .json)
    }
    
    init(task: QuadrantTask) {
        self.taskId = task.id
        self.title = task.title
        self.isCompleted = task.isCompleted
        self.targetDate = task.targetDate
    }
}
