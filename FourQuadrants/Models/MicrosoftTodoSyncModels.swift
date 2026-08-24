import Foundation
import SwiftData

enum MicrosoftTodoLinkState: String, Codable {
    case linked
    case pendingUpload
    case localOnly
    case pendingLocalDeletion
    case remotelyDeleted
}

@Model
final class MicrosoftTodoSyncProfile {
    var id: UUID = UUID()
    var accountIdentifier: String = ""
    var displayName: String = ""
    var defaultListIdentifier: String = ""
    var deltaLink: String?
    var isEnabled: Bool = true
    var lastSuccessfulSyncAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        accountIdentifier: String,
        displayName: String,
        defaultListIdentifier: String,
        deltaLink: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.accountIdentifier = accountIdentifier
        self.displayName = displayName
        self.defaultListIdentifier = defaultListIdentifier
        self.deltaLink = deltaLink
        self.isEnabled = isEnabled
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
