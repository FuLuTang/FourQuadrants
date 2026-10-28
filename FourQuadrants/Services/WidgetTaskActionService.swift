import Foundation
import SwiftData

/// Executes widget task actions against the same App Group store as the app.
@MainActor
enum WidgetTaskActionService {
    static func toggle(taskID: UUID) -> Bool {
        guard let container = try? PersistenceController().makeContainer() else { return false }
        let context = container.mainContext
        let store = TaskStore(modelContext: context)
        store.quadrantTaskMutationRecorder = { mutation in
            guard case let .upsert(id) = mutation else { return }
            try enqueueLinkedTask(id, in: context)
        }
        let descriptor = FetchDescriptor<QuadrantTask>(predicate: #Predicate { $0.id == taskID })
        guard let task = try? context.fetch(descriptor).first else { return false }
        return store.toggleTask(task)
    }

    private static func enqueueLinkedTask(_ taskID: UUID, in context: ModelContext) throws {
        let links = try context.fetch(FetchDescriptor<MicrosoftTodoTaskLink>())
        let taskLinks = links.filter { $0.localTaskIdentifier == taskID }
        let profile: MicrosoftTodoSyncProfile
        let link: MicrosoftTodoTaskLink
        if let existingLink = taskLinks
            .filter({ $0.state != .localOnly && $0.state != .pendingLocalDeletion && $0.state != .remotelyDeleted })
            .sorted(by: { ($0.remoteTaskIdentifier != nil) && ($1.remoteTaskIdentifier == nil) })
            .first,
           let existingProfile = try context.fetch(FetchDescriptor<MicrosoftTodoSyncProfile>()).first(where: { $0.id == existingLink.profileIdentifier }) {
            profile = existingProfile
            link = existingLink
        } else {
            guard taskLinks.isEmpty else { return }
            let eligibleProfiles = try context.fetch(FetchDescriptor<MicrosoftTodoSyncProfile>())
                .filter { $0.isEnabled && $0.hasCompletedInitialMerge }
            guard eligibleProfiles.count == 1, let onlyProfile = eligibleProfiles.first else { return }
            profile = onlyProfile
            link = MicrosoftTodoTaskLink(profileIdentifier: profile.id, localTaskIdentifier: taskID)
            context.insert(link)
        }

        let operations = try context.fetch(FetchDescriptor<MicrosoftTodoSyncOperation>())
        let existing = operations.filter { $0.profileIdentifier == profile.id && $0.localTaskIdentifier == taskID }
        let kind: MicrosoftTodoOperationKind = link.remoteTaskIdentifier == nil ? .create : .update
        link.state = .pendingUpload
        link.updatedAt = .now
        let operation = existing.sorted { $0.updatedAt > $1.updatedAt }.first
        guard let operation else {
            context.insert(MicrosoftTodoSyncOperation(
                profileIdentifier: profile.id,
                localTaskIdentifier: taskID,
                remoteTaskIdentifier: link.remoteTaskIdentifier,
                operationKind: kind,
                expectedRemoteETag: link.remoteETag,
                localUpdatedAt: try context.fetch(FetchDescriptor<QuadrantTask>()).first { $0.id == taskID }?.updatedAt
            ))
            return
        }
        operation.operationKind = operation.operationKind == .create && kind == .update ? .create : kind
        operation.remoteTaskIdentifier = link.remoteTaskIdentifier ?? operation.remoteTaskIdentifier
        operation.expectedRemoteETag = link.remoteETag ?? operation.expectedRemoteETag
        operation.localUpdatedAt = (try context.fetch(FetchDescriptor<QuadrantTask>()).first { $0.id == taskID })?.updatedAt
        operation.state = .queued
        operation.nextAttemptAt = nil
        operation.lastErrorMessage = nil
        operation.updatedAt = .now
        for duplicate in existing where duplicate.id != operation.id { context.delete(duplicate) }
    }
}
