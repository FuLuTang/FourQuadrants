import Foundation

enum SyncDiagnosticStep: String, CaseIterable, Identifiable, Equatable {
    case createAndRestore
    case moveAndResync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .createAndRestore: "创建并从云端恢复"
        case .moveAndResync: "移动象限后再次同步"
        }
    }

    var detail: String {
        switch self {
        case .createAndRestore: "创建 8 条随机任务，回读并导入后校验字段。"
        case .moveAndResync: "调用生产象限移动逻辑，再走完整同步与回读。"
        }
    }
}

enum SyncDiagnosticStepStatus: Equatable {
    case pending
    case running
    case passed
    case failed(String)
}

struct SyncDiagnosticStepResult: Identifiable, Equatable {
    let step: SyncDiagnosticStep
    var status: SyncDiagnosticStepStatus

    var id: SyncDiagnosticStep.ID { step.id }
}

struct SyncDiagnosticTaskSnapshot {
    let id: UUID
    let title: String
    let notes: String?
    let importance: ImportanceLevel
    let manualIsUrgent: Bool
    let urgentThresholdDays: Int?
    let originalUrgentThresholdDays: Int?
    let originalImportance: ImportanceLevel?
    let isTop: Bool
    let dueDateKey: String?
    let isCompleted: Bool

    init(task: QuadrantTask) {
        id = task.id
        title = task.title
        notes = task.notes
        importance = task.importance
        manualIsUrgent = task.manualIsUrgent
        urgentThresholdDays = task.urgentThresholdDays
        originalUrgentThresholdDays = task.originalUrgentThresholdDays
        originalImportance = task.originalImportance
        isTop = task.isTop
        dueDateKey = task.effectiveDueDateKey
        isCompleted = task.isCompleted
    }
}

enum SyncDiagnosticResult: Equatable {
    case running
    case success
    case failure(String, remoteTaskIdentifiers: [String] = [])
}
