import Foundation
import SwiftData

/// App 生命周期管理器 - 负责版本检测、数据迁移、更新提示等
final class AppLifecycleManager {
    
    static let shared = AppLifecycleManager()
    
    // MARK: - Constants
    
    private enum Keys {
        static let lastAppVersion = "lastAppVersion"
        static let lastBuildNumber = "lastBuildNumber"
        static let schemaVersion = "schemaVersion"
    }
    
    /// 当前 Schema 版本号（每次修改 @Model 结构时手动递增）
    /// - 1: 初始版本 (QuadrantTask + DailyTask)
    /// - 2: 新增 originalUrgentThresholdDays 字段 (双紧急阈值)
    /// - 3: 新增 originalImportance 字段 (重要性双轨追踪)
    static let currentSchemaVersion = 3
    
    // MARK: - Properties
    
    private let defaults = UserDefaults.standard
    
    /// 当前 App 版本号 (e.g., "1.0.0")
    var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    
    /// 当前 Build 号 (e.g., "42")
    var currentBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    
    /// 上次运行的 App 版本
    var lastAppVersion: String? {
        defaults.string(forKey: Keys.lastAppVersion)
    }
    
    /// 上次运行的 Build 号
    var lastBuildNumber: String? {
        defaults.string(forKey: Keys.lastBuildNumber)
    }
    
    /// 上次运行的 Schema 版本
    var lastSchemaVersion: Int {
        defaults.integer(forKey: Keys.schemaVersion)
    }
    
    private init() {}
    
    // MARK: - 版本状态检测
    
    enum LaunchType {
        case freshInstall      // 全新安装
        case sameVersion       // 同版本启动
        case upgraded          // 版本升级
        case downgraded        // 版本降级（罕见，可能是开发中）
    }
    
    /// 判断当前启动类型
    func detectLaunchType() -> LaunchType {
        guard let last = lastAppVersion else {
            return .freshInstall
        }
        
        if last == currentAppVersion {
            return .sameVersion
        }
        
        // 简单的版本比较（假设版本号格式为 x.y.z）
        let lastComponents = last.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentAppVersion.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(lastComponents.count, currentComponents.count) {
            let lastPart = i < lastComponents.count ? lastComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            
            if currentPart > lastPart {
                return .upgraded
            } else if currentPart < lastPart {
                return .downgraded
            }
        }
        
        return .sameVersion
    }
    
    // MARK: - 主入口：执行所有升级任务
    
    /// 在 App 启动时调用，执行所有必要的升级/迁移任务
    /// - Parameter modelContainer: SwiftData ModelContainer
    /// - Returns: 是否需要显示 "What's New" 页面
    @discardableResult
    func performUpdateIfNeeded(modelContainer: ModelContainer) -> Bool {
        let launchType = detectLaunchType()
        
        print("🚀 [AppLifecycle] Launch type: \(launchType)")
        print("   Version: \(lastAppVersion ?? "nil") → \(currentAppVersion)")
        print("   Schema: \(lastSchemaVersion) → \(Self.currentSchemaVersion)")
        
        // 1. 执行数据库 Schema 迁移
        performSchemaMigrationIfNeeded(modelContainer: modelContainer)
        
        // 2. TODO: 其他升级任务可以在这里添加
        // performDataCleanupIfNeeded()
        // performCacheClearIfNeeded()
        
        // 3. 更新存储的版本信息
        saveCurrentVersionInfo()
        
        // 4. 判断是否需要显示 What's New
        let shouldShowWhatsNew = (launchType == .upgraded || launchType == .freshInstall)
        
        return shouldShowWhatsNew
    }
    
    // MARK: - Schema 迁移
    
    /// 检测并执行 SwiftData Schema 迁移
    private func performSchemaMigrationIfNeeded(modelContainer: ModelContainer) {
        let oldVersion = lastSchemaVersion
        let newVersion = Self.currentSchemaVersion
        
        guard oldVersion != newVersion else {
            print("📦 [Schema] 版本一致 (v\(newVersion))，无需迁移")
            return
        }
        
        if oldVersion == 0 {
            // 全新安装，无需迁移
            print("📦 [Schema] 全新安装，设置初始 Schema 版本 v\(newVersion)")
            return
        }
        
        print("📦 [Schema] 检测到版本变化: v\(oldVersion) → v\(newVersion)")
        
        // 按版本号逐步迁移
        if oldVersion < 1 {
            migrateSchemaToV1(modelContainer: modelContainer)
        }
        
        if oldVersion < 2 {
            migrateSchemaToV2(modelContainer: modelContainer)
        }
        
        if oldVersion < 3 {
            migrateSchemaToV3(modelContainer: modelContainer)
        }
        
        print("📦 [Schema] 迁移完成!")
    }
    
