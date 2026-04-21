import SwiftData

enum OrynSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [OrynTask.self] }
}

enum OrynSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] { [OrynTask.self] }
}

enum OrynMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [OrynSchemaV1.self, OrynSchemaV2.self] }
    static var stages: [MigrationStage] { [v1ToV2] }

    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: OrynSchemaV1.self,
        toVersion: OrynSchemaV2.self
    )
}
