import SwiftUI
import SwiftData

/// The bench. A selector that resolves into a settings card.
///
/// This is the home screen and it is deliberately not a list with a plus button. A welder walking
/// up to an unfamiliar job answers five questions — what process, what metal, how thick, what
/// joint, what position — and wants a number. So the screen asks those five and shows the number,
/// live, as the answers change. The process is the top-level choice because it changes what the
/// screen asks for: stick wants to know the rod, TIG wants to know nothing about wire speed, and
/// MIG wants both.
struct BenchView: View {
    /// Hands the current selection to the job log so a weld can be recorded at these settings.
    var logWeld: (WeldSelection) -> Void

    @AppStorage("bench.process") private var processRaw = WeldProcess.mig.rawValue
    @AppStorage("bench.material") private var materialRaw = BaseMaterial.mildSteel.rawValue
    @AppStorage("bench.thickness") private var thicknessMM = 3.0
    @AppStorage("bench.joint") private var jointRaw = JointType.fillet.rawValue
    @AppStorage("bench.position") private var positionRaw = WeldPosition.flat.rawValue
    @AppStorage("bench.electrode") private var electrodeRaw = StickElectrode.e7018.rawValue
    @AppStorage("bench.unit") private var unitRaw = ThicknessUnit.millimetre.rawValue

    @State private var showingSettings = false
    @State private var savingPreset = false
    @State private var expandedLines: Set<String> = []
    @State private var showingDiagnostics = false

    private var selection: WeldSelection {
        var value = WeldSelection(
            process: WeldProcess(rawValue: processRaw) ?? .mig,
            material: BaseMaterial(rawValue: materialRaw) ?? .mildSteel,
            thicknessMM: thicknessMM,
            joint: JointType(rawValue: jointRaw) ?? .fillet,
            position: WeldPosition(rawValue: positionRaw) ?? .flat,
            electrode: StickElectrode(rawValue: electrodeRaw) ?? .e7018)
        value.normalise()
        return value
    }

