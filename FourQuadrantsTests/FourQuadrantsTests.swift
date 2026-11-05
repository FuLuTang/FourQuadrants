import Foundation
import SwiftData
import Testing
@testable import FourQuadrants

struct FourQuadrantsTests {
    @Test func widgetDeepLinksRouteToTheExpectedDestination() throws {
        let taskID = UUID()
        #expect(WidgetRoute(url: URL(string: "fourquadrants://today")!) == .today)
        #expect(WidgetRoute(url: URL(string: "fourquadrants://quadrant/important_urgent")!) == .quadrant(.importantAndUrgent))
        #expect(WidgetRoute(url: URL(string: "fourquadrants://task/\(taskID.uuidString)")!) == .task(taskID))
        #expect(WidgetRoute(url: URL(string: "fourquadrants://quadrant/all")!) == nil)
    }

    @Test @MainActor func widgetTaskOrderingPrioritizesOverdueAndDueTasks() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let overdue = QuadrantTask(title: "Overdue", createdAt: today.addingTimeInterval(-30), dueAt: today.addingTimeInterval(-86_400))
        let tomorrow = QuadrantTask(title: "Tomorrow", createdAt: today, dueAt: today.addingTimeInterval(86_400))
        let undated = QuadrantTask(title: "Undated", createdAt: today.addingTimeInterval(30))

