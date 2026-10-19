import SwiftUI
import SwiftData

/// Saving what actually worked.
///
/// The starting point comes from the card; this is where the welder writes down where they ended
/// up. The two are kept side by side on purpose, because the gap between them is the useful part:
/// a feeder that reads twenty amps low is a fact about that machine and nothing else will tell
/// you about it.
struct PresetEditorView: View {
    let preset: Preset?
    let selection: WeldSelection
    let recommendation: WeldRecommendation

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \Machine.name) private var machines: [Machine]

    @State private var name = ""
    @State private var machineID: UUID?
    @State private var amps = ""
    @State private var volts = ""
    @State private var wireFeed = ""
    @State private var gasFlow = ""
    @State private var consumable = ""
    @State private var gas = ""
    @State private var polarity: Polarity = .dcep
    @State private var notes = ""
    @State private var addingMachine: Machine?
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name it — \"my TIG, 16 ga stainless, fillet\"", text: $name, axis: .vertical)
                        .focused($nameFocused)
                    Picker("Machine", selection: $machineID) {
                        Text("Not on a machine").tag(UUID?.none)
                        ForEach(machines) { machine in
                            Text(machine.displayName).tag(UUID?.some(machine.id))
                        }
                    }
                    Button {
                        let machine = Machine()
                        context.insert(machine)
                        try? context.save()
                        machineID = machine.id
                        addingMachine = machine
                    } label: {
                        Label("Add a machine", systemImage: "plus.circle")
                    }
                } header: {
                    Text("The preset")
                } footer: {
                    Text("The machine is whatever you call it on the bench. The app ships no brand list and is not connected to any manufacturer.")
                }

                Section {
                    LabeledContent("Job", value: selection.headline)
                    LabeledContent("Position", value: selection.position.name)
                    LabeledContent("Starting point", value: recommendation.ampsText)
                } header: {
                    Text("What the card said")
                } footer: {
                    Text("Saved with the preset so you can see later how far off the starting point your machine actually runs.")
                }

                Section {
                    numberField("Amps", text: $amps, suffix: "A")
                    if selection.process == .mig {
                        numberField("Volts", text: $volts, suffix: "V")
                        numberField("Wire speed", text: $wireFeed, suffix: "ipm")
                    }
                    if selection.process != .stick {
                        numberField("Gas flow", text: $gasFlow, suffix: "CFH")
                    }
                    TextField(consumablePlaceholder, text: $consumable, axis: .vertical)
                    if selection.process != .stick {
                        TextField("Gas mix", text: $gas, axis: .vertical)
                    }
                    Picker("Polarity", selection: $polarity) {
                        ForEach(Polarity.allCases) { Text($0.shortName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("What you set it to")
                } footer: {
                    Text("Leave anything blank that the machine has no number for. A dial marked one to ten is still worth writing down in the notes.")
                }

                Section("Notes") {
                    TextField("What made it come out right", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(preset == nil ? "Save a preset" : "Edit preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold() }
            }
            .sheet(item: $addingMachine) { MachineEditorView(machine: $0) }
            .onAppear(perform: load)
        }
    }

    private var consumablePlaceholder: String {
        switch selection.process {
        case .mig: return "Wire — \"0.030 ER70S-6\""
        case .tig: return "Tungsten and rod — \"3/32 lanthanated, 1/8 ER308L\""
        case .stick: return "Rod — \"1/8 E7018\""
        }
    }

    private func numberField(_ label: String, text: Binding<String>, suffix: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField("—", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() {
        if let preset {
            name = preset.name
            machineID = preset.machine?.id
            amps = preset.amps > 0 ? trimmed(preset.amps) : ""
            volts = preset.volts > 0 ? trimmed(preset.volts) : ""
            wireFeed = preset.wireFeedIPM > 0 ? trimmed(preset.wireFeedIPM) : ""
            gasFlow = preset.gasFlowCFH > 0 ? trimmed(preset.gasFlowCFH) : ""
            consumable = preset.consumable
            gas = preset.gas
            polarity = preset.polarity
            notes = preset.notes
        } else {
            name = selection.headline
            // Pre-fill with the middle of the recommended range: most welders start there and
            // nudge, and an empty field invites nothing being written down at all.
            amps = String((recommendation.ampsLow + recommendation.ampsHigh) / 2)
            polarity = recommendation.polarity
            gas = recommendation.lines.first { $0.label == "Gas" }?.value ?? ""
            consumable = recommendation.lines.first { $0.label == "Wire" || $0.label == "Electrode" }?.value ?? ""
            machineID = machines.first?.id
            nameFocused = false
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }

    private func save() {
        let target = preset ?? Preset(name: name, selection: selection)
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.apply(selection)
        target.machine = machines.first { $0.id == machineID }
        target.amps = Double(amps) ?? 0
        target.volts = Double(volts) ?? 0
        target.wireFeedIPM = Double(wireFeed) ?? 0
        target.gasFlowCFH = Double(gasFlow) ?? 0
        target.consumable = consumable
        target.gas = gas
        target.polarity = polarity
        target.notes = notes
        target.updatedAt = .now
        if preset == nil { context.insert(target) }
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}

/// A machine is a name and a sentence. Nothing else, on purpose.
struct MachineEditorView: View {
    let machine: Machine

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var detail = ""
    @State private var notes = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What you call it", text: $name)
                        .focused($nameFocused)
                    TextField("What it is — \"200 A inverter, spool gun\"", text: $detail, axis: .vertical)
                } header: {
                    Text("Machine")
                } footer: {
                    Text("Type whatever you actually call it. Weld Settings is independent and is not affiliated with any welding machine manufacturer, so it ships no list of makes and models to pick from.")
                }

                Section("Notes") {
                    TextField("Quirks worth remembering — \"feeder reads low under 100 A\"", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(machine.name.isEmpty ? "New machine" : "Edit machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if machine.name.isEmpty && machine.detail.isEmpty { context.delete(machine) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        machine.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        machine.detail = detail
                        machine.notes = notes
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                name = machine.name
                detail = machine.detail
                notes = machine.notes
                nameFocused = machine.name.isEmpty
            }
        }
    }
}
