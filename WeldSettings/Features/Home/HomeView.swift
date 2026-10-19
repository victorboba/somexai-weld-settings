import SwiftUI
import SwiftData

/// Three places to be, and the first one is not a list.
///
/// Most logging apps open on a list with a plus button. This one opens on a **bench**: a selector
/// that resolves into a settings card, the way a welder actually starts — process, metal,
/// thickness, joint, position, and then the numbers. The list screens are where the app remembers
/// what worked, which is the part a machine manufacturer's calculator cannot do across brands.
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Query private var jobs: [JobEntry]
    @Query private var presets: [Preset]

    @State private var tab: Tab = .bench
    /// Set by the Siri shortcut and by the bench's "Log this weld" button. Presented as a sheet
    /// from right here, rather than handed down to `JobsView` as a binding it watches with
    /// `onChange` — that watcher only fires once `JobsView` has actually observed a transition,
    /// and a `TabView` page that has not been visited yet can miss the very first one.
    @State private var pendingJobSelection: WeldSelection?

    enum Tab: Hashable { case bench, presets, jobs }

    var body: some View {
        TabView(selection: $tab) {
            BenchView(logWeld: { selection in
                tab = .jobs
                pendingJobSelection = selection
            })
            .tabItem { Label("Bench", systemImage: "slider.horizontal.3") }
            .tag(Tab.bench)

            PresetsView()
                .tabItem { Label("Presets", systemImage: "tray.full") }
                .tag(Tab.presets)

            JobsView()
                .tabItem { Label("Job log", systemImage: "book.closed") }
                .tag(Tab.jobs)
        }
        .tint(.weldArc)
        .sheet(item: Binding(get: { pendingJobSelection.map(PendingSelectionBox.init) },
                             set: { pendingJobSelection = $0?.selection })) { box in
            JobEditorView(job: nil, selection: box.selection)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-resetData") {
                try? context.delete(model: JobEntry.self)
                try? context.delete(model: Preset.self)
                try? context.delete(model: Machine.self)
            }
            if ProcessInfo.processInfo.arguments.contains("-sampleData"), jobs.isEmpty {
                SampleData.insert(into: context)
            }
            #endif
        }
        .onChange(of: jobs.count, initial: true) { WidgetSync.update(jobs: jobs, presets: presets) }
        .onChange(of: presets.count) { WidgetSync.update(jobs: jobs, presets: presets) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            let defaults = WidgetSnapshot.defaults
            guard defaults.bool(forKey: LogEntryIntent.pendingKey) else { return }
            defaults.removeObject(forKey: LogEntryIntent.pendingKey)
            tab = .jobs
            pendingJobSelection = WeldSelection()
        }
    }
}

/// A `WeldSelection` is a value, and `.sheet(item:)` wants an identity, so it gets one.
private struct PendingSelectionBox: Identifiable {
    let selection: WeldSelection
    var id: String { selection.headline }
}

extension Color {
    /// The accent: the orange of an arc seen through a dark lens. Deliberately not the blue that
    /// half this portfolio uses.
    static let weldArc = Color(red: 1.0, green: 0.54, blue: 0.17)
    /// The steel the bench panel is cut from.
    static let weldSteel = Color(red: 0.17, green: 0.18, blue: 0.21)
}

/// The gear and the question mark, identical on all three tabs so they are always in the same
/// place. Rule 6: the How-To guide is reachable from the home screen, not buried.
struct BenchToolbar: ToolbarContent {
    @Binding var showingSettings: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink { HowToView() } label: {
                Label("How do I use this app?", systemImage: "questionmark.circle")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingSettings = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
