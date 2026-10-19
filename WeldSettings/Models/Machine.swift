import Foundation
import SwiftData

/// A welder on the bench, named by the person who owns it.
///
/// The name is free text and always will be. Every settings app on the store today is published
/// by a machine manufacturer and covers that manufacturer's own product line, which is no use at
/// all to a shop with a wire feeder from one company, a TIG from another and a stick box older
/// than the apprentice. This app ships no brand list, so "the blue one", "Dad's buzz box" and a
/// model number all work equally well — and the app stays out of anyone's trademark.
@Model
final class Machine {
    var id: UUID = UUID()
    var name: String = ""
    /// What it is, in the owner's words: "200 A inverter, spool gun", "AC/DC TIG with a pedal".
    var detail: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Preset.machine)
    var presets: [Preset]? = nil

    init(name: String = "", detail: String = "") {
        self.id = UUID()
        self.name = name
        self.detail = detail
        self.createdAt = .now
    }

    var displayName: String { name.isEmpty ? "Unnamed machine" : name }

    var sortedPresets: [Preset] {
        (presets ?? []).sorted { $0.updatedAt > $1.updatedAt }
    }
}

/// A setting that actually worked, on a named machine.
///
/// This is the part a manufacturer's calculator structurally cannot do. Their chart knows their
/// machine and nothing about yours: not the ground lead you are using, not the liner, not that
/// the feeder reads 20% low on the bottom half of the dial. A preset is the welder's own answer
/// to "what did I set it to last time it came out right", kept per machine, and it is the reason
/// this app is worth paying for.
@Model
final class Preset {
    var id: UUID = UUID()
    var name: String = ""

    // The bench selection this preset was saved from.
    var processRaw: String = WeldProcess.mig.rawValue
    var materialRaw: String = BaseMaterial.mildSteel.rawValue
    var thicknessMM: Double = 3.0
    var jointRaw: String = JointType.fillet.rawValue
    var positionRaw: String = WeldPosition.flat.rawValue
    var electrodeRaw: String = StickElectrode.e7018.rawValue

    // What the welder actually dialled in. Zero means "not recorded", which is honest for a
    // machine whose dial has no numbers on it at all.
    var amps: Double = 0
    var volts: Double = 0
    var wireFeedIPM: Double = 0
    var gasFlowCFH: Double = 0
    /// Free text, because the spool label is the truth: "0.030 ER70S-6", "3/32 lanthanated".
    var consumable: String = ""
    var gas: String = ""
    var polarityRaw: String = Polarity.dcep.rawValue
    var notes: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var machine: Machine? = nil

    init(name: String = "", selection: WeldSelection = WeldSelection()) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.updatedAt = .now
        apply(selection)
    }

    var process: WeldProcess {
        get { WeldProcess(rawValue: processRaw) ?? .mig }
        set { processRaw = newValue.rawValue }
    }

    var material: BaseMaterial {
        get { BaseMaterial(rawValue: materialRaw) ?? .mildSteel }
        set { materialRaw = newValue.rawValue }
    }

    var joint: JointType {
        get { JointType(rawValue: jointRaw) ?? .fillet }
        set { jointRaw = newValue.rawValue }
    }

    var position: WeldPosition {
        get { WeldPosition(rawValue: positionRaw) ?? .flat }
        set { positionRaw = newValue.rawValue }
    }

    var electrode: StickElectrode {
        get { StickElectrode(rawValue: electrodeRaw) ?? .e7018 }
        set { electrodeRaw = newValue.rawValue }
    }

    var polarity: Polarity {
        get { Polarity(rawValue: polarityRaw) ?? .dcep }
        set { polarityRaw = newValue.rawValue }
    }

    var selection: WeldSelection {
        WeldSelection(process: process, material: material, thicknessMM: thicknessMM,
                      joint: joint, position: position, electrode: electrode)
    }

    func apply(_ selection: WeldSelection) {
        process = selection.process
        material = selection.material
        thicknessMM = selection.thicknessMM
        joint = selection.joint
        position = selection.position
        electrode = selection.electrode
    }

    var displayName: String { name.isEmpty ? selection.headline : name }

    /// The one line that goes on a printed card and in a list row: the numbers that were set.
    var settingsSummary: String {
        var parts: [String] = []
        if amps > 0 { parts.append("\(Int(amps.rounded())) A") }
        if volts > 0 { parts.append(String(format: "%.1f V", volts)) }
        if wireFeedIPM > 0 { parts.append("\(Int(wireFeedIPM.rounded())) ipm") }
        if gasFlowCFH > 0 { parts.append("\(Int(gasFlowCFH.rounded())) CFH") }
        if !consumable.isEmpty { parts.append(consumable) }
        return parts.isEmpty ? "No numbers recorded yet" : parts.joined(separator: "  ·  ")
    }

    /// Whether anything was actually written down, which decides whether the preset earns its
    /// place or is just a saved selection.
    var hasNumbers: Bool { amps > 0 || volts > 0 || wireFeedIPM > 0 }
}
