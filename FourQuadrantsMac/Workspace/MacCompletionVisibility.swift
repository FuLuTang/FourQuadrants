import Foundation

/// A completed task stays visible in the quadrants for a few seconds so it can
/// be un-done. This finds when the view next has to re-evaluate that.
enum MacCompletionVisibility {
    /// Margin so the refresh lands just after the task stops being visible.
    static let expiryMargin: TimeInterval = 0.05

    /// The earliest moment after `snapshot` at which a completed task leaves
    /// the visible set, or nil when none is pending.
    static func nextExpiry(
        of tasks: [QuadrantTask],
        after snapshot: Date,
        visibleFor duration: TimeInterval = TaskStore.completionVisibilityDuration
    ) -> Date? {
        tasks
            .compactMap { $0.completedAt?.addingTimeInterval(duration + expiryMargin) }
            .filter { $0 > snapshot }
            .min()
    }
}