    /// 迁移到 Schema V1
    /// - 示例：处理字段重命名、默认值填充等
    private func migrateSchemaToV1(modelContainer: ModelContainer) {
        print("📦 [Schema] 执行 V1 迁移...")
        
        // SwiftData 本身会处理大部分 Schema 变更（添加可选字段、添加带默认值的字段等）
        // 这里只需要处理 SwiftData 无法自动处理的情况，例如：
        // - 字段重命名
        // - 复杂的数据转换
        // - 需要业务逻辑的默认值填充
        
        // 示例：如果需要手动更新所有任务的某个字段
        // let context = ModelContext(modelContainer)
        // let fetchDescriptor = FetchDescriptor<QuadrantTask>()
        // if let tasks = try? context.fetch(fetchDescriptor) {
        //     for task in tasks {
        //         // 执行数据转换
        //     }
        //     try? context.save()
        // }
        
        print("📦 [Schema] V1 迁移完成")
    }
    
    /// 迁移到 Schema V2
    /// - 新增 originalUrgentThresholdDays：将现有 urgentThresholdDays 拷贝为原始值
    private func migrateSchemaToV2(modelContainer: ModelContainer) {
        print("📦 [Schema] 执行 V2 迁移 (双紧急阈值)...")
        
        let context = ModelContext(modelContainer)
        let fetchDescriptor = FetchDescriptor<QuadrantTask>()
        if let tasks = try? context.fetch(fetchDescriptor) {
            for task in tasks {
                // 将现有的 urgentThresholdDays 拷贝到 originalUrgentThresholdDays
                if task.originalUrgentThresholdDays == nil && task.urgentThresholdDays != nil {
                    task.originalUrgentThresholdDays = task.urgentThresholdDays
                }
            }
            try? context.save()
            print("📦 [Schema] V2 迁移完成，已处理 \(tasks.count) 个任务")
        } else {
            print("📦 [Schema] V2 迁移：无法获取任务数据")
        }
    }
    
    /// 迁移到 Schema V3
    /// - 新增 originalImportance：将现有 importance 拷贝为原始值
    private func migrateSchemaToV3(modelContainer: ModelContainer) {
        print("📦 [Schema] 执行 V3 迁移 (重要性双轨追踪)...")
        
        let context = ModelContext(modelContainer)
        let fetchDescriptor = FetchDescriptor<QuadrantTask>()
        if let tasks = try? context.fetch(fetchDescriptor) {
            for task in tasks {
                if task.originalImportance == nil {
                    task.originalImportance = task.importance
                }
            }
            try? context.save()
            print("📦 [Schema] V3 迁移完成，已处理 \(tasks.count) 个任务")
        } else {
            print("📦 [Schema] V3 迁移：无法获取任务数据")
        }
    }
    
    // MARK: - 版本信息存储
    
    /// 保存当前版本信息到 UserDefaults
    private func saveCurrentVersionInfo() {
        defaults.set(currentAppVersion, forKey: Keys.lastAppVersion)
        defaults.set(currentBuildNumber, forKey: Keys.lastBuildNumber)
        defaults.set(Self.currentSchemaVersion, forKey: Keys.schemaVersion)
        defaults.synchronize()
        
        print("💾 [AppLifecycle] 版本信息已保存")
    }
    
    // MARK: - 辅助方法
    
    /// 重置所有版本追踪信息（仅用于调试）
    func resetVersionTracking() {
        defaults.removeObject(forKey: Keys.lastAppVersion)
        defaults.removeObject(forKey: Keys.lastBuildNumber)
        defaults.removeObject(forKey: Keys.schemaVersion)
        defaults.synchronize()
        print("🔄 [AppLifecycle] 版本追踪信息已重置")
    }
}
