import Foundation
import SwiftData

enum MicrosoftTodoLinkState: String, Codable {
    case linked
    case pendingUpload
    case remoteCreated
    case unknownCreateResult
    case localOnly
    case pendingLocalDeletion
    case remotelyDeleted
}

enum MicrosoftTodoOperationKind: String, Codable {
    case create
    case update
    case delete
}

enum MicrosoftTodoOperationState: String, Codable {
    case queued
    case inFlight
    case uncertain
    case retryableFailure
    case conflict
    case permanentFailure
}

@Model
final class MicrosoftTodoSyncProfile {
    var id: UUID = UUID()
    var accountIdentifier: String = ""
    var displayName: String = ""
    var defaultListIdentifier: String = ""
    var deltaLink: String?
    var isEnabled: Bool = true
    var taskTimeZoneIdentifier: String = TimeZone.current.identifier
    var hasCompletedInitialMerge: Bool = false
    var lastSuccessfulSyncAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        accountIdentifier: String,
        displayName: String,
        defaultListIdentifier: String,
        deltaLink: String? = nil,
        isEnabled: Bool = true,
        taskTimeZoneIdentifier: String = TimeZone.current.identifier,
        hasCompletedInitialMerge: Bool = false
    ) {
        self.id = id
        self.accountIdentifier = accountIdentifier
        self.displayName = displayName
        self.defaultListIdentifier = defaultListIdentifier
        self.deltaLink = deltaLink
        self.isEnabled = isEnabled
        self.taskTimeZoneIdentifier = taskTimeZoneIdentifier
        self.hasCompletedInitialMerge = hasCompletedInitialMerge
    }
}

@Model
final class MicrosoftTodoSyncOperation {
    var id: UUID = UUID()
    var operationIdentifier: UUID = UUID()
    var profileIdentifier: UUID = UUID()
    var localTaskIdentifier: UUID = UUID()
    var remoteTaskIdentifier: String?
    var operationKindRawValue: String = MicrosoftTodoOperationKind.update.rawValue
    var stateRawValue: String = MicrosoftTodoOperationState.queued.rawValue
    var expectedRemoteETag: String?
    var localUpdatedAt: Date?
    var attemptCount: Int = 0
    var nextAttemptAt: Date?
    var lastErrorMessage: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var operationKind: MicrosoftTodoOperationKind {
        get { MicrosoftTodoOperationKind(rawValue: operationKindRawValue) ?? .update }
        set { operationKindRawValue = newValue.rawValue }
    }

    var state: MicrosoftTodoOperationState {
        get { MicrosoftTodoOperationState(rawValue: stateRawValue) ?? .queued }
        set { stateRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        operationIdentifier: UUID = UUID(),
        profileIdentifier: UUID,
        localTaskIdentifier: UUID,
        remoteTaskIdentifier: String? = nil,
        operationKind: MicrosoftTodoOperationKind,
        expectedRemoteETag: String? = nil,
        localUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.operationIdentifier = operationIdentifier
        self.profileIdentifier = profileIdentifier
        self.localTaskIdentifier = localTaskIdentifier
        self.remoteTaskIdentifier = remoteTaskIdentifier
        self.operationKindRawValue = operationKind.rawValue
        self.expectedRemoteETag = expectedRemoteETag
        self.localUpdatedAt = localUpdatedAt
    }
}

@Model
final class MicrosoftTodoDeletionTombstone {
    var id: UUID = UUID()
    var profileIdentifier: UUID = UUID()
    var localTaskIdentifier: UUID = UUID()
    var remoteTaskIdentifier: String = ""
    var remoteETag: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        profileIdentifier: UUID,
        localTaskIdentifier: UUID,
        remoteTaskIdentifier: String,
        remoteETag: String? = nil
    ) {
        self.id = id
        self.profileIdentifier = profileIdentifier
        self.localTaskIdentifier = localTaskIdentifier
        self.remoteTaskIdentifier = remoteTaskIdentifier
        self.remoteETag = remoteETag
    }
}

@Model
final class MicrosoftTodoTaskLink {
    var id: UUID = UUID()
    var profileIdentifier: UUID = UUID()
    var localTaskIdentifier: UUID = UUID()
    var remoteTaskIdentifier: String?
    var remoteETag: String?
    var remoteLastModifiedAt: Date?
    var lastSyncedLocalUpdatedAt: Date?
    var stateRawValue: String = MicrosoftTodoLinkState.pendingUpload.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var state: MicrosoftTodoLinkState {
        get { MicrosoftTodoLinkState(rawValue: stateRawValue) ?? .pendingUpload }
        set { stateRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        profileIdentifier: UUID,
        localTaskIdentifier: UUID,
        remoteTaskIdentifier: String? = nil,
        state: MicrosoftTodoLinkState = .pendingUpload
    ) {
        self.id = id
        self.profileIdentifier = profileIdentifier
        self.localTaskIdentifier = localTaskIdentifier
        self.remoteTaskIdentifier = remoteTaskIdentifier
        self.stateRawValue = state.rawValue
    }
}
