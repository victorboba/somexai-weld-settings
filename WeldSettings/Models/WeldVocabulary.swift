import Foundation

/// The words a welder uses to describe a job, and nothing else.
///
/// Deliberately absent from this file, and from the whole app: the name of any machine
/// manufacturer. "Miller", "Lincoln", "ESAB", "Hobart" and "Fronius" are registered marks and
/// every settings app on the store today belongs to one of them and covers only that one line.
/// This app is written the other way round — by process and material — so a shop running three
/// different brands on the same bench has one reference instead of three. Where a machine has to
/// be named, the welder types the name; the app never ships a brand list.

// MARK: - Process

/// The three arc processes a mixed-fleet shop actually owns. Each asks the bench for a different
/// set of answers, which is why the process is the top-level choice rather than a filter.
enum WeldProcess: String, CaseIterable, Identifiable, Codable {
    case mig, tig, stick

    var id: String { rawValue }

    /// Short enough for a three-segment control (rule 18).
    var shortName: String {
        switch self {
        case .mig: return "MIG"
        case .tig: return "TIG"
        case .stick: return "Stick"
        }
    }

    var name: String {
        switch self {
        case .mig: return "MIG (GMAW)"
        case .tig: return "TIG (GTAW)"
        case .stick: return "Stick (SMAW)"
        }
    }

    var symbol: String {
        switch self {
        case .mig: return "bolt.fill"
        case .tig: return "flame.fill"
        case .stick: return "line.diagonal"
        }
    }

    /// What the consumable is called on this process. The card uses the welder's word, not a
    /// generic one: nobody asks what tungsten diameter to run in a wire feeder.
    var consumableNoun: String {
        switch self {
        case .mig: return "Wire"
        case .tig: return "Tungsten and filler"
        case .stick: return "Electrode"
        }
    }

    var usesShieldingGas: Bool { self != .stick }
    var usesWireFeed: Bool { self == .mig }
}

// MARK: - Material

enum BaseMaterial: String, CaseIterable, Identifiable, Codable {
    case mildSteel, stainless, aluminium

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mildSteel: return "Mild steel"
        case .stainless: return "Stainless"
        case .aluminium: return "Aluminium"
        }
    }

    /// How hard the metal pulls heat out of the puddle, relative to mild steel. Aluminium
    /// conducts heat roughly four times faster and needs noticeably more current for the same
    /// thickness; austenitic stainless conducts about a third as well as mild steel and runs
    /// cooler. These are the multipliers behind the amperage, not precise physics.
    var heatFactor: Double {
        switch self {
        case .mildSteel: return 1.0
        case .stainless: return 0.9
        case .aluminium: return 1.3
        }
    }

    /// Sheet gauge is not one table. Steel sheet uses the manufacturers' standard gauge,
    /// stainless uses the US standard gauge, and aluminium uses Brown and Sharpe. 16 gauge is
    /// three different thicknesses depending on which one you are holding, which is exactly the
    /// mistake this app exists to stop.
    var gaugeStandardName: String {
        switch self {
        case .mildSteel: return "Manufacturers' standard gauge (steel sheet)"
        case .stainless: return "US standard gauge (stainless sheet)"
        case .aluminium: return "Brown and Sharpe gauge (aluminium sheet)"
        }
    }
}

// MARK: - Joint and position

enum JointType: String, CaseIterable, Identifiable, Codable {
    case butt, lap, fillet, outsideCorner

    var id: String { rawValue }

    var name: String {
        switch self {
        case .butt: return "Butt"
        case .lap: return "Lap"
        case .fillet: return "Fillet or tee"
        case .outsideCorner: return "Outside corner"
        }
    }

    /// A fillet has two members pulling heat away from one puddle, so it takes more current than
    /// a butt in the same material. An outside corner has metal on one side only and burns
    /// through at settings a butt would shrug off.
    var heatFactor: Double {
        switch self {
        case .butt: return 1.0
        case .lap: return 1.05
        case .fillet: return 1.1
        case .outsideCorner: return 0.9
        }
    }

    var note: String {
        switch self {
        case .butt: return "Gap and prep decide as much as the dial does. Tack it, then check the root is open the same at both ends."
        case .lap: return "Aim two thirds at the bottom sheet, one third at the top edge, or the top edge melts away first."
        case .fillet: return "Two plates pull heat out of one puddle, so it runs hotter than a butt in the same metal. Work the toes, not the middle."
        case .outsideCorner: return "Metal on one side only. It burns through at settings a butt would shrug off — start at the bottom of the range."
        }
    }
}

enum WeldPosition: String, CaseIterable, Identifiable, Codable {
    case flat, horizontal, verticalUp, overhead

    var id: String { rawValue }

    var name: String {
        switch self {
        case .flat: return "Flat"
        case .horizontal: return "Horizontal"
        case .verticalUp: return "Vertical up"
        case .overhead: return "Overhead"
        }
    }

    /// Out of position the puddle has to be small enough that gravity does not win, so the
    /// current comes down. Vertical up and overhead take roughly ten to fifteen per cent off.
    var heatFactor: Double {
        switch self {
        case .flat: return 1.0
        case .horizontal: return 0.97
        case .verticalUp: return 0.87
        case .overhead: return 0.87
        }
    }

    var note: String {
        switch self {
        case .flat: return "Everything in the book is written for this position. Get it right flat before you chase it uphill."
        case .horizontal: return "The puddle wants to sag onto the bottom plate. Angle the torch up a few degrees and keep it moving."
        case .verticalUp: return "Lower current and a weave or a whip. If it runs away downhill you are too hot, not too slow."
        case .overhead: return "Lowest current, tightest arc, shortest stick-out. Everything that falls, falls on you — jacket buttoned, collar up."
        }
    }
}

// MARK: - Polarity

enum Polarity: String, CaseIterable, Identifiable, Codable {
    case dcep, dcen, ac

    var id: String { rawValue }

    /// Written the way it is printed on a machine's terminals, with the plain-English half
    /// after it, because half the shop calls it reverse polarity and half calls it DCEP.
    var name: String {
        switch self {
        case .dcep: return "DCEP (electrode positive, reverse)"
        case .dcen: return "DCEN (electrode negative, straight)"
        case .ac: return "AC"
        }
    }

    var shortName: String {
        switch self {
        case .dcep: return "DCEP"
        case .dcen: return "DCEN"
        case .ac: return "AC"
        }
    }
}

// MARK: - Units

enum ThicknessUnit: String, CaseIterable, Identifiable, Codable {
    case millimetre, inch, gauge

    var id: String { rawValue }

    var name: String {
        switch self {
        case .millimetre: return "mm"
        case .inch: return "inch"
        case .gauge: return "gauge"
        }
    }
}

enum FlowUnit: String, CaseIterable, Identifiable, Codable {
    case cfh, litresPerMinute

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cfh: return "CFH"
        case .litresPerMinute: return "L/min"
        }
    }
}
