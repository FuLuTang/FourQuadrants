import CoreGraphics
import Foundation

/// Dimensions of the daily timeline; shared by the grid, the blocks and the gestures.
enum MacDailyTimelineMetrics {
    static let hourHeight: CGFloat = 64
    static let timelineHeight: CGFloat = CGFloat(MacDailyTimeMath.minuteCount / 60) * hourHeight
    static let timeColumnWidth: CGFloat = 72
    static let timeLabelGap: CGFloat = 12
    static let timeLabelOffset: CGFloat = -8
    static let scrollTrailingPadding: CGFloat = 18

    /// Space right of the hour column that blocks may not use.
    static let blocksTrailingInset: CGFloat = 28
    static let minBlocksWidth: CGFloat = 220
    static let blocksLeadingGap: CGFloat = 12
    static let blockWidthInset: CGFloat = 3
    static let minBlockWidth: CGFloat = 48
    static let minBlockHeight: CGFloat = 22
    static let blockCornerRadius: CGFloat = 7
    /// Blocks at least this long also show their time range.
    static let timeRangeMinDuration: TimeInterval = 35 * 60

    /// `DailyTaskLayout` (shared with iOS) shifts frames down by this inset.
    static let sharedLayoutTopInset: CGFloat = 10

    static let resizeHitZoneHeight: CGFloat = 9
    static let resizeHitZoneWidth: CGFloat = 42
    static let resizeGripInset: CGFloat = 3
    static let moveGestureMinimumDistance: CGFloat = 4
    static let resizeGestureMinimumDistance: CGFloat = 2

    /// Vertical position of the empty-state message, in hours from midnight.
    static let emptyStateHour: CGFloat = 9.5
    /// Hour scrolled to on days other than today.
    static let defaultScrollHour = 8

    /// Drags are measured in this space so a moving block cannot skew its own gesture.
    static let coordinateSpace = "macDailyTimeline"

    static func hourID(_ hour: Int) -> String { "hour-\(hour)" }
}
