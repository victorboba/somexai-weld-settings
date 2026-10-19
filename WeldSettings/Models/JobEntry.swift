import Foundation
import SwiftData

/// How it came out. Three honest options, because "it worked" and "it worked after I moved it"
/// are different facts and only the second one teaches you anything.
enum JobOutcome: String, CaseIterable, Identifiable, Codable {
    case firstTry, tuned, redone

    var id: String { rawValue }

    var name: String {
        switch self {
        case .firstTry: return "Right first try"
        case .tuned: return "Tuned it in"
        case .redone: return "Had to redo it"
        }
    }

    var symbol: String {
        switch self {
        case .firstTry: return "checkmark.circle.fill"
        case .tuned: return "dial.medium.fill"
        case .redone: return "arrow.counterclockwise.circle.fill"
        }
    }
}

/// One weld, on one job, at the settings that were actually on the machine.
///
/// The job log is what turns a lookup table into something worth keeping. A chart tells you where
/// to start; the log tells you where you ended up on this metal, on this machine, in this
/// position — with a photo of the bead, which is the only record that survives the argument about
/// whether it looked right.
@Model
final class JobEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    /// What was welded: "trailer fender bracket", "handrail return", "exhaust patch".
    var title: String = ""
    var machineName: String = ""

    var processRaw: String = WeldProcess.mig.rawValue
    var materialRaw: String = BaseMaterial.mildSteel.rawValue
    var thicknessMM: Double = 3.0
    var jointRaw: String = JointType.fillet.rawValue
    var positionRaw: String = WeldPosition.flat.rawValue
    var electrodeRaw: String = StickElectrode.e7018.rawValue

    var amps: Double = 0
    var volts: Double = 0
    var wireFeedIPM: Double = 0
    var gasFlowCFH: Double = 0
    var consumable: String = ""
    var gas: String = ""
    var polarityRaw: String = Polarity.dcep.rawValue

    var outcomeRaw: String = JobOutcome.firstTry.rawValue
    var notes: String = ""

    /// A photo of the finished bead. Rule 14: this is `PhotoField`, downscaled before storage.
    @Attribute(.externalStorage) var photoData: Data? = nil

    var createdAt: Date = Date()

    init(date: Date = .now, title: String = "", selection: WeldSelection = WeldSelection()) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.createdAt = .now
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

    var outcome: JobOutcome {
        get { JobOutcome(rawValue: outcomeRaw) ?? .firstTry }
        set { outcomeRaw = newValue.rawValue }
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

    var displayTitle: String { title.isEmpty ? selection.headline : title }

    var day: Date { Calendar.current.startOfDay(for: date) }

    var settingsSummary: String {
        var parts: [String] = []
        if amps > 0 { parts.append("\(Int(amps.rounded())) A") }
        if volts > 0 { parts.append(String(format: "%.1f V", volts)) }
        if wireFeedIPM > 0 { parts.append("\(Int(wireFeedIPM.rounded())) ipm") }
        if gasFlowCFH > 0 { parts.append("\(Int(gasFlowCFH.rounded())) CFH") }
        return parts.isEmpty ? "No numbers recorded" : parts.joined(separator: "  ·  ")
    }

    /// The job line as it reads on a printed record: metal, thickness, joint, position.
    var jobSummary: String {
        "\(material.name) · \(Thickness.formatMM(thicknessMM)) · \(joint.name.lowercased()) · \(position.name.lowercased())"
    }
}
