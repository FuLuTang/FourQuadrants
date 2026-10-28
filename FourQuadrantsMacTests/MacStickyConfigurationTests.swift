import AppKit
import Foundation
import SwiftData
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacStickyConfigurationTests {
    @Test func collapsingPreservesHorizontalGeometryAndAnchorsToTopEdge() {
        let expanded = MacStickyWindowFrame(x: 80, y: 120, width: 310, height: 360)

        let compact = expanded.collapsed(to: 30)

        #expect(compact.x == expanded.x)
        #expect(compact.width == expanded.width)
        #expect(compact.y + compact.height == expanded.y + expanded.height)
        #expect(compact.height == 30)
    }

    @Test func configurationEncodingPreservesSourceAndWindowPreferences() throws {
        let taskID = UUID()
        let original = MacStickyConfiguration(
            source: .selectedTaskIDs([taskID]),
            frame: MacStickyWindowFrame(x: 80, y: 420, width: 310, height: 360),
            isCollapsed: true,
            isVisible: true,
            isFloating: false,
            showDetails: true
        )

        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([MacStickyConfiguration].self, from: data)

        #expect(decoded == [original])
    }

    @Test func legacyConfigurationIgnoresRemovedFieldsAndKeepsPreferences() throws {
        let id = UUID()
        let legacyJSON = """
        [{
          "id": "\(id.uuidString)",
          "title": "旧便笺",
          "source": { "kind": "selectedTaskIDs", "taskIDs": [] },
          "paper": "green",
          "frame": { "x": 12, "y": 34, "width": 280, "height": 320 },
          "isCollapsed": true,
          "isVisible": false,
          "isFloating": false,
          "opacity": 0.78
        }]
        """
        let data = try #require(legacyJSON.data(using: .utf8))

        let decoded = try JSONDecoder().decode([MacStickyConfiguration].self, from: data)

        #expect(decoded == [MacStickyConfiguration(
            id: id,
            source: .selectedTaskIDs([]),
            frame: MacStickyWindowFrame(x: 12, y: 34, width: 280, height: 320),
            isCollapsed: true,
            isVisible: false,
            isFloating: false,
            showDetails: false
        )])
        #expect(decoded.first?.displayTitle == "智能排列")
    }

    @Test func minimalLegacyConfigurationFillsMissingFieldsWithDefaults() throws {
        let id = UUID()
        let data = try #require("[{\"id\": \"\(id.uuidString)\"}]".data(using: .utf8))

        let decoded = try JSONDecoder().decode([MacStickyConfiguration].self, from: data)

        #expect(decoded == [MacStickyConfiguration(id: id)])
        #expect(decoded.first?.isFloating == true)
    }

    @Test func newConfigurationFloatsByDefault() {
        #expect(MacStickyConfiguration().isFloating)
    }

    @Test func collapsedWindowFrameUsesTitleBarHeightAndKeepsTopEdge() {
        let expanded = MacStickyWindowFrame(x: 100, y: 200, width: 220, height: 260)

        let window = expanded.windowFrame(isCollapsed: true)

        #expect(window.height == MacStickyLayout.titleBarHeight)
        #expect(window.x == 100 && window.width == 220)
        #expect(window.y + window.height == expanded.y + expanded.height)
        #expect(expanded.windowFrame(isCollapsed: false) == expanded)
    }

    @Test func expandingAfterDraggingCollapsedWindowUsesMovedTopEdge() {
        let expanded = MacStickyWindowFrame(x: 100, y: 200, width: 220, height: 260)
        let collapsedWindow = expanded.windowFrame(isCollapsed: true)
        // 收起态窗口整体向右 50、向下 80。
        let dragged = MacStickyWindowFrame(x: collapsedWindow.x + 50, y: collapsedWindow.y - 80, width: collapsedWindow.width, height: collapsedWindow.height)

        let updated = expanded.updated(fromWindow: dragged, isCollapsed: true)

        #expect(updated.x == 150)
        #expect(updated.width == 220 && updated.height == 260)
        #expect(updated.y + updated.height == expanded.y + expanded.height - 80)
        #expect(updated.windowFrame(isCollapsed: true) == dragged)
    }

    @Test func expandedWindowFrameIsRecordedAsIs() {
        let expanded = MacStickyWindowFrame(x: 100, y: 200, width: 220, height: 260)
        let resized = MacStickyWindowFrame(x: 90, y: 180, width: 300, height: 280)

        #expect(expanded.updated(fromWindow: resized, isCollapsed: false) == resized)
    }

    @Test func widenedExpandsToTheRightKeepingLeftEdge() {
        let narrow = MacStickyWindowFrame(x: 100, y: 200, width: 220, height: 260)

        let widened = narrow.widened(toAtLeast: MacStickyLayout.combinedMinimumWidth)

        #expect(widened.x == 100)
        #expect(widened.width == MacStickyLayout.combinedMinimumWidth)
        #expect(widened.y == 200 && widened.height == 260)
        let wide = MacStickyWindowFrame(x: 0, y: 0, width: 500, height: 300)
        #expect(wide.widened(toAtLeast: MacStickyLayout.combinedMinimumWidth) == wide)
    }

    @Test func collapsingUpdatesConfigurationImmediatelyWithoutChangingExpandedFrame() throws {
        let container = try PersistenceController.inMemoryContainer()
        let coordinator = MacStickyCoordinator(container: container, taskStore: TaskStore(modelContext: container.mainContext), defaults: try makeDefaults())
        let original = MacStickyWindowFrame(x: 100, y: 200, width: 220, height: 260)
        let id = coordinator.createNote(source: .category(.importantAndUrgent), frame: original)

        coordinator.setCollapsed(true, id: id)
        coordinator.setCollapsed(false, id: id)
        coordinator.setCollapsed(true, id: id)

        // 动画只影响窗口 frame，配置立即是最新状态，展开态框架不被中间 frame 污染。
        #expect(coordinator.configurations.first?.isCollapsed == true)
        #expect(coordinator.configurations.first?.frame == original)
        coordinator.closeAllWindows()
    }

    @Test func switchingToCombinedWidensNarrowNoteIncludingCollapsedOnes() throws {
        let container = try PersistenceController.inMemoryContainer()
        let coordinator = MacStickyCoordinator(container: container, taskStore: TaskStore(modelContext: container.mainContext), defaults: try makeDefaults())
        let id = coordinator.createNote(source: .category(.importantAndUrgent), frame: MacStickyWindowFrame(x: 100, y: 200, width: 220, height: 260))
        coordinator.setCollapsed(true, id: id)

        coordinator.setSource(.combined, for: id)

        let frame = try #require(coordinator.configurations.first?.frame)
        #expect(frame.x == 100)
        #expect(frame.width == MacStickyLayout.combinedMinimumWidth)
        #expect(coordinator.configurations.first?.isCollapsed == true)
        coordinator.closeAllWindows()
    }

    @Test func combinedDefaultSizeIsWiderThanSingleQuadrant() {
        #expect(MacStickyLayout.defaultSize(for: .combined) == (360, 300))
        #expect(MacStickyLayout.defaultSize(for: .smart) == (220, 260))
        #expect(MacStickyLayout.defaultSize(for: .category(.importantAndUrgent)) == (220, 260))
    }

    @Test func frameChangesAreDebouncedAndFlushedOnDemand() throws {
        let container = try PersistenceController.inMemoryContainer()
        let defaults = try makeDefaults()
        let coordinator = MacStickyCoordinator(container: container, taskStore: TaskStore(modelContext: container.mainContext), defaults: defaults, saveDebounce: 60)
        let id = coordinator.createNote(source: .smart, frame: MacStickyWindowFrame(x: 10, y: 20, width: 220, height: 260))

        for step in 1...20 {
            coordinator.recordWindowFrame(NSRect(x: 10 + Double(step), y: 20, width: 220, height: 260), id: id)
        }

        #expect(coordinator.configurations.first?.frame.x == 30)
        #expect(try MacStickyCoordinator.loadConfigurations(from: defaults).first?.frame.x == 10)

        coordinator.flushPendingChanges()

        #expect(try MacStickyCoordinator.loadConfigurations(from: defaults).first?.frame.x == 30)
        coordinator.closeAllWindows()
    }

    @Test func debouncedFrameChangesEventuallyPersistWithoutFlush() async throws {
        let container = try PersistenceController.inMemoryContainer()
        let defaults = try makeDefaults()
        let coordinator = MacStickyCoordinator(container: container, taskStore: TaskStore(modelContext: container.mainContext), defaults: defaults, saveDebounce: 0.05)
        let id = coordinator.createNote(source: .smart, frame: MacStickyWindowFrame(x: 10, y: 20, width: 220, height: 260))

        coordinator.recordWindowFrame(NSRect(x: 77, y: 20, width: 220, height: 260), id: id)
        try await Task.sleep(for: .milliseconds(400))

        #expect(try MacStickyCoordinator.loadConfigurations(from: defaults).first?.frame.x == 77)
        coordinator.closeAllWindows()
    }

    @Test func allSixCategoryConfigurationsRoundTripThroughPersistenceCodec() throws {
        let sources: [MacStickySource] = [
            .category(.importantAndUrgent),
            .category(.importantButNotUrgent),
            .category(.urgentButNotImportant),
            .category(.notImportantAndNotUrgent),
            .combined,
            .smart
        ]
        let configurations = sources.map { source in
            MacStickyConfiguration(source: source)
        }

        let data = try MacStickyCoordinator.encode(configurations)
        let decoded = try JSONDecoder().decode([MacStickyConfiguration].self, from: data)

        #expect(decoded == configurations)
        #expect(decoded.map(\.source) == sources)
    }

    @Test func categoryNotesUseSharedTaskStoreFiltering() throws {
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext)
        let defaults = try makeDefaults()
        let coordinator = MacStickyCoordinator(container: container, taskStore: store, defaults: defaults)
        let recentCompletion = QuadrantTask(title: "最近完成", completedAt: .now)
        let oldCompletion = QuadrantTask(title: "较早完成", completedAt: Date(timeIntervalSinceNow: -10))
        let unfinished = QuadrantTask(title: "待处理")
        let tasks = [recentCompletion, oldCompletion, unfinished]
        tasks.forEach { container.mainContext.insert($0) }

        let now = Date()
        let expected = store.filteredTasks(tasks, in: .all, now: now).map(\.id)
        let actual = coordinator.visibleTasks(from: .category(.all), in: tasks, now: now).map(\.id)

        #expect(actual == expected)
        #expect(actual.contains(recentCompletion.id))
        #expect(!actual.contains(oldCompletion.id))
    }

    @Test func categoryNotesReturnTheMatchingVisibleTasksForEveryCategory() throws {
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext)
        let coordinator = MacStickyCoordinator(container: container, taskStore: store, defaults: try makeDefaults())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let importantAndUrgent = makeTask("重要紧急", important: true, urgent: true)
        let important = makeTask("重要", important: true, urgent: false)
        let urgent = makeTask("紧急", important: false, urgent: true)
        let neither = makeTask("普通", important: false, urgent: false)
        let recentlyCompleted = QuadrantTask(title: "近期完成", completedAt: now.addingTimeInterval(-2))
        let oldCompleted = QuadrantTask(title: "较早完成", completedAt: now.addingTimeInterval(-10))
        let tasks = [importantAndUrgent, important, urgent, neither, recentlyCompleted, oldCompleted]
        tasks.forEach { container.mainContext.insert($0) }
        let expected: [TaskCategory: Set<UUID>] = [
            .all: Set([importantAndUrgent, important, urgent, neither, recentlyCompleted].map(\.id)),
            .importantAndUrgent: [importantAndUrgent.id],
            .importantButNotUrgent: [important.id],
            .urgentButNotImportant: [urgent.id],
            .notImportantAndNotUrgent: [neither.id, recentlyCompleted.id],
            .completed: [recentlyCompleted.id, oldCompleted.id]
        ]

        for category in TaskCategory.allCases {
            let actual = coordinator.visibleTasks(from: .category(category), in: tasks, now: now)
            let expectedIDs = try #require(expected[category])
            #expect(Set(actual.map(\.id)) == expectedIDs)
        }
    }

    @Test func closingAllWindowsKeepsConfigurationVisibility() throws {
        let container = try PersistenceController.inMemoryContainer()
        let defaults = try makeDefaults()
        let coordinator = MacStickyCoordinator(
            container: container,
            taskStore: TaskStore(modelContext: container.mainContext),
            defaults: defaults
        )
        let id = coordinator.createNote(source: .smart)
        coordinator.showWindow(for: id)
        #expect(coordinator.configurations.first?.isVisible == true)

        coordinator.closeAllWindows()

        #expect(coordinator.configurations.first?.isVisible == true)
        #expect(try MacStickyCoordinator.loadConfigurations(from: defaults).first?.isVisible == true)
    }

    @Test func removingConfigurationPersistsDeletion() throws {
        let container = try PersistenceController.inMemoryContainer()
        let defaults = try makeDefaults()
        let coordinator = MacStickyCoordinator(
            container: container,
            taskStore: TaskStore(modelContext: container.mainContext),
            defaults: defaults
        )
        let keptID = coordinator.createNote(source: .smart)
        let removedID = coordinator.createNote(source: .combined)

        coordinator.removeConfiguration(id: removedID)

        #expect(coordinator.configurations.map(\.id) == [keptID])
        #expect(try MacStickyCoordinator.loadConfigurations(from: defaults).map(\.id) == [keptID])
    }

    @Test func unreadableConfigurationDataIsPreservedWhenEditing() throws {
        let container = try PersistenceController.inMemoryContainer()
        let defaults = try makeDefaults()
        let originalData = Data([0x46, 0x51, 0x01, 0xFF])
        defaults.set(originalData, forKey: MacStickyCoordinator.persistenceKey)
        let coordinator = MacStickyCoordinator(
            container: container,
            taskStore: TaskStore(modelContext: container.mainContext),
            defaults: defaults
        )

        coordinator.createNote(source: .smart)

        #expect(defaults.data(forKey: MacStickyCoordinator.persistenceKey) == originalData)
        #expect(coordinator.persistenceError != nil)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "FourQuadrantsMacTests.Stickies.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeTask(_ title: String, important: Bool, urgent: Bool) -> QuadrantTask {
        let task = QuadrantTask(title: title, importance: important ? .high : .normal)
        task.isUrgent = urgent
        return task
    }
}
