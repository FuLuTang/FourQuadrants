import Foundation
import SwiftData
import Testing
@testable import FourQuadrantsMac

@MainActor
struct MacTaskDraftTests {
    private func makeStore() throws -> (ModelContainer, TaskStore) {
        let container = try PersistenceController.inMemoryContainer()
        return (container, TaskStore(modelContext: container.mainContext))
    }

    private func onlyTask(in container: ModelContainer) throws -> QuadrantTask {
        try #require(container.mainContext.fetch(FetchDescriptor<QuadrantTask>()).first)
    }

    @Test func blankTitleCannotBeSaved() throws {
        let (container, store) = try makeStore()
        var draft = MacTaskDraft()
        draft.title = "   \n"
        #expect(!draft.hasValidTitle)
        #expect(!draft.save(to: nil, using: store))
        #expect(try container.mainContext.fetch(FetchDescriptor<QuadrantTask>()).isEmpty)
    }

    @Test func savingNewDraftTrimsTextAndRecordsOriginals() throws {
        let (container, store) = try makeStore()
        var draft = MacTaskDraft()
        draft.title = "  新任务 "
        draft.notes = "  \n"
        draft.importance = .high
        draft.hasDueDate = true
        draft.hasUrgentThreshold = true
        draft.urgentThresholdDays = 2
        #expect(draft.save(to: nil, using: store))

        let task = try onlyTask(in: container)
        #expect(task.title == "新任务")
        #expect(task.notes == nil)
        #expect(task.urgentThresholdDays == 2)
        #expect(task.originalUrgentThresholdDays == 2)
        #expect(task.originalImportance == .high)
    }

