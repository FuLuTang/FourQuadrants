import Foundation
import SwiftData
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacStickyConfigurationTests {
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
}
