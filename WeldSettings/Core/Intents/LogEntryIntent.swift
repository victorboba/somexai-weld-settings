import AppIntents
import Foundation

/// "Log a weld in Weld Settings" from Siri, Spotlight or the Shortcuts app. Opens the job log
/// ready to record one — which matters here because the phone is usually in a pocket under a
/// welding jacket and the gloves are still on.
struct LogEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Weld"
    static var description = IntentDescription("Opens the job log ready to record a weld.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.openNewEntry"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct WeldSettingsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogEntryIntent(),
            phrases: ["Log a weld in \(.applicationName)", "New weld in \(.applicationName)"],
            shortTitle: "Log Weld",
            systemImageName: "plus.circle"
        )
    }
}
