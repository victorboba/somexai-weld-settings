import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

/// The last settings that worked, which is what you want when you walk back to a machine you
/// used yesterday and cannot remember where you left the dial.
struct WeldSettingsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var arc: Color { Color(red: 1.0, green: 0.54, blue: 0.17) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Last weld")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let settings = entry.snapshot.lastJobSettings, entry.snapshot.totalJobs > 0 {
                Text(settings)
                    .font(family == .systemSmall ? .headline : .title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(arc)
                    .minimumScaleFactor(0.8)
                if let title = entry.snapshot.lastJobTitle {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                if family != .systemSmall {
                    if let machine = entry.snapshot.lastJobMachine, !machine.isEmpty {
                        Text(machine)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Divider()
                    Text("\(entry.snapshot.jobsThisWeek) this week · \(entry.snapshot.presetCount) presets")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let date = entry.snapshot.lastJobDate {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Nothing logged yet")
                    .font(.subheadline.weight(.semibold))
                Text("Open \(AppConfig.appName) and record what you ran.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct WeldSettingsWidget: Widget {
    let kind = "WeldSettingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            WeldSettingsWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("The settings from the last weld you logged.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WeldSettingsWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeldSettingsWidget()
    }
}
