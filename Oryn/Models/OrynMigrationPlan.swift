import SwiftData

enum OrynSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [OrynTask.self] }
}

enum OrynSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] { [OrynTask.self] }
}

enum OrynSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 2, 0)
    static var models: [any PersistentModel.Type] { [OrynTask.self, ProductivityRecord.self] }
}

// V4 adds recurrence, backlog, and manual-scheduling fields to OrynTask.
// All new fields are optional so lightweight migration leaves existing rows as nil.
enum OrynSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 3, 0)
    static var models: [any PersistentModel.Type] { [OrynTask.self, ProductivityRecord.self] }
}

enum OrynMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [OrynSchemaV1.self, OrynSchemaV2.self, OrynSchemaV3.self, OrynSchemaV4.self]
    }
    static var stages: [MigrationStage] { [v1ToV2, v2ToV3, v3ToV4] }

    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: OrynSchemaV1.self,
        toVersion: OrynSchemaV2.self
    )

    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: OrynSchemaV2.self,
        toVersion: OrynSchemaV3.self
    )

    static let v3ToV4 = MigrationStage.lightweight(
        fromVersion: OrynSchemaV3.self,
        toVersion: OrynSchemaV4.self
    )
}
