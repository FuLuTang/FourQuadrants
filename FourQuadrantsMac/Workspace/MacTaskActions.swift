import Foundation

/// 工作区中任务行与看板共用的操作集合。由 `MacWorkspaceView` 构造一次，
/// 再整体传给下层视图，避免每一层都透传 `TaskStore` 与一串回调。
struct MacTaskActions {
    /// 单击任务时更新选中状态。
    let select: (QuadrantTask) -> Void
    /// 双击或菜单「编辑任务」时打开编辑表单。
    let edit: (QuadrantTask) -> Void
    /// 请求删除；真正删除前由工作区弹出确认。
    let delete: (QuadrantTask) -> Void
    /// 为任务所属象限创建 ToDo 便笺浮窗。
    let pin: (QuadrantTask) -> Void
    /// 切换完成状态。
    let toggleCompletion: (QuadrantTask) -> Void
    /// 移动到其他象限，返回是否成功。已完成任务不能移动，返回 false。
    let move: (QuadrantTask, TaskCategory) -> Bool
}
