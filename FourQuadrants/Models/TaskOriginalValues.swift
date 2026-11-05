import Foundation

/// 编辑任务保存时，计算应写入的「原始值」（即用户最后一次手动设置的重要性与自动紧急阈值）。
/// 只有用户实际改动了对应字段，才采用新值；没有改动则保持任务原有的原始值。
/// 拖动或菜单移动象限造成的变化不算手动设置，调用方不应把它们当作新值传入。
enum TaskOriginalValues {
    /// - Parameters:
    ///   - task: 编辑前的任务，用于比较当前值并取回原有原始值。
    ///   - newImportance: 表单中将保存的重要性。
    ///   - newThreshold: 表单中将保存的自动紧急阈值（自动紧急关闭时为 nil）。
    static func resolve(
        task: QuadrantTask,
        newImportance: ImportanceLevel,
        newThreshold: Int?
    ) -> (importance: ImportanceLevel?, urgentThresholdDays: Int?) {
        let importance = newImportance != task.importance ? newImportance : task.originalImportance
        let threshold = newThreshold != task.urgentThresholdDays ? newThreshold : task.originalUrgentThresholdDays
        return (importance, threshold)
    }
}
