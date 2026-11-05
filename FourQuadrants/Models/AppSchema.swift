import SwiftData

/// First-release persistence baseline. No previous Four Quadrants schema has
/// shipped, so development databases created by earlier prototypes are not a
/// supported migration source.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

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
