import Foundation
import WidgetKit

enum WidgetSync {
    /// Recomputes the widget summary and reloads timelines.
    static func update(jobs: [JobEntry], presets: [Preset]) {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let latest = jobs.max { $0.date < $1.date }
        var snapshot = WidgetSnapshot()
        snapshot.totalJobs = jobs.count
        snapshot.jobsThisWeek = jobs.filter { $0.date >= weekAgo }.count
        snapshot.presetCount = presets.count
        snapshot.lastJobTitle = latest?.displayTitle
        snapshot.lastJobSettings = latest?.settingsSummary
        snapshot.lastJobMachine = latest?.machineName
        snapshot.lastJobDate = latest?.date
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
