import SwiftData

// Versioned schemas for future SwiftData migrations.
// Current version is V1. Add V2, V3 etc. here as the schema evolves.

enum RoamieSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self, Waypoint.self] }
}

enum RoamieMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [RoamieSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