        let ordered = WidgetSnapshotService.sortTasksForWidget([undated, tomorrow, overdue])
        #expect(ordered.map(\.title) == ["Overdue", "Tomorrow", "Undated"])
    }

    @Test @MainActor func sharedIntelligenceOrderingUsesImportanceThenTopThenDueDateAndStableTies() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func task(
            _ id: String,
            importance: ImportanceLevel = .high,
            isTop: Bool = true,
            dueOffset: TimeInterval? = nil,
            updatedOffset: TimeInterval = 0
        ) -> QuadrantTask {
            QuadrantTask(
                id: UUID(uuidString: id)!,
                title: id,
                createdAt: base,
                updatedAt: base.addingTimeInterval(updatedOffset),
                dueAt: dueOffset.map { base.addingTimeInterval($0) },
                importance: importance,
                isUrgent: false,
                isTop: isTop
            )
        }

        let highTopEarlyID5 = task("00000000-0000-0000-0000-000000000005", dueOffset: 86_400, updatedOffset: 2)
        let highTopEarlyID6 = task("00000000-0000-0000-0000-000000000006", dueOffset: 86_400, updatedOffset: 1)
        let highTopEarlyID4 = task("00000000-0000-0000-0000-000000000004", dueOffset: 86_400, updatedOffset: 1)
        let highTopLater = task("00000000-0000-0000-0000-000000000003", dueOffset: 172_800)
        let highTopUndated = task("00000000-0000-0000-0000-000000000007", updatedOffset: -1)
        let highNotTop = task("00000000-0000-0000-0000-000000000002", isTop: false, dueOffset: -86_400)
        let normalTop = task("00000000-0000-0000-0000-000000000001", importance: .normal, dueOffset: -172_800)
        let lowTop = task("00000000-0000-0000-0000-000000000008", importance: .low, dueOffset: -259_200)

        let input = [lowTop, highNotTop, highTopUndated, normalTop, highTopLater, highTopEarlyID5, highTopEarlyID6, highTopEarlyID4]
        let expected = [highTopEarlyID4, highTopEarlyID6, highTopEarlyID5, highTopLater, highTopUndated, highNotTop, normalTop, lowTop]

        #expect(TaskOrdering.sorted(input, by: .intelligence).map(\.id) == expected.map(\.id))
        #expect(TaskOrdering.sorted(input, by: .intelligence, direction: .descending).map(\.id) == expected.map(\.id))
        #expect(Set(TaskStore.TaskSortMethod.allCases).count == 4)
    }

    @Test @MainActor func dueDateDirectionReversesDatedTasksAndKeepsUndatedLast() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func task(_ id: Int, title: String, dueOffset: TimeInterval?) -> QuadrantTask {
            QuadrantTask(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
                title: title,
                createdAt: base,
                dueAt: dueOffset.map { base.addingTimeInterval($0) }
            )
        }

        let earlyID1 = task(1, title: "Early 1", dueOffset: 86_400)
        let earlyID2 = task(2, title: "Early 2", dueOffset: 86_400)
        let late = task(3, title: "Late", dueOffset: 172_800)
        let undated = task(4, title: "Undated", dueOffset: nil)
        let input = [undated, late, earlyID2, earlyID1]

        #expect(TaskOrdering.sorted(input, by: .byDueDate).map(\.id) == [earlyID1.id, earlyID2.id, late.id, undated.id])
        #expect(TaskOrdering.sorted(input, by: .byDueDate, direction: .descending).map(\.id) == [late.id, earlyID1.id, earlyID2.id, undated.id])
    }

    @Test @MainActor func creationDateAndNameDirectionsKeepStableIDTieBreaks() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func task(_ id: Int, title: String, createdOffset: TimeInterval) -> QuadrantTask {
            QuadrantTask(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
                title: title,
                createdAt: base.addingTimeInterval(createdOffset)
            )
        }

        let olderID1 = task(1, title: "Bravo", createdOffset: 0)
        let olderID2 = task(2, title: "Bravo", createdOffset: 0)
        let newer = task(3, title: "Alpha", createdOffset: 86_400)
        let input = [newer, olderID2, olderID1]

        #expect(TaskOrdering.sorted(input, by: .byCreationDate).map(\.id) == [olderID1.id, olderID2.id, newer.id])
        #expect(TaskOrdering.sorted(input, by: .byCreationDate, direction: .descending).map(\.id) == [newer.id, olderID1.id, olderID2.id])
        #expect(TaskOrdering.sorted(input, by: .byName).map(\.id) == [newer.id, olderID1.id, olderID2.id])
        #expect(TaskOrdering.sorted(input, by: .byName, direction: .descending).map(\.id) == [olderID1.id, olderID2.id, newer.id])
    }

    @Test @MainActor func recommendationFillsWithImportantUrgentTasksBeforeOtherGroups() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func task(_ id: Int, importance: ImportanceLevel = .high, urgent: Bool, dueOffset: TimeInterval? = nil) -> QuadrantTask {
            QuadrantTask(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
                title: "Task \(id)",
                createdAt: base,
                updatedAt: base,
                dueAt: dueOffset.map { base.addingTimeInterval($0) },
                importance: importance,
                isUrgent: urgent
            )
        }

        let importantUrgent = (1...6).map { task($0, urgent: true, dueOffset: TimeInterval($0) * 86_400) }
        let urgentNotImportant = task(20, importance: .normal, urgent: true)
        let importantNotUrgent = task(30, urgent: false)

        let recommended = TaskOrdering.recommended(importantUrgent + [urgentNotImportant, importantNotUrgent], limit: 5)
        let recommendedIDs = recommended.map(\.id)
        let expectedIDs = Array(importantUrgent.prefix(5)).map(\.id)
        #expect(recommendedIDs == expectedIDs)
        #expect(TaskOrdering.sorted(
            importantUrgent + [urgentNotImportant, importantNotUrgent],
            by: .intelligence,
            direction: .descending
        ).map(\.id) == TaskOrdering.sorted(
            importantUrgent + [urgentNotImportant, importantNotUrgent],
            by: .intelligence
        ).map(\.id))
        #expect(TaskOrdering.recommended(importantUrgent, limit: 0).isEmpty)
    }

    @Test @MainActor func recommendationKeepsGroupGuaranteesThenFillsByIntelligenceAndCapacityPrefix() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func task(
            _ id: Int,
            importance: ImportanceLevel = .high,
            urgent: Bool,
            isTop: Bool = false,
            dueOffset: TimeInterval? = nil,
            updatedOffset: TimeInterval = 0
        ) -> QuadrantTask {
            QuadrantTask(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
                title: "Task \(id)",
                createdAt: base,
                updatedAt: base.addingTimeInterval(updatedOffset),
                dueAt: dueOffset.map { base.addingTimeInterval($0) },
                importance: importance,
                isUrgent: urgent,
                isTop: isTop
            )
        }

        let urgentImportantEarly = task(1, urgent: true, dueOffset: 86_400)
        let urgentImportantTop = task(2, urgent: true, isTop: true, dueOffset: 172_800)
        let urgentNormal = task(3, importance: .normal, urgent: true, dueOffset: 86_400)
        let urgentLow = task(4, importance: .low, urgent: true, dueOffset: 86_400)
        let importantNotUrgentEarly = task(5, urgent: false, dueOffset: 86_400)
        let importantNotUrgentTop = task(6, urgent: false, isTop: true, dueOffset: 172_800)

        let input = [urgentImportantEarly, urgentNormal, importantNotUrgentEarly, urgentLow, urgentImportantTop, importantNotUrgentTop]
        let limitFive = TaskOrdering.recommended(input, limit: 5)
        let expectedIDs = [urgentImportantTop.id, urgentImportantEarly.id, urgentNormal.id, importantNotUrgentTop.id, importantNotUrgentEarly.id]
        let limitFiveIDs = limitFive.map(\.id)
        let limitThreeIDs = TaskOrdering.recommended(input, limit: 3).map(\.id)
        let limitFourIDs = TaskOrdering.recommended(input, limit: 4).map(\.id)
        #expect(limitFiveIDs == expectedIDs)
        #expect(limitThreeIDs == Array(expectedIDs.prefix(3)))
        #expect(limitFourIDs == Array(expectedIDs.prefix(4)))
    }

    @Test func microsoftTodoRecurrenceDistinguishesUnobservedAndNull() throws {
        let absent = try JSONDecoder().decode(MicrosoftTodoTask.self, from: Data(#"{"id":"absent"}"#.utf8))
        let null = try JSONDecoder().decode(MicrosoftTodoTask.self, from: Data(#"{"id":"null","importance":null,"body":null,"dueDateTime":null,"recurrence":null}"#.utf8))
        #expect(absent.importanceObservation.isObserved == false)
        #expect(null.importanceObservation.isObserved == true)
        #expect(null.importanceObservation.value == nil)
        #expect(null.bodyObservation.isObserved == true)
        #expect(null.dueDateTimeObservation.isObserved == true)
        #expect(absent.recurrence.rawValue == "unobserved")
        #expect(null.recurrence.rawValue == "null")
        #expect(null.recurrence.encodedData == nil)
    }

    @Test @MainActor func updateAndCreateOperationsProtectLocalTaskDuringPull() {
        let taskID = UUID()
        let update = MicrosoftTodoSyncOperation(
            profileIdentifier: UUID(), localTaskIdentifier: taskID, operationKind: .update
        )
        let create = MicrosoftTodoSyncOperation(
            profileIdentifier: UUID(), localTaskIdentifier: taskID, operationKind: .create
        )
        let delete = MicrosoftTodoSyncOperation(
            profileIdentifier: UUID(), localTaskIdentifier: taskID, operationKind: .delete
        )
        #expect(SyncService.isLocalMutationOperation(update))
        #expect(SyncService.isLocalMutationOperation(create))
        #expect(!SyncService.isLocalMutationOperation(delete))
    }

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
            schema: Schema(versionedSchema: AppSchemaV1.self),
            url: storeURL,
            cloudKitDatabase: .none
        )
        let firstContainer = try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV1.self),
            configurations: configuration
        )
        let firstStore = TaskStore(modelContext: firstContainer.mainContext)
        #expect(try firstContainer.mainContext.fetch(FetchDescriptor<QuadrantTask>()).isEmpty)
        #expect(firstStore.addTask(title: "Persist me", importance: .normal, isUrgent: false, isTop: false))

        let reopenedContainer = try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV1.self),
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
              "recurrence": { "pattern": { "type": "weekly", "interval": 2, "daysOfWeek": ["monday"] }, "range": { "type": "noEnd", "startDate": "2026-08-17", "recurrenceTimeZone": "Europe/Paris" } },
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
        #expect(page.value[0].recurrence.rawValue == "value")
        #expect(page.value[0].recurrence.encodedData != nil)
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

        let statusOnlyPayload = MicrosoftTodoTaskPayload(
            title: nil, body: nil, importance: nil, status: "completed", dueDateTime: nil,
            includesTitle: false, includesBody: false, includesImportance: false,
            includesStatus: true, includesDueDateTime: false
        )
        let statusOnlyObject = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(statusOnlyPayload)) as? [String: Any])
        #expect(statusOnlyObject["status"] as? String == "completed")
        #expect(statusOnlyObject["dueDateTime"] == nil)
        #expect(statusOnlyObject["recurrence"] == nil)

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
        #expect((createObject["importance"] as? String) == "high")

        let taskWithExplicitMetadata = page.value[0].replacingExtensions([metadata])
        #expect(taskWithExplicitMetadata.fourQuadrantsMetadata?.localTaskIdentifier == metadata.localTaskIdentifier)
    }
}
