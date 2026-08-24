import Foundation
import SwiftData
import Testing
@testable import FourQuadrants

struct FourQuadrantsTests {
    @Test @MainActor func taskStoreCRUDCompletionAndTimestamps() throws {
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext)

        #expect(store.addTask(title: "Write tests", importance: .high, isUrgent: false, isTop: false))
        var tasks = try container.mainContext.fetch(FetchDescriptor<QuadrantTask>())
        #expect(tasks.count == 1)
        let task = try #require(tasks.first)
        let originalUpdatedAt = task.updatedAt

        #expect(store.toggleTask(task))
        #expect(task.completedAt != nil)
        #expect(task.isCompleted)

        #expect(store.updateTask(task, title: "Write persistence tests", importance: .normal, isUrgent: true, isTop: true, dueAt: nil))
        #expect(task.title == "Write persistence tests")
        #expect(task.updatedAt >= originalUpdatedAt)

        #expect(store.removeTask(task))
        tasks = try container.mainContext.fetch(FetchDescriptor<QuadrantTask>())
        #expect(tasks.isEmpty)
    }

    @Test @MainActor func taskMoveUsesProductionRules() throws {
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext)
        let task = QuadrantTask(title: "Move me", importance: .normal, isUrgent: false, isTop: false)
        container.mainContext.insert(task)
        try container.mainContext.save()

        #expect(store.moveTask(task, to: .importantAndUrgent))
        #expect(task.isImportantQuadrant)
        #expect(task.isUrgent)
        #expect(store.moveTask(task, to: .notImportantAndNotUrgent))
        #expect(!task.isImportantQuadrant)
        #expect(!task.isUrgent)
    }

    @Test @MainActor func dailyTaskRelationshipNullifiesWhenQuadrantTaskIsDeleted() throws {
        let container = try PersistenceController.inMemoryContainer()
        let context = container.mainContext
        let quadrant = QuadrantTask(title: "Parent")
        let daily = DailyTask(title: "Plan", quadrantTask: quadrant)
        context.insert(quadrant)
        context.insert(daily)
        try context.save()
        #expect(daily.quadrantTask?.id == quadrant.id)

        context.delete(quadrant)
        try context.save()
        let dailyTasks = try context.fetch(FetchDescriptor<DailyTask>())
        #expect(dailyTasks.count == 1)
        #expect(dailyTasks[0].quadrantTask == nil)
    }

    @Test @MainActor func dailyTaskPersistencePredicateUsesCompletedAt() throws {
        let container = try PersistenceController.inMemoryContainer()
        let context = container.mainContext
        let now = Date()
        let active = DailyTask(title: "Active", startAt: now)
        let completed = DailyTask(title: "Completed", startAt: now, completedAt: now)
        context.insert(active)
        context.insert(completed)
        try context.save()

        let predicate = #Predicate<DailyTask> { task in
            task.completedAt == nil
        }
        let tasks = try context.fetch(FetchDescriptor<DailyTask>(predicate: predicate))

        #expect(tasks.map(\.id) == [active.id])
    }

    @Test @MainActor func emptyInMemoryStoreRemainsEmpty() throws {
        let container = try PersistenceController.inMemoryContainer()
        let tasks = try container.mainContext.fetch(FetchDescriptor<QuadrantTask>())
        #expect(tasks.isEmpty)
    }

    @Test @MainActor func diskStorePersistsAndDoesNotSeedDemoTasks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FourQuadrantsTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent(PersistenceController.storeFilename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = ModelConfiguration(
            "FourQuadrants-v1",
            schema: Schema(versionedSchema: AppSchemaV2.self),
            url: storeURL,
            cloudKitDatabase: .none
        )
        let firstContainer = try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV2.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
        let firstStore = TaskStore(modelContext: firstContainer.mainContext)
        #expect(try firstContainer.mainContext.fetch(FetchDescriptor<QuadrantTask>()).isEmpty)
        #expect(firstStore.addTask(title: "Persist me", importance: .normal, isUrgent: false, isTop: false))

        let reopenedContainer = try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV2.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
        let reopenedTasks = try reopenedContainer.mainContext.fetch(FetchDescriptor<QuadrantTask>())
        #expect(reopenedTasks.map(\.title) == ["Persist me"])
    }

    @Test @MainActor func failedSaveRollsBackAndReportsError() throws {
        enum SaveFailure: Error { case expected }
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext, saveOperation: { throw SaveFailure.expected })

        #expect(!store.addTask(title: "Will fail", importance: .normal, isUrgent: false, isTop: false))
        #expect(store.lastErrorMessage != nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<QuadrantTask>()).isEmpty)
    }

    @Test @MainActor func dailyTaskLayoutCommitsOnceAndCancellationRestoresSnapshot() throws {
        let container = try PersistenceController.inMemoryContainer()
        let context = container.mainContext
        let originalStartAt = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let originalDuration: TimeInterval = 3_600
        let task = DailyTask(title: "Plan", startAt: originalStartAt, duration: originalDuration)
        context.insert(task)
        try context.save()

        let store = TaskStore(modelContext: context)
        let previewStartAt = originalStartAt.addingTimeInterval(1_800)
        store.previewDailyTaskLayout(task, startAt: previewStartAt, duration: 5_400)
        #expect(task.startAt == previewStartAt)
        #expect(task.duration == 5_400)

        store.restoreDailyTaskLayout(task, startAt: originalStartAt, duration: originalDuration)
        #expect(task.startAt == originalStartAt)
        #expect(task.duration == originalDuration)

        store.previewDailyTaskLayout(task, startAt: previewStartAt, duration: 5_400)
        #expect(store.commitDailyTaskLayout(task))
        #expect(task.updatedAt >= task.createdAt)

        enum SaveFailure: Error { case expected }
        let failingStore = TaskStore(modelContext: context, saveOperation: { throw SaveFailure.expected })
        failingStore.previewDailyTaskLayout(task, startAt: originalStartAt, duration: originalDuration)
        #expect(!failingStore.commitDailyTaskLayout(task))
        #expect(task.startAt == previewStartAt)
        #expect(task.duration == 5_400)
    }

    @Test @MainActor func containerFailureEntersRecoveryWithoutFallbackStore() {
        let controller = AppDataController(persistence: PersistenceController(appGroupIdentifier: "group.invalid.FourQuadrants"))
        if case .recoveryRequired = controller.state {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "An invalid App Group must not create a fallback store.")
        }
    }

    @Test @MainActor func microsoftTodoLinksRemainIndependentFromTasks() throws {
        let container = try PersistenceController.inMemoryContainer()
        let context = container.mainContext
        let profile = MicrosoftTodoSyncProfile(
            accountIdentifier: "account-a",
            displayName: "Test Account",
            defaultListIdentifier: "default-list"
        )
        let task = QuadrantTask(title: "Local only")
        context.insert(profile)
        context.insert(task)
        context.insert(MicrosoftTodoTaskLink(
            profileIdentifier: profile.id,
            localTaskIdentifier: task.id,
            state: .localOnly
        ))
        try context.save()

        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>())
        #expect(links.count == 1)
        #expect(links[0].localTaskIdentifier == task.id)
        #expect(task.notes == nil)
    }

    @Test func microsoftTodoDeltaDecodingAndPayloadMapping() throws {
        let response = """
        {
          "value": [
            {
              "id": "task/with+reserved=characters",
              "@odata.etag": "W/\\\"etag-1\\\"",
              "title": "Remote task",
              "body": { "content": "Notes" },
              "importance": "high",
              "status": "completed",
              "createdDateTime": "2026-08-16T09:00:00Z",
              "lastModifiedDateTime": "2026-08-16T10:00:00Z",
              "dueDateTime": { "dateTime": "2026-08-17T09:00:00Z" },
              "completedDateTime": { "dateTime": "2026-08-16T10:00:00Z" },
              "extensions": [
                {
                  "extensionName": "com.fulu.FourQuadrants.taskMetadata",
                  "schemaVersion": 1,
                  "localTaskIdentifier": "26B2D16B-32B6-4928-B0A7-1D5B5FC8A427",
                  "manualIsUrgent": true,
                  "hasUrgentThresholdDays": true,
                  "urgentThresholdDays": 3,
                  "hasOriginalUrgentThresholdDays": true,
                  "originalUrgentThresholdDays": 5,
                  "hasOriginalImportance": true,
                  "originalImportance": "normal",
                  "isTop": true
                }
              ]
            }
          ],
          "@odata.deltaLink": "https://graph.microsoft.com/v1.0/opaque-delta-link"
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder().decode(MicrosoftGraphDeltaPage<MicrosoftTodoTask>.self, from: response)
        #expect(page.value.count == 1)
        #expect(page.value[0].id == "task/with+reserved=characters")
        #expect(page.value[0].eTag == "W/\"etag-1\"")
        #expect(page.deltaLink?.contains("opaque-delta-link") == true)
        let metadata = try #require(page.value[0].fourQuadrantsMetadata)
        #expect(metadata.localTaskIdentifier == "26B2D16B-32B6-4928-B0A7-1D5B5FC8A427")
        #expect(metadata.manualIsUrgent == true)
        #expect(metadata.isTop == true)

        let payload = MicrosoftTodoTaskPayload(
            title: "Local task",
            body: .init(content: "Local notes"),
            importance: "high",
            status: "completed",
            dueDateTime: .init(dateTime: "2026-08-17T09:00:00Z"),
            extensions: nil
        )
        let encoded = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        let body = try #require(object?["body"] as? [String: String])
        #expect(body["content"] == "Local notes")
        #expect(body["contentType"] == "text")
        #expect(object?["importance"] as? String == "high")
        #expect(object?["status"] as? String == "completed")
        #expect(object?["extensions"] == nil)

        let localTask = QuadrantTask(
            id: UUID(uuidString: "26B2D16B-32B6-4928-B0A7-1D5B5FC8A427")!,
            title: "FourQuadrants metadata",
            importance: .normal,
            isUrgent: true,
            urgentThresholdDays: 3,
            originalUrgentThresholdDays: 5,
            originalImportance: .normal,
            isTop: true
        )
        let metadataPayload = MicrosoftTodoTaskMetadata(
            localTaskIdentifier: localTask.id.uuidString,
            manualIsUrgent: localTask.manualIsUrgent,
            urgentThresholdDays: localTask.urgentThresholdDays,
            originalUrgentThresholdDays: localTask.originalUrgentThresholdDays,
            originalImportance: localTask.originalImportance?.rawValue,
            isTop: localTask.isTop
        )
        let encodedMetadata = try JSONEncoder().encode(metadataPayload)
        let metadataObject = try #require(JSONSerialization.jsonObject(with: encodedMetadata) as? [String: Any])
        #expect(metadataObject["@odata.type"] as? String == "microsoft.graph.openTypeExtension")
        #expect(metadataObject["extensionName"] as? String == MicrosoftTodoTaskMetadata.extensionName)
        #expect(metadataObject["manualIsUrgent"] as? Bool == true)
        #expect(metadataObject["hasUrgentThresholdDays"] as? Bool == true)
        #expect(metadataObject["isTop"] as? Bool == true)
    }
}
