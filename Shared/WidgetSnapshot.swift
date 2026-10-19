import Foundation

/// A tiny summary the app writes to the shared App Group so the widget can render without
/// touching SwiftData. Updated whenever a weld is logged or a preset changes.
///
/// The widget shows the **last settings that worked**, because that is the thing a welder wants
/// at a glance when they walk back to a machine they used yesterday.
struct WidgetSnapshot: Codable {
    var totalJobs: Int = 0
    var jobsThisWeek: Int = 0
    var presetCount: Int = 0
    var lastJobTitle: String?
    var lastJobSettings: String?
    var lastJobMachine: String?
    var lastJobDate: Date?
    var updatedAt: Date = .now

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    static let placeholder = WidgetSnapshot(
        totalJobs: 38, jobsThisWeek: 4, presetCount: 9,
        lastJobTitle: "Trailer fender bracket",
        lastJobSettings: "145 A · 19.5 V · 250 ipm",
        lastJobMachine: "Bench feeder",
        lastJobDate: .now)
}
