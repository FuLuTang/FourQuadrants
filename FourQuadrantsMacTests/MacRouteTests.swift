import Foundation
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacRouteTests {
    @Test func requestsWaitForTheWorkspaceWithoutAWindow() {
        let runtime = MacApplicationRuntime()
        let id = UUID()

        runtime.requestShowTask(id)

        #expect(runtime.pendingRoute == .showTask(id))
        #expect(runtime.consumePendingRoute() == .showTask(id))
        #expect(runtime.pendingRoute == nil)
        #expect(runtime.consumePendingRoute() == nil)
    }

    @Test func latestRequestWinsAndOpensTheMainWindow() {
        let runtime = MacApplicationRuntime()
        var openCount = 0
        runtime.registerMainWindowOpener { openCount += 1 }

        runtime.requestNewTask()
        runtime.requestShowTask(UUID())
        let id = UUID()
        runtime.requestShowTask(id)

        #expect(openCount == 3)
        #expect(runtime.consumePendingRoute() == .showTask(id))
    }

    @Test func taskURLUsesTheSameRoute() {
        let runtime = MacApplicationRuntime()
        let id = UUID()

        #expect(runtime.handle(url: URL(string: "fourquadrants://task/\(id.uuidString)")!))
        #expect(runtime.pendingRoute == .showTask(id))
        runtime.consumePendingRoute()

        #expect(!runtime.handle(url: URL(string: "fourquadrants://task/not-a-uuid")!))
        #expect(!runtime.handle(url: URL(string: "https://example.com/task/\(id.uuidString)")!))
        #expect(runtime.pendingRoute == nil)
    }

    @Test func stickyOpenTaskRoutesThroughRuntime() throws {
        let runtime = MacApplicationRuntime()
        let stickies = try #require(runtime.stickies)
        let id = UUID()

        stickies.openTaskInMainApp(id)

        #expect(runtime.consumePendingRoute() == .showTask(id))
    }

    @Test func quadrantListKeepsDisplayOrder() {
        #expect(TaskCategory.allQuadrants == [
            .importantAndUrgent, .urgentButNotImportant, .importantButNotUrgent, .notImportantAndNotUrgent
        ])
    }
}
