import SwiftUI
import SwiftData

@main
struct RoamieApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([Trip.self, Waypoint.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TripListView()
                .environment(AppEnvironment())
        }
        .modelContainer(container)
    }
}
