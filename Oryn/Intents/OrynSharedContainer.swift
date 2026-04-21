import SwiftData
import Foundation

/// Creates a standalone ModelContainer for use inside App Intents,
/// which run outside the main app's SwiftUI environment.
enum OrynSharedContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([OrynTask.self, ProductivityRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(
            for: schema,
            migrationPlan: OrynMigrationPlan.self,
            configurations: [config]
        )
    }
}
