import Foundation
import SwiftData
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacSharedTaskTests {
    @Test func callerCanReferenceNewTaskWithoutSearchingItsTitle() throws {
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext)
        let firstID = UUID()
        let secondID = UUID()
        #expect(store.addTask(id: firstID, title: "同名任务", importance: .normal, isUrgent: false, isTop: false))
        #expect(store.addTask(id: secondID, title: "同名任务", importance: .normal, isUrgent: false, isTop: false))
        let tasks = try container.mainContext.fetch(FetchDescriptor<QuadrantTask>())
        #expect(Set(tasks.map(\.id)) == [firstID, secondID])
    }

    @Test func taskMutationIsVisibleAcrossSurfacesAndPersists() throws {
        let container = try PersistenceController.inMemoryContainer()
        let session = AppDataController(container: container, configureSync: false)
        guard case .ready(let data) = session.state else {
            Issue.record("Expected a ready shared data session")
            return
        }
        #expect(data.taskStore.addTask(title: "同一任务", importance: .high, isUrgent: true, isTop: false))
        let mainWindowTask = try #require(container.mainContext.fetch(FetchDescriptor<QuadrantTask>()).first)
        let stickyTask = try #require(container.mainContext.fetch(FetchDescriptor<QuadrantTask>()).first)
        #expect(mainWindowTask === stickyTask)
        #expect(data.taskStore.toggleTask(stickyTask))
        #expect(mainWindowTask.isCompleted)

        let reader = ModelContext(container)
        let savedTask = try #require(reader.fetch(FetchDescriptor<QuadrantTask>()).first)
        #expect(savedTask.isCompleted)
        #expect(savedTask.id == mainWindowTask.id)
    }

    @Test func failedSaveRollsBackSharedTask() throws {
        enum SaveFailure: Error { case rejected }
        let container = try PersistenceController.inMemoryContainer()
        let task = QuadrantTask(title: "保留原任务", importance: .high)
        container.mainContext.insert(task)
        try container.mainContext.save()
        let store = TaskStore(modelContext: container.mainContext, saveOperation: { throw SaveFailure.rejected })
        #expect(!store.toggleTask(task))
        #expect(!task.isCompleted)
        #expect(store.lastErrorMessage != nil)
        let saved = try #require(ModelContext(container).fetch(FetchDescriptor<QuadrantTask>()).first)
        #expect(!saved.isCompleted)
    }

    @Test func movingBetweenQuadrantsKeepsIdentityAndPinnedState() throws {
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext)
        #expect(store.addTask(title: "移动任务", importance: .normal, isUrgent: false, isTop: true))
        let task = try #require(container.mainContext.fetch(FetchDescriptor<QuadrantTask>()).first)
        let originalID = task.id
        #expect(store.moveTask(task, to: .importantAndUrgent))
        #expect(task.category == .importantAndUrgent)
        #expect(task.id == originalID)
        #expect(task.isTop)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<QuadrantTask>()) == 1)
    }

    @Test func previewContainsEveryCoreVisualStateWithoutPersistentStore() throws {
        let container = try PersistenceController.inMemoryContainer()
        try MacPreviewData.populate(container.mainContext)
        let tasks = try container.mainContext.fetch(FetchDescriptor<QuadrantTask>())
        let blocks = try container.mainContext.fetch(FetchDescriptor<DailyTask>())
        #expect(tasks.count == 11)
        #expect(blocks.count == 5)
        for category in [TaskCategory.importantAndUrgent, .importantButNotUrgent, .urgentButNotImportant, .notImportantAndNotUrgent, .completed] {
            #expect(tasks.contains { $0.category == category })
        }
        #expect(blocks.contains { $0.quadrantTask != nil })
        #expect(blocks.contains { $0.quadrantTask == nil })
        let anotherContainer = try PersistenceController.inMemoryContainer()
        #expect(try anotherContainer.mainContext.fetchCount(FetchDescriptor<QuadrantTask>()) == 0)
    }
}
