import SwiftUI

/// 已完成任务在原位置保留 `TaskStore.completionVisibilityDuration` 秒（便于撤销），之后才消失。
/// 这里只负责 iOS 端的到期时刻计算与刷新，可见性判断仍由 `TaskStore.filteredTasks` 完成。
/// 逻辑与 macOS 端 `MacCompletionVisibility` 保持一致；iOS 视图目录不属于 Mac target，两者互不冲突。
enum CompletionVisibility {
    /// 刷新时刻略晚于任务消失的时刻，避免边界上仍然可见。
    static let expiryMargin: TimeInterval = 0.05

    /// `snapshot` 之后，最早一个已完成任务离开可见集合的时刻；没有待到期任务时返回 nil。
    static func nextExpiry(of tasks: [QuadrantTask], after snapshot: Date) -> Date? {
        tasks
            .compactMap { $0.completedAt?.addingTimeInterval(TaskStore.completionVisibilityDuration + expiryMargin) }
            .filter { $0 > snapshot }
            .min()
    }
}

extension View {
    /// 在最近一个已完成任务到期时，把 `refreshDate` 更新一次，使视图重新过滤。不使用每秒定时器。
    func refreshingAtCompletionExpiry(of tasks: [QuadrantTask], refreshDate: Binding<Date>) -> some View {
        modifier(CompletionExpiryRefreshModifier(tasks: tasks, refreshDate: refreshDate))
    }
}

private struct CompletionExpiryRefreshModifier: ViewModifier {
    let tasks: [QuadrantTask]
    @Binding var refreshDate: Date

    private var expiry: Date? {
        CompletionVisibility.nextExpiry(of: tasks, after: refreshDate)
    }

    func body(content: Content) -> some View {
        // id 随到期时刻变化而重新启动任务；到期后 refreshDate 前移，下一次到期时刻随之更新。
        content.task(id: expiry) {
            guard let expiry else { return }
            let delay = expiry.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            refreshDate = Date()
        }
    }
}
