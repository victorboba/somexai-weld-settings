import SwiftUI
import SwiftData

/// Recording one weld: the job, the metal, the numbers that were on the machine, how it came out,
/// and a photo of the bead.
struct JobEditorView: View {
    let job: JobEntry?
    let selection: WeldSelection

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \Machine.name) private var machines: [Machine]
    @Query(sort: \Preset.updatedAt, order: .reverse) private var presets: [Preset]

    @State private var date = Date.now
    @State private var title = ""
    @State private var machineName = ""
    @State private var working = WeldSelection()
    @State private var amps = ""
    @State private var volts = ""
    @State private var wireFeed = ""
    @State private var gasFlow = ""
    @State private var consumable = ""
    @State private var gas = ""
    @State private var polarity: Polarity = .dcep
    @State private var outcome: JobOutcome = .firstTry
    @State private var notes = ""
    @State private var photoData: Data?
    @FocusState private var titleFocused: Bool

    private var recommendation: WeldRecommendation { WeldAdvisor.recommend(for: working) }

    var body: some View {
        NavigationStack {
            Form {
                Section("The job") {
                    DatePicker("When", selection: $date)
                    TextField("What did you weld?", text: $title, axis: .vertical)
                        .focused($titleFocused)
                    if machines.isEmpty {
                        TextField("Which machine", text: $machineName)
                    } else {
                        Picker("Machine", selection: $machineName) {
                            Text("Not recorded").tag("")
                            ForEach(machines) { machine in
                                Text(machine.displayName).tag(machine.displayName)
                            }
                        }
                    }
                }

                Section {
                    Picker("Process", selection: $working.process) {
                        ForEach(WeldProcess.allCases) { Text($0.shortName).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metal").font(.caption).foregroundStyle(.secondary)
                        ChoiceChips(options: BaseMaterial.allCases, selection: $working.material,
                                    title: { $0.name }, tint: { _ in Color.weldArc })
                    }

                    LabeledContent("Thickness") {
                        Text(Thickness.describe(working.thicknessMM, material: working.material, preferring: .millimetre))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Slider(value: thicknessIndex, in: 0...Double(Thickness.steps.count - 1), step: 1) {
                        Text("Thickness")
                    }
                    .tint(.weldArc)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Joint").font(.caption).foregroundStyle(.secondary)
                        ChoiceChips(options: JointType.allCases, selection: $working.joint,
                                    title: { $0.name }, tint: { _ in Color.weldArc })
                        Text("Position").font(.caption).foregroundStyle(.secondary)
                        ChoiceChips(options: WeldPosition.allCases, selection: $working.position,
                                    title: { $0.name }, tint: { _ in Color.weldArc })
                    }
                } header: {
                    Text("The metal")
                } footer: {
                    Text("Starting point for this combination: \(recommendation.ampsText), \(recommendation.polarity.shortName).")
                }

                Section {
                    numberField("Amps", text: $amps, suffix: "A")
                    if working.process == .mig {
                        numberField("Volts", text: $volts, suffix: "V")
                        numberField("Wire speed", text: $wireFeed, suffix: "ipm")
                    }
                    if working.process != .stick {
                        numberField("Gas flow", text: $gasFlow, suffix: "CFH")
                    }
                    TextField("Wire, rod or electrode", text: $consumable, axis: .vertical)
                    Picker("Polarity", selection: $polarity) {
                        ForEach(Polarity.allCases) { Text($0.shortName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if !presets.isEmpty {
                        Menu {
                            ForEach(presets.filter(\.hasNumbers)) { preset in
                                Button(preset.displayName) { fill(from: preset) }
                            }
                        } label: {
                            Label("Fill from a preset", systemImage: "tray.and.arrow.up")
                        }
                    }
                } header: {
                    Text("What was on the machine")
                } footer: {
                    Text("Write down what you actually ran, not what the card suggested. The difference between the two is the useful part.")
                }

                Section {
                    ChoiceChips(options: JobOutcome.allCases, selection: $outcome,
                                title: { $0.name }, tint: { _ in Color.weldArc })
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("How it came out")
                }

                Section {
                    PhotoField(data: $photoData, label: "Photo of the bead")
                } header: {
                    Text("The bead")
                } footer: {
                    Text("A photo settles the argument about whether it looked right. It is stored on this device and goes nowhere unless you export it.")
                }
            }
            .navigationTitle(job == nil ? "Log a weld" : "Edit weld")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold() }
            }
            .onAppear(perform: load)
            .onChange(of: working.material) { working.normalise() }
        }
    }

    private var thicknessIndex: Binding<Double> {
        Binding(
            get: {
                let nearest = Thickness.steps.enumerated()
                    .min { abs($0.element - working.thicknessMM) < abs($1.element - working.thicknessMM) }
                return Double(nearest?.offset ?? 0)
            },
            set: { working.thicknessMM = Thickness.steps[min(Thickness.steps.count - 1, max(0, Int($0.rounded())))] })
    }

    private func numberField(_ label: String, text: Binding<String>, suffix: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField("—", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text(suffix).foregroundStyle(.secondary)
            }
        }
    }

    private func fill(from preset: Preset) {
        working = preset.selection
        if preset.amps > 0 { amps = trimmed(preset.amps) }
        if preset.volts > 0 { volts = trimmed(preset.volts) }
        if preset.wireFeedIPM > 0 { wireFeed = trimmed(preset.wireFeedIPM) }
        if preset.gasFlowCFH > 0 { gasFlow = trimmed(preset.gasFlowCFH) }
        if !preset.consumable.isEmpty { consumable = preset.consumable }
        if !preset.gas.isEmpty { gas = preset.gas }
        polarity = preset.polarity
        if machineName.isEmpty, let machine = preset.machine { machineName = machine.displayName }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }

    private func load() {
        if let job {
            date = job.date
            title = job.title
            machineName = job.machineName
            working = job.selection
            amps = job.amps > 0 ? trimmed(job.amps) : ""
            volts = job.volts > 0 ? trimmed(job.volts) : ""
            wireFeed = job.wireFeedIPM > 0 ? trimmed(job.wireFeedIPM) : ""
            gasFlow = job.gasFlowCFH > 0 ? trimmed(job.gasFlowCFH) : ""
            consumable = job.consumable
            gas = job.gas
            polarity = job.polarity
            outcome = job.outcome
            notes = job.notes
            photoData = job.photoData
        } else {
            working = selection
            polarity = WeldAdvisor.recommend(for: selection).polarity
            amps = String((recommendation.ampsLow + recommendation.ampsHigh) / 2)
            machineName = machines.first?.displayName ?? ""
            titleFocused = true
        }
    }

    private func save() {
        let target = job ?? JobEntry(date: date, title: title, selection: working)
        target.date = date
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.machineName = machineName
        target.apply(working)
        target.amps = Double(amps) ?? 0
        target.volts = Double(volts) ?? 0
        target.wireFeedIPM = Double(wireFeed) ?? 0
        target.gasFlowCFH = Double(gasFlow) ?? 0
        target.consumable = consumable
        target.gas = gas
        target.polarity = polarity
        target.outcome = outcome
        target.notes = notes
        target.photoData = photoData
        if job == nil { context.insert(target) }
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}