    private var unit: ThicknessUnit { ThicknessUnit(rawValue: unitRaw) ?? .millimetre }
    private var recommendation: WeldRecommendation { WeldAdvisor.recommend(for: selection) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    processPicker
                    metalCard
                    if selection.process == .stick { rodCard }
                    jointCard
                    settingsCard
                    diagnosticsCard
                    techniqueCard
                    cautionsCard
                    actions
                    affiliationNote
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bench")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { BenchToolbar(showingSettings: $showingSettings) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $savingPreset) {
                PresetEditorView(preset: nil, selection: selection, recommendation: recommendation)
            }
        }
    }

    // MARK: - Process

    private var processPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Process")
            HStack(spacing: 10) {
                ForEach(WeldProcess.allCases) { process in
                    Button {
                        processRaw = process.rawValue
                        // Keep the rod the welder picked unless it is not made for this metal.
                        if !StickElectrode.available(for: selection.material).contains(selection.electrode) {
                            electrodeRaw = StickElectrode.default(for: selection.material).rawValue
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: process.symbol)
                                .font(.title3)
                            Text(process.shortName)
                                .font(.headline)
                            Text(process.name.replacingOccurrences(of: "\(process.shortName) ", with: ""))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selection.process == process ? Color.weldArc.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(selection.process == process ? Color.weldArc : .clear, lineWidth: 2)
                        )
                        .foregroundStyle(selection.process == process ? Color.weldArc : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("process-\(process.rawValue)")
                    .accessibilityAddTraits(selection.process == process ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    // MARK: - Metal and thickness

    private var metalCard: some View {
        card {
            sectionLabel("Metal")
            ChoiceChips(options: BaseMaterial.allCases,
                        selection: Binding(get: { selection.material },
                                           set: { newValue in
                                               materialRaw = newValue.rawValue
                                               if !StickElectrode.available(for: newValue).contains(selection.electrode) {
                                                   electrodeRaw = StickElectrode.default(for: newValue).rawValue
                                               }
                                           }),
                        title: { $0.name },
                        tint: { _ in Color.weldArc })

            Divider().padding(.vertical, 2)

            HStack {
                sectionLabel("Thickness")
                Spacer()
                Picker("Unit", selection: Binding(get: { unit }, set: { unitRaw = $0.rawValue })) {
                    ForEach(ThicknessUnit.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }

            if unit == .gauge {
                gaugePicker
            } else {
                thicknessSlider
            }

            Text(Thickness.describe(thicknessMM, material: selection.material, preferring: unit))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.weldArc)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("thicknessReadout")

            Text(selection.material.gaugeStandardName + ". Sixteen gauge is a different thickness in each of the three, which is why the app converts rather than assuming.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var thicknessSlider: some View {
        let index = Binding<Double>(
            get: {
                let steps = Thickness.steps
                let nearest = steps.enumerated().min { abs($0.element - thicknessMM) < abs($1.element - thicknessMM) }
                return Double(nearest?.offset ?? 0)
            },
            set: { thicknessMM = Thickness.steps[min(Thickness.steps.count - 1, max(0, Int($0.rounded())))] })
        return VStack(spacing: 4) {
            Slider(value: index, in: 0...Double(Thickness.steps.count - 1), step: 1) {
                Text("Thickness")
            } minimumValueLabel: {
                Text(Thickness.formatMM(Thickness.steps.first ?? 0)).font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(Thickness.formatMM(Thickness.steps.last ?? 0)).font(.caption2).foregroundStyle(.secondary)
            }
            .tint(.weldArc)
            .accessibilityIdentifier("thicknessSlider")
        }
    }

    private var gaugePicker: some View {
        Picker("Gauge", selection: Binding<Int>(
            get: { Thickness.nearestGauge(millimetres: thicknessMM, material: selection.material) ?? 16 },
            set: { gauge in
                if let mm = Thickness.millimetres(gauge: gauge, material: selection.material) {
                    thicknessMM = mm
                }
            })) {
                ForEach(Thickness.gaugeNumbers(for: selection.material), id: \.self) { gauge in
                    let mm = Thickness.millimetres(gauge: gauge, material: selection.material) ?? 0
                    Text("\(gauge) gauge — \(Thickness.formatMM(mm))").tag(gauge)
                }
            }
            .pickerStyle(.menu)
            .tint(.weldArc)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rod (stick only)

    private var rodCard: some View {
        card {
            sectionLabel("Electrode")
            ChoiceChips(options: StickElectrode.available(for: selection.material),
                        selection: Binding(get: { selection.electrode },
                                           set: { electrodeRaw = $0.rawValue }),
                        title: { $0.name },
                        tint: { _ in Color.weldArc })
            Text(selection.electrode.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Joint and position

    private var jointCard: some View {
        card {
            sectionLabel("Joint")
            ChoiceChips(options: JointType.allCases,
                        selection: Binding(get: { selection.joint }, set: { jointRaw = $0.rawValue }),
                        title: { $0.name },
                        tint: { _ in Color.weldArc })
            Divider().padding(.vertical, 2)
            sectionLabel("Position")
            ChoiceChips(options: WeldPosition.allCases,
                        selection: Binding(get: { selection.position }, set: { positionRaw = $0.rawValue }),
                        title: { $0.name },
                        tint: { _ in Color.weldArc })
        }
    }

    // MARK: - The card everything resolves to

    private var settingsCard: some View {
        let recommendation = self.recommendation
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Starting point")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Text(recommendation.ampsText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.weldArc)
                    .accessibilityIdentifier("amperageReadout")
                Text("\(recommendation.polarity.shortName) · \(selection.process.shortName) · \(selection.material.name)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cardSubtitle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.weldSteel)

            VStack(spacing: 0) {
                ForEach(recommendation.lines) { line in
                    settingRow(line)
                    if line.id != recommendation.lines.last?.id { Divider() }
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Polarity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(recommendation.polarity.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(recommendation.polarityNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func settingRow(_ line: SettingLine) -> some View {
        Button {
            if expandedLines.contains(line.id) { expandedLines.remove(line.id) }
            else { expandedLines.insert(line.id) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(line.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .accessibilityIdentifier(line.label.uppercased())
                    Spacer()
                    Image(systemName: expandedLines.contains(line.id) ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(line.value)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let alternate = line.alternate {
                    Text(alternate)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if expandedLines.contains(line.id) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.footnote)
                            .foregroundStyle(Color.weldArc)
                        Text(line.moveIt)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows which way to move this when the bead looks wrong")
    }

    // MARK: - Reading the bead

    private var diagnosticsCard: some View {
        card {
            Button { showingDiagnostics.toggle() } label: {
                HStack {
                    Label("If the bead looks wrong", systemImage: "eye")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showingDiagnostics ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showingDiagnostics {
                ForEach(BeadDiagnostics.symptoms(for: selection.process)) { symptom in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(symptom.symptom)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(symptom.cause)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(symptom.fix)
                            .font(.footnote)
                            .foregroundStyle(Color.weldArc)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            } else {
                Text("\(BeadDiagnostics.symptoms(for: selection.process).count) things that go wrong on \(selection.process.shortName), what causes each one, and which dial to move.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var techniqueCard: some View {
        card {
            sectionLabel("Technique")
            ForEach(Array(recommendation.technique.enumerated()), id: \.offset) { _, note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(Color.weldArc)
                        .padding(.top, 6)
                    Text(note)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var cautionsCard: some View {
        card {
            Label("Read this before you strike an arc", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            ForEach(Array(recommendation.cautions.enumerated()), id: \.offset) { _, caution in
                Text(caution)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                savingPreset = true
            } label: {
                Label("Save as a preset", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.weldArc)
            .controlSize(.large)

            Button {
                logWeld(selection)
            } label: {
                Label("Log this weld", systemImage: "book.closed")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var affiliationNote: some View {
        Text("Weld Settings is an independent app. It is not affiliated with, endorsed by or connected to any welding machine manufacturer, and it covers no manufacturer's product line in particular.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    // MARK: - Card chrome

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
