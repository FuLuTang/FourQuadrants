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
            title: "工作便笺",
            source: .selectedTaskIDs([taskID]),
            paper: .blue,
            frame: MacStickyWindowFrame(x: 80, y: 420, width: 310, height: 360),
            isCollapsed: true,
            isVisible: true,
            isFloating: true,
            opacity: 0.82
        )

        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([MacStickyConfiguration].self, from: data)

        #expect(decoded == [original])
    }

    @Test func legacyConfigurationWithoutDetailsPreferenceUsesDefault() throws {
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
          "isFloating": true,
          "opacity": 0.78
        }]
        """
        let data = try #require(legacyJSON.data(using: .utf8))

        let decoded = try JSONDecoder().decode([MacStickyConfiguration].self, from: data)

        #expect(decoded == [MacStickyConfiguration(
            id: id,
            title: "旧便笺",
            source: .selectedTaskIDs([]),
            paper: .green,
            frame: MacStickyWindowFrame(x: 12, y: 34, width: 280, height: 320),
            isCollapsed: true,
            isVisible: false,
            isFloating: true,
            opacity: 0.78,
            showDetails: false
        )])
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
            MacStickyConfiguration(title: source.title, source: source)
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
            .notImportantAndNotUrgent: [neither.id],
            .completed: [recentlyCompleted.id, oldCompleted.id]
        ]

        for category in TaskCategory.allCases {
            let actual = coordinator.visibleTasks(from: .category(category), in: tasks, now: now)
            let expectedIDs = try #require(expected[category])
            #expect(Set(actual.map(\.id)) == expectedIDs)
        }
    }

    @Test func updatingConfigurationSettingsPersistsNormalizedValues() throws {
        let container = try PersistenceController.inMemoryContainer()
        let defaults = try makeDefaults()
        let coordinator = MacStickyCoordinator(
            container: container,
            taskStore: TaskStore(modelContext: container.mainContext),
            defaults: defaults
        )
        coordinator.createEmptyNote(title: "原始标题")
        let id = try #require(coordinator.configurations.first?.id)

        coordinator.updateConfiguration(id, title: "  新标题  ", paper: .pink, isFloating: true, opacity: 0.4)

        let updated = try #require(coordinator.configurations.first)
        #expect(updated.title == "新标题")
        #expect(updated.paper == .pink)
        #expect(updated.isFloating)
        #expect(updated.opacity == 0.65)
        let reloaded = try MacStickyCoordinator.loadConfigurations(from: defaults)
        #expect(reloaded == [updated])
    }

    @Test func removingConfigurationPersistsDeletion() throws {
        let container = try PersistenceController.inMemoryContainer()
        let defaults = try makeDefaults()
        let coordinator = MacStickyCoordinator(
            container: container,
            taskStore: TaskStore(modelContext: container.mainContext),
            defaults: defaults
        )
        coordinator.createEmptyNote(title: "保留")
        coordinator.createEmptyNote(title: "删除")
        let removedID = try #require(coordinator.configurations.first(where: { $0.title == "删除" })?.id)

        coordinator.removeConfiguration(id: removedID)

        #expect(coordinator.configurations.map(\.title) == ["保留"])
        #expect(try MacStickyCoordinator.loadConfigurations(from: defaults).map(\.title) == ["保留"])
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

        coordinator.createEmptyNote()

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
