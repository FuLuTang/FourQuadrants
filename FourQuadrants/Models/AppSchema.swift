import Foundation
import SwiftData

// Historical schemas are intentionally self-contained. Do not replace these
// model types with current production models when adding a later schema.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [QuadrantTask.self, DailyTask.self] }

    @Model
    final class QuadrantTask {
        var id: UUID = UUID()
        var title: String = ""
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var dueAt: Date?
        var completedAt: Date?
        var importance: ImportanceLevel = ImportanceLevel.normal
        var manualIsUrgent: Bool = false
        var urgentThresholdDays: Int?
        var originalUrgentThresholdDays: Int?
        var originalImportance: ImportanceLevel?
        var isTop: Bool = false

        @Relationship(deleteRule: .nullify, inverse: \DailyTask.quadrantTask)
        var dailyTasks: [DailyTask]?

        init(
            id: UUID = UUID(),
            title: String = "",
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            dueAt: Date? = nil,
            completedAt: Date? = nil,
            importance: ImportanceLevel = .normal,
            manualIsUrgent: Bool = false,
            urgentThresholdDays: Int? = nil,
            originalUrgentThresholdDays: Int? = nil,
            originalImportance: ImportanceLevel? = nil,
            isTop: Bool = false
        ) {
            self.id = id
            self.title = title
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.dueAt = dueAt
            self.completedAt = completedAt
            self.importance = importance
            self.manualIsUrgent = manualIsUrgent
            self.urgentThresholdDays = urgentThresholdDays
            self.originalUrgentThresholdDays = originalUrgentThresholdDays
            self.originalImportance = originalImportance
            self.isTop = isTop
        }
    }

    @Model
    final class DailyTask {
        var id: UUID = UUID()
        var title: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var startAt: Date = Date()
        var duration: TimeInterval = 3600
        var completedAt: Date?
        var colorHex: String?
        var notes: String?
        var quadrantTask: QuadrantTask?

        init(
            id: UUID = UUID(),
            title: String = "",
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            startAt: Date = Date(),
            duration: TimeInterval = 3600,
            completedAt: Date? = nil,
            colorHex: String? = nil,
            notes: String? = nil,
            quadrantTask: QuadrantTask? = nil
        ) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.startAt = startAt
            self.duration = duration
            self.completedAt = completedAt
            self.colorHex = colorHex
            self.notes = notes
            self.quadrantTask = quadrantTask
        }
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [QuadrantTask.self, DailyTask.self, MicrosoftTodoSyncProfile.self, MicrosoftTodoTaskLink.self]
    }

    @Model
    final class QuadrantTask {
        var id: UUID = UUID()
        var title: String = ""
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var dueAt: Date?
        var completedAt: Date?
        var importance: ImportanceLevel = ImportanceLevel.normal
        var manualIsUrgent: Bool = false
        var urgentThresholdDays: Int?
        var originalUrgentThresholdDays: Int?
        var originalImportance: ImportanceLevel?
        var isTop: Bool = false

        @Relationship(deleteRule: .nullify, inverse: \DailyTask.quadrantTask)
        var dailyTasks: [DailyTask]?

        init(
            id: UUID = UUID(),
            title: String = "",
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            dueAt: Date? = nil,
            completedAt: Date? = nil,
            importance: ImportanceLevel = .normal,
            manualIsUrgent: Bool = false,
            urgentThresholdDays: Int? = nil,
            originalUrgentThresholdDays: Int? = nil,
            originalImportance: ImportanceLevel? = nil,
            isTop: Bool = false
        ) {
            self.id = id
            self.title = title
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.dueAt = dueAt
            self.completedAt = completedAt
            self.importance = importance
            self.manualIsUrgent = manualIsUrgent
            self.urgentThresholdDays = urgentThresholdDays
            self.originalUrgentThresholdDays = originalUrgentThresholdDays
            self.originalImportance = originalImportance
            self.isTop = isTop
        }
    }

    @Model
    final class DailyTask {
        var id: UUID = UUID()
        var title: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var startAt: Date = Date()
        var duration: TimeInterval = 3600
        var completedAt: Date?
        var colorHex: String?
        var notes: String?
        var quadrantTask: QuadrantTask?

        init(
            id: UUID = UUID(),
            title: String = "",
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            startAt: Date = Date(),
            duration: TimeInterval = 3600,
            completedAt: Date? = nil,
            colorHex: String? = nil,
            notes: String? = nil,
            quadrantTask: QuadrantTask? = nil
        ) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.startAt = startAt
            self.duration = duration
            self.completedAt = completedAt
            self.colorHex = colorHex
            self.notes = notes
            self.quadrantTask = quadrantTask
        }
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
            accountIdentifier: String = "",
            displayName: String = "",
            defaultListIdentifier: String = "",
            deltaLink: String? = nil,
            isEnabled: Bool = true,
            lastSuccessfulSyncAt: Date? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.accountIdentifier = accountIdentifier
            self.displayName = displayName
            self.defaultListIdentifier = defaultListIdentifier
            self.deltaLink = deltaLink
            self.isEnabled = isEnabled
            self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
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

        init(
            id: UUID = UUID(),
            profileIdentifier: UUID = UUID(),
            localTaskIdentifier: UUID = UUID(),
            remoteTaskIdentifier: String? = nil,
            remoteETag: String? = nil,
            remoteLastModifiedAt: Date? = nil,
            lastSyncedLocalUpdatedAt: Date? = nil,
            stateRawValue: String = MicrosoftTodoLinkState.pendingUpload.rawValue,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.profileIdentifier = profileIdentifier
            self.localTaskIdentifier = localTaskIdentifier
            self.remoteTaskIdentifier = remoteTaskIdentifier
            self.remoteETag = remoteETag
            self.remoteLastModifiedAt = remoteLastModifiedAt
            self.lastSyncedLocalUpdatedAt = lastSyncedLocalUpdatedAt
            self.stateRawValue = stateRawValue
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

enum AppSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [
            QuadrantTask.self,
            DailyTask.self,
            MicrosoftTodoSyncProfile.self,
            MicrosoftTodoTaskLink.self,
            MicrosoftTodoSyncOperation.self,
            MicrosoftTodoDeletionTombstone.self
        ]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self, AppSchemaV3.self] }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self),
            migrateV2toV3
        ]
    }

    /// V3 introduces a civil-date field. Populate it while V2's absolute date
    /// is still available so the first V3 launch has one authoritative value.
    static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: AppSchemaV2.self,
        toVersion: AppSchemaV3.self,
        willMigrate: nil,
        didMigrate: { context in
            let tasks = try context.fetch(FetchDescriptor<QuadrantTask>())
            for task in tasks {
                task.restoreLegacyDueDateKeyIfNeeded()
            }
            try context.save()
        }
    )
}
