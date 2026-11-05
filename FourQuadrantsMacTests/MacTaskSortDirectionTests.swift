import Foundation
import SwiftData
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacTaskSortDirectionTests {
    @Test func descendingReversesNameOrder() throws {
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext)
        let tasks = ["B", "C", "A"].map { QuadrantTask(title: $0, importance: .normal) }

        let ascending = store.sortTasks(tasks, by: .byName, direction: .ascending).map(\.title)
        let descending = store.sortTasks(tasks, by: .byName, direction: .descending).map(\.title)

        #expect(ascending == ["A", "B", "C"])
        #expect(descending == ["C", "B", "A"])
    }

    @Test func directionIsOnlyOfferedForSortMethodsThatSupportIt() {
        #expect(!TaskStore.TaskSortMethod.intelligence.supportsDirection)
        #expect(TaskStore.TaskSortMethod.byDueDate.supportsDirection)
        #expect(TaskStore.TaskSortMethod.byCreationDate.supportsDirection)
        #expect(TaskStore.TaskSortMethod.byName.supportsDirection)
    }
}
