import Foundation
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacCompletionVisibilityTests {
    @Test func noCompletedTasksMeansNoRefresh() {
        let open = QuadrantTask(title: "未完成", importance: .normal)
        #expect(MacCompletionVisibility.nextExpiry(of: [open], after: .now) == nil)
    }

    @Test func schedulesEarliestFutureExpiryOnly() {
        let snapshot = Date()
        let stale = QuadrantTask(title: "早已隐藏", importance: .normal)
        stale.completedAt = snapshot.addingTimeInterval(-60)
        let recent = QuadrantTask(title: "刚完成", importance: .normal)
        recent.completedAt = snapshot.addingTimeInterval(-1)
        let later = QuadrantTask(title: "稍后完成", importance: .normal)
        later.completedAt = snapshot.addingTimeInterval(1)

        let expiry = MacCompletionVisibility.nextExpiry(of: [stale, later, recent], after: snapshot, visibleFor: 3)
        #expect(expiry == recent.completedAt?.addingTimeInterval(3 + MacCompletionVisibility.expiryMargin))
        #expect(MacCompletionVisibility.nextExpiry(of: [stale], after: snapshot, visibleFor: 3) == nil)
    }
}
