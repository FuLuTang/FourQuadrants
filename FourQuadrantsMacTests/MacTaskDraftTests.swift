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
}