    @Test func savingExistingDraftUpdatesAndTogglesCompletion() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "原标题", importance: .normal, isUrgent: false, isTop: false))
        let task = try onlyTask(in: container)

        var draft = MacTaskDraft(task: task)
        draft.title = "新标题"
        draft.isTop = true
        draft.isCompleted = true
        #expect(draft.save(to: task, using: store))
        #expect(task.title == "新标题")
        #expect(task.isTop)
        #expect(task.isCompleted)
    }

    @Test func dueDateRemovalClearsThreshold() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "有期限", importance: .normal, isUrgent: false, isTop: false, dueAt: .now, urgentThresholdDays: 3))
        let task = try onlyTask(in: container)
        var draft = MacTaskDraft(task: task)
        #expect(draft.hasAutomaticUrgency)
        draft.hasDueDate = false
        #expect(draft.save(to: task, using: store))
        #expect(task.effectiveDueDateKey == nil)
        #expect(task.urgentThresholdDays == nil)
    }

    @Test func effectiveUrgencyFollowsThresholdOnlyWhenAutomatic() throws {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: .now)
        var draft = MacTaskDraft()
        draft.isUrgent = false
        draft.hasDueDate = true
        draft.dueDate = try #require(calendar.date(byAdding: .day, value: 2, to: now))
        #expect(!draft.effectiveUrgency(now: now))

        draft.hasUrgentThreshold = true
        draft.urgentThresholdDays = 3
        #expect(draft.effectiveUrgency(now: now))
        draft.urgentThresholdDays = 1
        #expect(!draft.effectiveUrgency(now: now))
    }

    @Test func dirtyCheckIgnoresTimeOfDayAndFollowsRealEdits() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "任务", importance: .normal, isUrgent: false, isTop: false, dueAt: .now))
        let task = try onlyTask(in: container)
        var session = MacTaskDraftSession(task: task)
        #expect(!session.isDirty)

        session.draft.dueDate = session.draft.dueDate.addingTimeInterval(60)
        if Calendar.current.isDate(session.draft.dueDate, inSameDayAs: session.baseline.dueDate) {
            #expect(!session.isDirty)
        }
        session.draft.title = "改动"
        #expect(session.isDirty)
        session.draft.title = "任务"
        #expect(!session.isDirty)
    }

    @Test func externalChangeRefreshesCleanDraft() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "任务", importance: .normal, isUrgent: false, isTop: false))
        let task = try onlyTask(in: container)
        var session = MacTaskDraftSession(task: task)

        task.title = "同步改名"
        session.taskDidChange(task)
        #expect(session.draft.title == "同步改名")
        #expect(!session.hasExternalUpdate)
        #expect(!session.isDirty)
    }

    @Test func externalChangeDoesNotOverwriteUnsavedEdits() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "任务", importance: .normal, isUrgent: false, isTop: false))
        let task = try onlyTask(in: container)
        var session = MacTaskDraftSession(task: task)

        session.draft.title = "我的未保存标题"
        task.title = "同步改名"
        session.taskDidChange(task)
        #expect(session.draft.title == "我的未保存标题")
        #expect(session.hasExternalUpdate)
        #expect(session.isDirty)

        session.reload(from: task)
        #expect(session.draft.title == "同步改名")
        #expect(!session.hasExternalUpdate)
    }

    @Test func shouldAutosaveOnlyForDirtyValidDraftWithoutConflict() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "任务", importance: .normal, isUrgent: false, isTop: false))
        let task = try onlyTask(in: container)

        // 脏且标题有效 -> 自动保存
        var session = MacTaskDraftSession(task: task)
        session.draft.title = "待保存"
        #expect(session.shouldAutosave)

        // 标题为空 -> 不自动保存
        session = MacTaskDraftSession(task: task)
        session.draft.title = "   "
        #expect(!session.shouldAutosave)

        // 有外部更新冲突 -> 不自动保存
        session = MacTaskDraftSession(task: task)
        session.draft.title = "我的修改"
        task.title = "同步改名"
        session.taskDidChange(task)
        #expect(session.hasExternalUpdate)
        #expect(!session.shouldAutosave)

        // 未修改 -> 不自动保存
        session = MacTaskDraftSession(task: task)
        #expect(!session.shouldAutosave)
    }

    @Test func successfulSessionSaveBecomesCleanBaseline() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "任务", importance: .normal, isUrgent: false, isTop: false))
        let task = try onlyTask(in: container)
        var session = MacTaskDraftSession(task: task)
        session.draft.title = "  保存后  "
        let saved = session.save(to: task, using: store)
        #expect(saved)
        #expect(task.title == "保存后")
        #expect(!session.isDirty)
        #expect(session.draft.title == "保存后")
    }

    @Test func changingImportanceUpdatesOriginalImportance() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "任务", importance: .normal, isUrgent: false, isTop: false, originalImportance: .normal))
        let task = try onlyTask(in: container)

        var draft = MacTaskDraft(task: task)
        draft.importance = .low
        #expect(draft.save(to: task, using: store))
        #expect(task.importance == .low)
        #expect(task.originalImportance == .low)
    }

    @Test func titleOnlyEditKeepsOriginalValues() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(
            title: "任务",
            importance: .normal,
            isUrgent: false,
            isTop: false,
            dueAt: .now,
            urgentThresholdDays: 2,
            originalUrgentThresholdDays: 4,
            originalImportance: .high
        ))
        let task = try onlyTask(in: container)

        var draft = MacTaskDraft(task: task)
        draft.title = "只改标题"
        #expect(draft.save(to: task, using: store))
        #expect(task.title == "只改标题")
        #expect(task.originalImportance == .high)
        #expect(task.originalUrgentThresholdDays == 4)
    }

    @Test func quadrantMoveDoesNotChangeOriginalImportanceOnLaterTitleEdit() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(title: "任务", importance: .normal, isUrgent: false, isTop: false, originalImportance: .normal))
        let task = try onlyTask(in: container)

        // 拖动移动到重要象限会把重要性改为高，但不算手动设置。
        #expect(store.moveTask(task, to: .importantButNotUrgent))
        #expect(task.importance == .high)
        #expect(task.originalImportance == .normal)

        var draft = MacTaskDraft(task: task)
        draft.title = "移动后只改标题"
        #expect(draft.save(to: task, using: store))
        #expect(task.originalImportance == .normal)
    }

    @Test func changingThresholdDaysUpdatesOriginalThreshold() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(
            title: "有期限",
            importance: .normal,
            isUrgent: false,
            isTop: false,
            dueAt: .now,
            urgentThresholdDays: 3,
            originalUrgentThresholdDays: 3
        ))
        let task = try onlyTask(in: container)

        var draft = MacTaskDraft(task: task)
        draft.urgentThresholdDays = 5
        #expect(draft.save(to: task, using: store))
        #expect(task.urgentThresholdDays == 5)
        #expect(task.originalUrgentThresholdDays == 5)
    }

    @Test func turningOffAutomaticUrgencyKeepsOriginalThreshold() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(
            title: "有期限",
            importance: .normal,
            isUrgent: false,
            isTop: false,
            dueAt: .now,
            urgentThresholdDays: 3,
            originalUrgentThresholdDays: 3
        ))
        let task = try onlyTask(in: container)

        var draft = MacTaskDraft(task: task)
        draft.hasUrgentThreshold = false
        #expect(draft.save(to: task, using: store))
        #expect(task.urgentThresholdDays == nil)
        #expect(task.originalUrgentThresholdDays == 3)
    }

    @Test func dueDateRemovalKeepsOriginalThreshold() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(
            title: "有期限",
            importance: .normal,
            isUrgent: false,
            isTop: false,
            dueAt: .now,
            urgentThresholdDays: 3,
            originalUrgentThresholdDays: 5
        ))
        let task = try onlyTask(in: container)

        var draft = MacTaskDraft(task: task)
        draft.hasDueDate = false
        #expect(draft.save(to: task, using: store))
        #expect(task.effectiveDueDateKey == nil)
        #expect(task.urgentThresholdDays == nil)
        #expect(task.originalUrgentThresholdDays == 5)
    }

    @Test func originalValueResolutionOnlyTakesManualChanges() throws {
        let (container, store) = try makeStore()
        #expect(store.addTask(
            title: "任务",
            importance: .normal,
            isUrgent: false,
            isTop: false,
            dueAt: .now,
            urgentThresholdDays: 3,
            originalUrgentThresholdDays: 4,
            originalImportance: .low
        ))
        let task = try onlyTask(in: container)

        let unchanged = TaskOriginalValues.resolve(task: task, newImportance: .normal, newThreshold: 3)
        #expect(unchanged.importance == .low)
        #expect(unchanged.urgentThresholdDays == 4)

        let changed = TaskOriginalValues.resolve(task: task, newImportance: .high, newThreshold: nil)
        #expect(changed.importance == .high)
        #expect(changed.urgentThresholdDays == 4)

        let edited = TaskOriginalValues.resolve(task: task, newImportance: .low, newThreshold: 6)
        #expect(edited.importance == .low)
        #expect(edited.urgentThresholdDays == 6)
    }
}
