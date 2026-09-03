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

        let calendar = Calendar.current
        let dueAtWithTime = calendar.date(bySettingHour: 17, minute: 45, second: 0, of: Date())!
        #expect(store.updateTask(
            task,
            title: "Write tests",
            importance: .high,
            isUrgent: false,
            isTop: false,
            dueAt: dueAtWithTime
        ))
        #expect(task.dueAt == calendar.startOfDay(for: dueAtWithTime))
        #expect(task.dueDateKey == TaskDueDate.key(for: dueAtWithTime))

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

    @Test @MainActor func pendingUploadKeepsLocalMoveUntilRemoteActuallyChanges() {
        let baseline = Date(timeIntervalSince1970: 1_000)
        let localMove = baseline.addingTimeInterval(5)

        #expect(SyncService.shouldKeepPendingLocalChange(
            linkState: .pendingUpload,
            localUpdatedAt: localMove,
            remoteModifiedAt: baseline.addingTimeInterval(10),
            lastSyncedRemoteModifiedAt: baseline,
            lastSyncedRemoteETag: "etag-1",
            remoteETag: "etag-1"
        ))

        #expect(!SyncService.shouldKeepPendingLocalChange(
            linkState: .pendingUpload,
            localUpdatedAt: localMove,
            remoteModifiedAt: baseline.addingTimeInterval(10),
            lastSyncedRemoteModifiedAt: baseline,
            lastSyncedRemoteETag: "etag-1",
            remoteETag: "etag-2"
        ))
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
            schema: Schema(versionedSchema: AppSchemaV3.self),
            url: storeURL,
            cloudKitDatabase: .none
        )
        let firstContainer = try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV3.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
        let firstStore = TaskStore(modelContext: firstContainer.mainContext)
        #expect(try firstContainer.mainContext.fetch(FetchDescriptor<QuadrantTask>()).isEmpty)
        #expect(firstStore.addTask(title: "Persist me", importance: .normal, isUrgent: false, isTop: false))

        let reopenedContainer = try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV3.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
        let reopenedTasks = try reopenedContainer.mainContext.fetch(FetchDescriptor<QuadrantTask>())
        #expect(reopenedTasks.map(\.title) == ["Persist me"])
    }

    @Test @MainActor func v2DiskStoreMigratesToV3WithTasksRelationshipsAndSyncLinks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FourQuadrantsV2Migration-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent(PersistenceController.storeFilename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let taskID = UUID()
        let profileID = UUID()
        let dueAt = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 19))!

        do {
            let v2Configuration = ModelConfiguration(
                "FourQuadrants-v1",
                schema: Schema(versionedSchema: AppSchemaV2.self),
                url: storeURL,
                cloudKitDatabase: .none
            )
            let v2Container = try ModelContainer(
                for: Schema(versionedSchema: AppSchemaV2.self),
                configurations: v2Configuration
            )
            let context = v2Container.mainContext
            let task = AppSchemaV2.QuadrantTask(
                id: taskID,
                title: "V2 task",
                notes: "Preserve me",
                dueAt: dueAt,
                importance: .high,
                manualIsUrgent: true,
                urgentThresholdDays: 7,
                isTop: true
            )
            let daily = AppSchemaV2.DailyTask(title: "V2 daily", quadrantTask: task)
            let profile = AppSchemaV2.MicrosoftTodoSyncProfile(
                id: profileID,
                accountIdentifier: "legacy-account",
                displayName: "Legacy Account",
                defaultListIdentifier: "Tasks",
                deltaLink: "legacy-delta"
            )
            let link = AppSchemaV2.MicrosoftTodoTaskLink(
                profileIdentifier: profileID,
                localTaskIdentifier: taskID,
                remoteTaskIdentifier: "legacy-remote",
                remoteETag: "legacy-etag",
                stateRawValue: MicrosoftTodoLinkState.linked.rawValue
            )
            context.insert(task)
            context.insert(daily)
            context.insert(profile)
            context.insert(link)
            try context.save()
        }

        let v3Configuration = ModelConfiguration(
            "FourQuadrants-v1",
            schema: Schema(versionedSchema: AppSchemaV3.self),
            url: storeURL,
            cloudKitDatabase: .none
        )
        let v3Container = try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV3.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: v3Configuration
        )
        let context = v3Container.mainContext

        let task = try #require(context.fetch(FetchDescriptor<QuadrantTask>()).first)
        #expect(task.id == taskID)
        #expect(task.title == "V2 task")
        #expect(task.notes == "Preserve me")
        #expect(task.dueDateKey == "2026-11-19")
        #expect(task.importance == .high)
        #expect(task.manualIsUrgent)
        #expect(task.urgentThresholdDays == 7)
        #expect(task.isTop)

        let daily = try #require(context.fetch(FetchDescriptor<DailyTask>()).first)
        #expect(daily.title == "V2 daily")
        #expect(daily.quadrantTask?.id == taskID)

        let profile = try #require(context.fetch(FetchDescriptor<MicrosoftTodoSyncProfile>()).first)
        #expect(profile.id == profileID)
        #expect(profile.accountIdentifier == "legacy-account")
        #expect(profile.defaultListIdentifier == "Tasks")
        #expect(profile.deltaLink == "legacy-delta")

        let link = try #require(context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>()).first)
        #expect(link.profileIdentifier == profileID)
        #expect(link.localTaskIdentifier == taskID)
        #expect(link.remoteTaskIdentifier == "legacy-remote")
        #expect(link.remoteETag == "legacy-etag")
        #expect(link.state == .linked)
        #expect(try context.fetch(FetchDescriptor<MicrosoftTodoSyncOperation>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MicrosoftTodoDeletionTombstone>()).isEmpty)
    }

    @Test @MainActor func failedSaveRollsBackAndReportsError() throws {
        enum SaveFailure: Error { case expected }
        let container = try PersistenceController.inMemoryContainer()
        let store = TaskStore(modelContext: container.mainContext, saveOperation: { throw SaveFailure.expected })

        #expect(!store.addTask(title: "Will fail", importance: .normal, isUrgent: false, isTop: false))
        #expect(store.lastErrorMessage != nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<QuadrantTask>()).isEmpty)
    }

    @Test @MainActor func taskAndOutboxCommitTogether() throws {
        let container = try PersistenceController.inMemoryContainer()
        let context = container.mainContext
        let profile = MicrosoftTodoSyncProfile(
            accountIdentifier: "account-a",
            displayName: "Account A",
            defaultListIdentifier: "Tasks"
        )
        context.insert(profile)
        try context.save()

        let store = TaskStore(modelContext: context)
        store.quadrantTaskMutationRecorder = { mutation in
            guard case let .upsert(taskID) = mutation else { return }
            let link = MicrosoftTodoTaskLink(profileIdentifier: profile.id, localTaskIdentifier: taskID)
            context.insert(link)
            context.insert(MicrosoftTodoSyncOperation(
                profileIdentifier: profile.id,
                localTaskIdentifier: taskID,
                operationKind: .create
            ))
        }

        #expect(store.addTask(title: "Queued", importance: .normal, isUrgent: false, isTop: false))
        #expect(try context.fetch(FetchDescriptor<QuadrantTask>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<MicrosoftTodoSyncOperation>()).count == 1)
    }

    @Test @MainActor func deletionTombstoneCommitsWithTaskRemoval() throws {
        let container = try PersistenceController.inMemoryContainer()
        let context = container.mainContext
        let profile = MicrosoftTodoSyncProfile(
            accountIdentifier: "account-a",
            displayName: "Account A",
            defaultListIdentifier: "Tasks"
        )
        let task = QuadrantTask(title: "Delete me")
        let link = MicrosoftTodoTaskLink(
            profileIdentifier: profile.id,
            localTaskIdentifier: task.id,
            remoteTaskIdentifier: "remote-task",
            state: .linked
        )
        context.insert(profile)
        context.insert(task)
        context.insert(link)
        try context.save()

        let store = TaskStore(modelContext: context)
        store.quadrantTaskMutationRecorder = { mutation in
            guard case let .delete(taskID) = mutation else { return }
            context.insert(MicrosoftTodoDeletionTombstone(
                profileIdentifier: profile.id,
                localTaskIdentifier: taskID,
                remoteTaskIdentifier: "remote-task"
            ))
            context.insert(MicrosoftTodoSyncOperation(
                profileIdentifier: profile.id,
                localTaskIdentifier: taskID,
                remoteTaskIdentifier: "remote-task",
                operationKind: .delete
            ))
        }

        #expect(store.removeTask(task))
        #expect(try context.fetch(FetchDescriptor<QuadrantTask>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MicrosoftTodoDeletionTombstone>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<MicrosoftTodoSyncOperation>()).first?.operationKind == .delete)
    }

    @Test func dueDateKeyUsesCivilDateAcrossTimeZones() {
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let shanghaiDate = shanghai.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!

        let key = TaskDueDate.key(for: shanghaiDate, calendar: shanghai)
        #expect(key == "2026-03-29")

        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        #expect(TaskDueDate.date(for: key, calendar: paris).map { TaskDueDate.key(for: $0, calendar: paris) } == key)
        #expect(TaskDueDate.date(for: "2026-02-30", calendar: paris) == nil)
    }

    @Test func checklistDateDisplayDerivesFromCivilDateInCurrentCalendar() {
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let storedInstant = shanghai.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let task = QuadrantTask(title: "Travel-safe")
        task.setDueDate(storedInstant, calendar: shanghai)

        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        let reconstructed = task.effectiveDueDateKey.flatMap { TaskDueDate.date(for: $0, calendar: paris) }
        #expect(reconstructed.map { TaskDueDate.key(for: $0, calendar: paris) } == "2026-09-03")
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
              "dueDateTime": { "dateTime": "2026-08-17T09:00:00.0000000", "timeZone": "Europe/Paris" },
              "completedDateTime": { "dateTime": "2026-08-16T10:00:00.0000000", "timeZone": "Europe/Paris" },
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
        #expect(metadata.hasUrgentThresholdDays == true)
        #expect(metadata.urgentThresholdDays == 3)
        #expect(metadata.hasOriginalUrgentThresholdDays == true)
        #expect(metadata.originalUrgentThresholdDays == 5)
        #expect(metadata.isTop == true)

        let payload = MicrosoftTodoTaskPayload(
            title: "Local task",
            body: .init(content: "Local notes"),
            importance: "low",
            status: "completed",
            dueDateTime: .init(date: Date(timeIntervalSince1970: 1_786_032_000), timeZone: TimeZone(identifier: "Europe/Paris")!)
        )
        let encoded = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        let body = try #require(object?["body"] as? [String: String])
        #expect(body["content"] == "Local notes")
        #expect(body["contentType"] == "text")
        #expect(object?["importance"] as? String == "low")
        #expect(object?["status"] as? String == "completed")
        let dueDateTime = try #require(object?["dueDateTime"] as? [String: String])
        #expect(dueDateTime["timeZone"] == "Europe/Paris")

        let clearPayload = MicrosoftTodoTaskPayload(
            title: "Clear due date",
            body: .init(content: ""),
            importance: "normal",
            status: "notStarted",
            dueDateTime: nil
        )
        let clearObject = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(clearPayload)) as? [String: Any])
        #expect(clearObject["dueDateTime"] is NSNull)

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
        #expect(metadataObject["urgentThresholdDays"] as? Int == 3)
        #expect(metadataObject["hasOriginalUrgentThresholdDays"] as? Bool == true)
        #expect(metadataObject["originalUrgentThresholdDays"] as? Int == 5)
        #expect(metadataObject["isTop"] as? Bool == true)

        let createPayload = MicrosoftTodoTaskPayload(
            title: "Create with extension",
            body: .init(content: "Metadata belongs in the create request"),
            importance: "high",
            status: "notStarted",
            dueDateTime: .init(dueDateKey: "2026-09-02", timeZoneIdentifier: "Europe/Paris"),
            extensions: [metadataPayload]
        )
        let createObject = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(createPayload)) as? [String: Any])
        let extensions = try #require(createObject["extensions"] as? [[String: Any]])
        #expect(extensions.first?["extensionName"] as? String == MicrosoftTodoTaskMetadata.extensionName)
        #expect((createObject["dueDateTime"] as? [String: String])?["timeZone"] == "Romance Standard Time")

        let taskWithExplicitMetadata = page.value[0].replacingExtensions([metadata])
        #expect(taskWithExplicitMetadata.fourQuadrantsMetadata?.localTaskIdentifier == metadata.localTaskIdentifier)
    }
}
