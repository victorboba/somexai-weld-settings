import SwiftUI
import SwiftData

@main
struct WeldSettings: App {
    @State private var entitlements = EntitlementStore()
    private let container: ModelContainer

    init() {
        #if DEBUG
        // `-resetData` has to clear the bench's own defaults too, and it has to happen before any
        // view reads them, or a UI test inherits whatever the last run left the selector on.
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            let defaults = UserDefaults.standard
            for key in ["bench.process", "bench.material", "bench.thickness", "bench.joint",
                        "bench.position", "bench.electrode", "bench.unit",
                        "review.successCount", "review.lastPromptedVersion"] {
                defaults.removeObject(forKey: key)
            }
        }
        #endif
        let schema = Schema([Machine.self, Preset.self, JobEntry.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: AppConfig.iCloudSyncEnabled ? .automatic : .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
        }
        .modelContainer(container)
    }
}
