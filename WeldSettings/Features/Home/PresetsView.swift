import SwiftUI
import SwiftData

/// Saved settings, grouped by the machine they belong to.
///
/// The grouping is the whole point. A manufacturer's calculator gives one answer for its own
/// product line; a shop with three machines needs three answers, and only the person standing in
/// front of them knows which is which. The machine is a name the user types, never a brand the
/// app ships.
struct PresetsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Machine.name) private var machines: [Machine]
    @Query(sort: \Preset.updatedAt, order: .reverse) private var presets: [Preset]

    @State private var showingSettings = false
    @State private var editingMachine: Machine?
    @State private var editingPreset: Preset?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var unassigned: [Preset] { presets.filter { $0.machine == nil } }

    var body: some View {
        NavigationStack {
            Group {
                if presets.isEmpty && machines.isEmpty {
                    ContentUnavailableView {
                        Label("No presets yet", systemImage: "tray.full")
                    } description: {
                        Text("Set the bench to a job you run often, then tap Save as a preset. Presets live under the machine you ran them on, so a shop with three machines keeps three sets of numbers.")
                    } actions: {
                        Button("Add a machine") { addMachine() }
                            .buttonStyle(.borderedProminent)
                            .tint(.weldArc)
                    }
                } else {
                    List {
                        ForEach(machines) { machine in
                            Section {
                                if machine.sortedPresets.isEmpty {
                                    Text("No presets saved on this machine yet. Set the bench up and tap Save as a preset.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(machine.sortedPresets) { preset in
                                        Button { editingPreset = preset } label: { PresetRow(preset: preset) }
                                            .buttonStyle(.plain)
                                    }
                                    .onDelete { offsets in delete(offsets.map { machine.sortedPresets[$0] }) }
                                }
                            } header: {
                                HStack {
                                    Text(machine.displayName)
                                    Spacer()
                                    Button("Edit") { editingMachine = machine }
                                        .font(.caption)
                                }
                            } footer: {
                                VStack(alignment: .leading, spacing: 4) {
                                    if !machine.detail.isEmpty {
                                        Text(machine.detail)
                                    }
                                    if !machine.sortedPresets.isEmpty {
                                        Button {
                                            exportCard(for: machine)
                                        } label: {
                                            Label("Setting card for the cabinet door (PDF)", systemImage: "doc.richtext")
                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        }

                        if !unassigned.isEmpty {
                            Section {
                                ForEach(unassigned) { preset in
                                    Button { editingPreset = preset } label: { PresetRow(preset: preset) }
                                        .buttonStyle(.plain)
                                }
                                .onDelete { offsets in delete(offsets.map { unassigned[$0] }) }
                            } header: {
                                Text("Not on a machine")
                            } footer: {
                                Text("Open one and pick a machine to file it.")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BenchToolbar(showingSettings: $showingSettings)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { addMachine() } label: { Label("Add a machine", systemImage: "plus") }
                        if !presets.isEmpty {
                            Button { exportCSV() } label: { Label("Every preset as CSV", systemImage: "tablecells") }
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editingMachine) { MachineEditorView(machine: $0) }
            .sheet(item: $editingPreset) { preset in
                PresetEditorView(preset: preset, selection: preset.selection,
                                 recommendation: WeldAdvisor.recommend(for: preset.selection))
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private func addMachine() {
        let machine = Machine()
        context.insert(machine)
        try? context.save()
        editingMachine = machine
    }

    private func delete(_ toDelete: [Preset]) {
        for preset in toDelete { context.delete(preset) }
        try? context.save()
    }

    private func exportCard(for machine: Machine) {
        do { exportFile = ExportFile(url: try PDFExporter.exportSettingCard(for: machine)) }
        catch { exportError = error.localizedDescription }
    }

    private func exportCSV() {
        do { exportFile = ExportFile(url: try CSVExporter.exportPresets(presets)) }
        catch { exportError = error.localizedDescription }
    }
}

private struct PresetRow: View {
    let preset: Preset

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(preset.displayName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(preset.selection.headline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(preset.settingsSummary)
                .font(.subheadline.weight(preset.hasNumbers ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(preset.hasNumbers ? Color.weldArc : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
