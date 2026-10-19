import Foundation

/// Stick is the one process where the rod decides the settings, not the thickness, so the bench
/// asks for it. A 1/8 in 6010 and a 1/8 in 7018 in the same plate are forty amps and two
/// different techniques apart.
///
/// The amperage ranges below are the published operating ranges for each classification and
/// diameter. They are not scaled by joint or position the way the MIG and TIG numbers are —
/// distorting a published range would make it something other than the published range. Out of
/// position the card says to work in the lower part of it instead, which is what the rod makers
/// say too.
enum StickElectrode: String, CaseIterable, Identifiable, Codable {
    case e6010, e6011, e6013, e7018, e308L, e4043

    var id: String { rawValue }

    var name: String {
        switch self {
        case .e6010: return "E6010"
        case .e6011: return "E6011"
        case .e6013: return "E6013"
        case .e7018: return "E7018"
        case .e308L: return "E308L-16"
        case .e4043: return "E4043"
        }
    }

    /// What it is for, in one line a welder would actually say.
    var summary: String {
        switch self {
        case .e6010: return "Deep digging root pass. Cuts through rust, paint and mill scale. Wants DC."
        case .e6011: return "The 6010 that runs on an AC buzz box. Same dig, more spatter."
        case .e6013: return "Soft, easy arc for light sheet and general repair. Shallow penetration."
        case .e7018: return "Low hydrogen, structural. Smooth bead, tight arc, and it has to be dry."
        case .e308L: return "Austenitic stainless. Run it cool and let it cool."
        case .e4043: return "Aluminium stick. Rare, awkward, and only worth it when nothing else is in the shop."
        }
    }

    static func available(for material: BaseMaterial) -> [StickElectrode] {
        switch material {
        case .mildSteel: return [.e6010, .e6011, .e6013, .e7018]
        case .stainless: return [.e308L]
        case .aluminium: return [.e4043]
        }
    }

    static func `default`(for material: BaseMaterial) -> StickElectrode {
        available(for: material).first ?? .e7018
    }

    /// Published operating range, in amps, keyed by electrode diameter in millimetres.
    /// 2.4 mm is 3/32 in, 3.2 mm is 1/8 in, 4.0 mm is 5/32 in.
    var ampsByDiameter: [Double: (low: Int, high: Int)] {
        switch self {
        case .e6010: return [2.4: (40, 85), 3.2: (75, 125), 4.0: (110, 165)]
        case .e6011: return [2.4: (50, 85), 3.2: (75, 125), 4.0: (110, 165)]
        case .e6013: return [2.4: (50, 90), 3.2: (80, 130), 4.0: (105, 180)]
        case .e7018: return [2.4: (70, 100), 3.2: (110, 150), 4.0: (140, 190)]
        case .e308L: return [2.4: (40, 80), 3.2: (65, 110), 4.0: (95, 145)]
        case .e4043: return [2.4: (40, 75), 3.2: (70, 110), 4.0: (100, 150)]
        }
    }

    var polarity: Polarity {
        switch self {
        case .e6010, .e6011, .e7018, .e308L, .e4043: return .dcep
        case .e6013: return .ac
        }
    }

    var polarityNote: String {
        switch self {
        case .e6010: return "DC only. A 6010 on an AC machine will not stay lit — that is what 6011 is for."
        case .e6011: return "Runs on AC or DCEP. AC is what it was made for."
        case .e6013: return "Happy on AC, DCEN or DCEP. DCEN gives the flattest bead on thin sheet."
        case .e7018: return "DCEP, or AC if the rod is an AC classification. Keep the arc short."
        case .e308L: return "DCEP, or AC on an older machine."
        case .e4043: return "DCEP only."
        }
    }

    var technique: [String] {
        switch self {
        case .e6010:
            return ["Whip and pause, or a tight drag. It wants to be worked, not dragged in a straight line.",
                    "Long arc on purpose for the root. That dig is the whole reason the rod exists."]
        case .e6011:
            return ["Same whip as a 6010. Expect more spatter and a heavier slag.",
                    "Good on dirty or painted metal when grinding it clean is not an option."]
        case .e6013:
            return ["Drag it with a short arc, near vertical. It is the easy rod for a reason.",
                    "On sheet, run at the bottom of the range and let it cool between passes."]
        case .e7018:
            return ["Drag, short arc, no whipping. The flux does the shielding and a long arc lets air in.",
                    "Keep the rods in a dry rod oven or a sealed can. A damp 7018 gives porosity and nothing will fix it but a fresh rod."]
        case .e308L:
            return ["Short arc, minimal weave, stringer beads. Heat is what wrecks stainless.",
                    "Let it cool between passes — check the interpass temperature by hand on the back side."]
        case .e4043:
            return ["Preheat, strike fast, and move. The flux is hygroscopic and the arc is unforgiving.",
                    "Chip and wash the slag off completely. Aluminium stick flux is corrosive if it is left on."]
        }
    }
}
