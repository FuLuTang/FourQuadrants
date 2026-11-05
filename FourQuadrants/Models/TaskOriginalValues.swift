import Foundation

/// 编辑任务保存时，计算应写入的「原始值」（即用户最后一次手动设置的重要性与原始紧急阈值）。
/// - 重要性：与当前值不同才采用新值，否则保持任务原有的原始重要性。
/// - 紧急阈值：只有新阈值非 nil 且与当前阈值不同时才采用新值；
///   新阈值为 nil（删除截止日期或关闭自动紧急）或与当前相同，一律保持任务原有的原始阈值。
///   关闭或删除只是让表单不能再编辑阈值，不会清空原始阈值。
/// 拖动或菜单移动象限造成的变化不算手动设置，调用方不应把它们当作新值传入。
enum TaskOriginalValues {
    /// - Parameters:
    ///   - task: 编辑前的任务，用于比较当前值并取回原有原始值。
    ///   - newImportance: 表单中将保存的重要性。
    ///   - newThreshold: 表单中将保存的自动紧急阈值（截止日期删除或自动紧急关闭时为 nil）。
    static func resolve(
        task: QuadrantTask,
        newImportance: ImportanceLevel,
        newThreshold: Int?
    ) -> (importance: ImportanceLevel?, urgentThresholdDays: Int?) {
        let importance = newImportance != task.importance ? newImportance : task.originalImportance
        let threshold: Int?
        if let newThreshold, newThreshold != task.urgentThresholdDays {
            threshold = newThreshold
        } else {
            threshold = task.originalUrgentThresholdDays
        }
        return (importance, threshold)
    }
}
