import Foundation

/// What the bench is set to. One value type, so the selector, a saved preset and a logged job all
/// speak the same language and a preset can be loaded straight back onto the bench.
struct WeldSelection: Equatable, Codable {
    var process: WeldProcess = .mig
    var material: BaseMaterial = .mildSteel
    /// Always millimetres inside the app. Gauge and inches are display, never storage.
    var thicknessMM: Double = 3.0
    var joint: JointType = .fillet
    var position: WeldPosition = .flat
    /// Only asked for, and only meaningful, on stick.
    var electrode: StickElectrode = .e7018

    /// Keeps the electrode legal when the material changes: there is no 7018 for aluminium.
    mutating func normalise() {
        if !StickElectrode.available(for: material).contains(electrode) {
            electrode = StickElectrode.default(for: material)
        }
    }

    var headline: String {
        let thickness = Thickness.formatMM(thicknessMM)
        return "\(process.shortName) · \(material.name) · \(thickness) · \(joint.name.lowercased())"
    }
}

/// One row of the settings card: what to set, the range to set it to, and — the part the
/// manufacturer apps leave out — which way to move it when the bead comes out wrong.
struct SettingLine: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let value: String
    /// The secondary reading of the same number: millimetres beside inches, L/min beside CFH.
    var alternate: String? = nil
    /// Which way to move it, and what you are looking at when you decide.
    let moveIt: String
}

/// A starting point, not a specification.
///
/// Every number in here is a range taken from general welding practice for short-circuit MIG,
/// TIG and stick on mild steel, stainless and aluminium. No machine is modelled, no brand's
/// chart is reproduced, and nothing is claimed to a precision the process does not have — a
/// wire feeder's dial, the length of the ground lead and the temperature of the plate all move
/// it. The card says so, on the card, every time.
struct WeldRecommendation: Equatable {
    var selection: WeldSelection
    var ampsLow: Int
    var ampsHigh: Int
    var lines: [SettingLine]
    var polarity: Polarity
    var polarityNote: String
    var technique: [String]
    var cautions: [String]

    var ampsText: String { "\(ampsLow) – \(ampsHigh) A" }
}

/// Turns a bench selection into a settings card.
///
/// The rules it applies, all of them ordinary shop practice rather than anything invented here:
///
/// * **One amp per thousandth of an inch** is the starting current for MIG and TIG on mild
///   steel. Thickness in inches times 1000 is the number.
/// * **The metal moves it.** Aluminium pulls heat out roughly four times faster than steel and
///   takes more current; austenitic stainless conducts about a third as well and takes less.
/// * **The joint moves it.** A fillet has two members drinking from one puddle. An outside
///   corner has metal on one side only and burns through.
/// * **The position moves it.** Out of position the puddle has to be small enough that gravity
///   does not win, so the current comes down ten to fifteen per cent.
/// * **Stick is different** and is left alone: the published range for that rod at that diameter
///   is the range, and the card says to work low in it out of position rather than quietly
///   rewriting the rod maker's numbers.
enum WeldAdvisor {

    static func recommend(for input: WeldSelection) -> WeldRecommendation {
        var selection = input
        selection.normalise()
        switch selection.process {
        case .mig: return mig(selection)
        case .tig: return tig(selection)
        case .stick: return stick(selection)
        }
    }

    // MARK: - Shared arithmetic

    /// Thickness in thousandths of an inch, which is the number the one-amp-per-mil rule wants.
    static func mils(_ mm: Double) -> Double { Thickness.inches(millimetres: mm) * 1000 }

    /// The centre current before the range is opened up around it.
    static func centreAmps(_ selection: WeldSelection) -> Double {
        mils(selection.thicknessMM)
            * selection.material.heatFactor
            * selection.joint.heatFactor
            * selection.position.heatFactor
    }

    static func roundTo(_ value: Double, _ step: Int) -> Int {
        max(step, Int((value / Double(step)).rounded()) * step)
    }

    // MARK: - MIG

    /// Solid wire diameters stocked in a home or fab shop, in millimetres, with the inch size
    /// printed on the spool.
    static let wireDiameters: [(mm: Double, inch: String)] = [
        (0.6, "0.023 in"), (0.8, "0.030 in"), (0.9, "0.035 in"), (1.2, "0.045 in"),
    ]

    /// The diameter that suits the thickness. Aluminium starts a size up whatever the plate:
    /// soft wire under 0.9 mm buckles in the liner and birdnests before it reaches the gun.
    static func wireDiameter(for selection: WeldSelection) -> Double {
        let t = selection.thicknessMM
        let base: Double
        switch t {
        case ..<1.3: base = 0.6
        case ..<3.3: base = 0.8
        case ..<6.5: base = 0.9
        default: base = 1.2
        }
        return selection.material == .aluminium ? max(base, 0.9) : base
    }

    /// Roughly how many inches of this wire one amp will melt off in a minute. The figure falls
    /// as the wire gets fatter, which is why a 0.045 spool at 200 A is nowhere near the feed
    /// speed a 0.030 spool wants at the same current.
    static func meltOffRate(diameterMM: Double, material: BaseMaterial) -> Double {
        let steel: Double
        switch diameterMM {
        case ..<0.7: steel = 3.4
        case ..<0.85: steel = 2.2
        case ..<1.0: steel = 1.6
        default: steel = 1.0
        }
        // Aluminium wire is a third of the density of steel, so the same current pushes a lot
        // more wire through the gun.
        return material == .aluminium ? steel * 1.7 : steel
    }

    /// The current above which a wire that size stops keeping up and starts burning back.
    static func wireCeiling(diameterMM: Double) -> Int {
        switch diameterMM {
        case ..<0.7: return 140
        case ..<0.85: return 200
        case ..<1.0: return 250
        default: return 350
        }
    }

    static func gas(for selection: WeldSelection) -> (primary: String, alternative: String?) {
        switch selection.material {
        case .mildSteel:
            return ("75% argon / 25% CO2 (C25)",
                    "100% CO2 digs deeper and costs less, at the price of a lot more spatter.")
        case .stainless:
            return ("98% argon / 2% CO2",
                    "A helium tri-mix (90 He / 7.5 Ar / 2.5 CO2) runs flatter and wets in better on short circuit.")
        case .aluminium:
            return ("100% argon",
                    "Add helium only on heavy section, and only if the machine can hold the arc.")
        }
    }

    static func flowCFH(for selection: WeldSelection) -> (low: Int, high: Int) {
        switch selection.process {
        case .mig:
            return selection.material == .aluminium ? (25, 30) : (20, 25)
        case .tig:
            return selection.material == .aluminium ? (18, 25) : (15, 20)
        case .stick:
            return (0, 0)
        }
    }

    static func mig(_ selection: WeldSelection) -> WeldRecommendation {
        let centre = centreAmps(selection)
        let diameter = wireDiameter(for: selection)
        let ceiling = wireCeiling(diameterMM: diameter)
        // The range is clamped to what the wire will carry, and then reopened downwards if the
        // clamp closed it. Widening it upwards instead would hand back a current the wire
        // physically cannot feed, which is exactly the fabricated number this app avoids.
        var ampsLow = max(30, min(roundTo(centre * 0.88, 5), ceiling))
        var ampsHigh = max(30, min(roundTo(centre * 1.12, 5), ceiling))
        if ampsHigh <= ampsLow { ampsLow = max(30, ampsHigh - 20) }
        if ampsHigh <= ampsLow { ampsHigh = ampsLow + 10 }

        // Short-circuit transfer on steel lives in the high teens and low twenties. Aluminium is
        // spray or pulse and sits several volts above that.
        let voltCentre: Double
        switch selection.material {
        case .mildSteel: voltCentre = min(25, max(15, 14.0 + Double(ampsLow + ampsHigh) / 32))
        case .stainless: voltCentre = min(25, max(15, 14.5 + Double(ampsLow + ampsHigh) / 32))
        case .aluminium: voltCentre = min(29, max(20, 18.0 + Double(ampsLow + ampsHigh) / 32))
        }
        let voltLow = (voltCentre * 2).rounded() / 2 - 1
        let voltHigh = voltLow + 2

        let melt = meltOffRate(diameterMM: diameter, material: selection.material)
        let wfsLow = roundTo(Double(ampsLow) * melt, 10)
        let wfsHigh = roundTo(Double(ampsHigh) * melt, 10)

        let gasChoice = gas(for: selection)
        let flow = flowCFH(for: selection)
        let inchLabel = wireDiameters.first { abs($0.mm - diameter) < 0.01 }?.inch ?? ""

        var lines: [SettingLine] = [
            SettingLine(
                label: "Amperage",
                value: "\(ampsLow) – \(ampsHigh) A",
                alternate: "on a machine with one dial, this is the wire speed doing the work",
                moveIt: "Blowing through or dropping out the root: down 10 A. Bead sitting on top with a cold edge you can see the toe line on: up 10 A."),
            SettingLine(
                label: "Voltage",
                value: String(format: "%.1f – %.1f V", voltLow, voltHigh),
                moveIt: "Tall, narrow and ropey: up 1 V at a time until it flattens. Wide, flat and the arc wandering or trying to spray: down 1 V."),
            SettingLine(
                label: "Wire speed",
                value: "\(wfsLow) – \(wfsHigh) ipm",
                alternate: String(format: "%.1f – %.1f m/min", Double(wfsLow) * 0.0254, Double(wfsHigh) * 0.0254),
                moveIt: "Wire stubbing into the plate and pushing the gun back: slow it 20 ipm. Wire burning back and fusing to the tip: speed it 20 ipm."),
            SettingLine(
                label: "Wire",
                value: "\(inchLabel) (\(Thickness.formatMM(diameter))) \(wireAlloy(for: selection.material))",
                alternate: "stick-out 3/8 in (10 mm), measured from the tip to the plate",
                moveIt: "Longer stick-out lowers the current at the same dial setting. If the arc goes cold when you pull back, that is why."),
            SettingLine(
                label: "Gas",
                value: gasChoice.primary,
                alternate: gasChoice.alternative,
                moveIt: "Porosity with the bottle open means the gas is not reaching the puddle: draught, a split liner, a clogged nozzle, or spatter bridging the cup."),
            SettingLine(
                label: "Gas flow",
                value: Thickness.formatFlow(flow.low, unit: .cfh) + " – " + Thickness.formatFlow(flow.high, unit: .cfh),
                alternate: Thickness.formatFlow(flow.low, unit: .litresPerMinute) + " – " + Thickness.formatFlow(flow.high, unit: .litresPerMinute),
                moveIt: "Up 5 CFH outdoors or with a long nozzle. More is not better: past about 35 CFH the stream turns turbulent and pulls air in with it."),
        ]

        if selection.material == .aluminium {
            lines.append(SettingLine(
                label: "Feeding",
                value: "Spool gun or push-pull, U-groove rollers, nylon liner",
                moveIt: "Birdnesting at the drive rolls is a feeding problem, never a settings problem. Shorten the lead and back the tension off."))
        }

        var cautions = baseCautions(selection)
        if ampsHigh >= ceiling {
            cautions.append("\(inchLabel) wire is at the top of what it will carry at around \(ceiling) A. On section this heavy go up a wire size rather than pushing this one.")
        }
        if selection.material == .aluminium && selection.thicknessMM < 1.6 {
            cautions.append("Aluminium this thin is very hard with short-circuit MIG. TIG it, or back the plate with aluminium or steel to carry the heat away.")
        }

        var technique: [String] = [
            "Push the gun, do not drag it. A push angle of 10 to 15 degrees gives a flatter bead and better gas coverage on solid wire.",
            selection.joint.selectionNote(selection),
            selection.position.note,
        ]
        if selection.material == .stainless {
            technique.append("Keep the interpass temperature down. Stringers, not weave, and let it cool or the chromium carbide precipitates and the corrosion resistance goes with it.")
        }
        if selection.material == .aluminium {
            technique.append("Clean it first with a stainless brush kept only for aluminium, then weld inside the hour. The oxide melts at three times the temperature of the metal under it.")
        }

        return WeldRecommendation(
            selection: selection, ampsLow: ampsLow, ampsHigh: ampsHigh, lines: lines,
            polarity: .dcep,
            polarityNote: "Solid wire under gas runs DCEP. If the machine was last used with gasless flux-cored wire the leads are almost certainly still swapped.",
            technique: technique, cautions: cautions)
    }

    static func wireAlloy(for material: BaseMaterial) -> String {
        switch material {
        case .mildSteel: return "ER70S-6 solid"
        case .stainless: return "ER308LSi solid"
        case .aluminium: return "ER4043 or ER5356"
        }
    }

    // MARK: - TIG

    /// Tungsten diameters in millimetres, with the inch size on the packet.
    static let tungstenDiameters: [(mm: Double, inch: String)] = [
        (1.6, "1/16 in"), (2.4, "3/32 in"), (3.2, "1/8 in"),
    ]

    static func tungstenDiameter(for thicknessMM: Double) -> Double {
        switch thicknessMM {
        case ..<1.7: return 1.6
        case ..<5.0: return 2.4
        default: return 3.2
        }
    }

    /// What that tungsten will carry before it spits. AC costs roughly a third of the DC
    /// capacity because the electrode-positive half of the cycle heats the tungsten, not the work.
    static func tungstenCeiling(diameterMM: Double, ac: Bool) -> Int {
        switch diameterMM {
        case ..<1.7: return ac ? 100 : 145
        case ..<2.5: return ac ? 160 : 250
        default: return ac ? 250 : 400
        }
    }

    /// Filler rod about the thickness of the metal, snapped to a size somebody stocks.
    static func fillerDiameter(for thicknessMM: Double) -> Double {
        let candidates: [Double] = [1.6, 2.4, 3.2, 4.0]
        let target = min(max(thicknessMM, 1.6), 4.0)
        return candidates.min { abs($0 - target) < abs($1 - target) } ?? 2.4
    }

    static func tig(_ selection: WeldSelection) -> WeldRecommendation {
        let isAluminium = selection.material == .aluminium
        let centre = centreAmps(selection)
        let diameter = tungstenDiameter(for: selection.thicknessMM)
        let ceiling = tungstenCeiling(diameterMM: diameter, ac: isAluminium)
        // Same clamp as MIG: a tungsten at its limit spits into the weld, so the top of the range
        // is the tungsten's limit and the bottom moves down to keep it a range.
        var ampsLow = max(10, min(roundTo(centre * 0.85, 5), ceiling))
        var ampsHigh = max(10, min(roundTo(centre * 1.15, 5), ceiling))
        if ampsHigh <= ampsLow { ampsLow = max(10, ampsHigh - 15) }
        if ampsHigh <= ampsLow { ampsHigh = ampsLow + 5 }

        let filler = fillerDiameter(for: selection.thicknessMM)
        let flow = flowCFH(for: selection)
        let tungstenInch = tungstenDiameters.first { abs($0.mm - diameter) < 0.01 }?.inch ?? ""
        let fillerInch = Thickness.formatInch(filler)

        var lines: [SettingLine] = [
            SettingLine(
                label: "Amperage",
                value: "\(ampsLow) – \(ampsHigh) A",
                alternate: "set the machine here and control the heat with the pedal",
                moveIt: "Puddle spreading faster than you can feed: back off the pedal. Puddle will not open in three or four seconds: up 10 A, or the ground clamp is poor."),
            SettingLine(
                label: "Tungsten",
                value: "\(tungstenInch) (\(Thickness.formatMM(diameter))) 2% lanthanated",
                alternate: isAluminium ? "balled or lightly truncated for AC" : "ground to a point about 2.5 times the diameter",
                moveIt: "Tungsten spitting into the weld: too much current for that size, or it was ground across the taper instead of along it."),
            SettingLine(
                label: "Filler rod",
                value: "\(fillerInch) (\(Thickness.formatMM(filler))) \(fillerAlloy(for: selection.material))",
                moveIt: "Rod balling up before it reaches the puddle: it is entering the arc instead of the puddle. Come in flatter, at the leading edge."),
            SettingLine(
                label: "Gas",
                value: "100% argon",
                alternate: selection.material == .stainless ? "back purge the root on pipe and on anything that has to stay corrosion resistant" : nil,
                moveIt: "Grey, sooty or dull weld: not enough gas at the puddle. Check the flow, the post-flow, and that the cup is not cracked."),
            SettingLine(
                label: "Gas flow",
                value: Thickness.formatFlow(flow.low, unit: .cfh) + " – " + Thickness.formatFlow(flow.high, unit: .cfh),
                alternate: Thickness.formatFlow(flow.low, unit: .litresPerMinute) + " – " + Thickness.formatFlow(flow.high, unit: .litresPerMinute),
                moveIt: "A gas lens lets you drop the flow and still cover a wider area. Post-flow of one second per ten amps stops the tungsten oxidising."),
        ]

        if isAluminium {
            lines.append(SettingLine(
                label: "AC balance",
                value: "65 – 75% electrode negative",
                alternate: "AC frequency 100 – 150 Hz",
                moveIt: "More electrode positive cleans more oxide and heats the tungsten; more electrode negative puts the heat in the work. Raise the frequency to tighten the arc cone."))
        }

        var technique: [String] = [
            "Arc length about the diameter of the tungsten. A long TIG arc is wide, cold and dirty.",
            selection.joint.selectionNote(selection),
            selection.position.note,
        ]
        if selection.material == .stainless {
            technique.append("Watch the back side. Straw is fine, blue is warm, grey and sugary means the root had no gas on it and it has to come out.")
        }
        if isAluminium {
            technique.append("Aluminium gives no colour warning before it collapses. Watch the puddle shine, not the plate.")
        }

        var cautions = baseCautions(selection)
        if ampsHigh >= ceiling {
            cautions.append("\(tungstenInch) tungsten is at its limit around \(ceiling) A \(isAluminium ? "on AC" : "on DC"). Go up a size before you push it further.")
        }
        if selection.thicknessMM >= 6.0 {
            cautions.append("Section this heavy wants multiple passes and probably a bevel. One pass this thick fuses the faces and not the middle.")
        }

        return WeldRecommendation(
            selection: selection, ampsLow: ampsLow, ampsHigh: ampsHigh, lines: lines,
            polarity: isAluminium ? .ac : .dcen,
            polarityNote: isAluminium
                ? "AC. The electrode-positive half of the cycle is what breaks up the oxide film; without it the arc just wanders on top."
                : "DCEN. Two thirds of the heat goes into the work and the tungsten stays cool.",
            technique: technique, cautions: cautions)
    }

    static func fillerAlloy(for material: BaseMaterial) -> String {
        switch material {
        case .mildSteel: return "ER70S-2 or ER70S-6"
        case .stainless: return "ER308L"
        case .aluminium: return "ER4043 or ER5356"
        }
    }

    // MARK: - Stick

    static func electrodeDiameter(for thicknessMM: Double) -> Double {
        switch thicknessMM {
        case ..<3.2: return 2.4
        case ..<6.5: return 3.2
        default: return 4.0
        }
    }

    static func stick(_ selection: WeldSelection) -> WeldRecommendation {
        let diameter = electrodeDiameter(for: selection.thicknessMM)
        let rod = selection.electrode
        let published = rod.ampsByDiameter[diameter] ?? (low: 90, high: 130)
        let inchLabel = Thickness.formatInch(diameter)

        var lines: [SettingLine] = [
            SettingLine(
                label: "Amperage",
                value: "\(published.low) – \(published.high) A",
                alternate: "published range for \(rod.name) at \(inchLabel)",
                moveIt: "Rod sticking on the strike and the arc going out: up 10 A. Rod glowing red halfway down and the flux flaking off: down 10 A."),
            SettingLine(
                label: "Electrode",
                value: "\(rod.name), \(inchLabel) (\(Thickness.formatMM(diameter)))",
                alternate: rod.summary,
                moveIt: "Never run a rod thicker than the thinner member of the joint. On sheet, go down a size before you go down in amps."),
            SettingLine(
                label: "Arc length",
                value: rod == .e6010 || rod == .e6011 ? "Long enough to dig on the root, tight on the fill" : "About one electrode diameter, and no more",
                moveIt: "Undercut along the toes: the arc is long or the travel is fast. Shorten it first."),
            SettingLine(
                label: "Gas",
                value: "None. The flux is the shielding.",
                alternate: "which is why this is the process that works outside in the wind",
                moveIt: "Porosity on stick is a rod problem: damp flux, a long arc, or oil and galvanising in the joint."),
        ]

        if rod == .e7018 {
            lines.append(SettingLine(
                label: "Rod storage",
                value: "Dry oven at 120 °C (250 °F), or a freshly opened sealed can",
                moveIt: "A 7018 left out overnight gives porosity no setting will fix. Bin it or re-bake it."))
        }

        var cautions = baseCautions(selection)
        if selection.thicknessMM < 2.4 {
            cautions.append("Stick on sheet this thin blows through easily. A 6013 at the bottom of the range with a skip sequence is the best of it — MIG or TIG is the honest answer.")
        }
        if selection.material == .aluminium {
            cautions.append("Aluminium stick is a last resort. If a TIG or a spool gun is anywhere in the shop, use it instead.")
        }
        if selection.position != .flat {
            cautions.append("Out of position, work in the lower part of the published range. These are the rod maker's numbers and the app does not rewrite them — it tells you where in them to sit.")
        }

        var technique = rod.technique
        technique.append(selection.joint.selectionNote(selection))
        technique.append(selection.position.note)

        return WeldRecommendation(
            selection: selection, ampsLow: published.low, ampsHigh: published.high, lines: lines,
            polarity: rod.polarity, polarityNote: rod.polarityNote,
            technique: technique, cautions: cautions)
    }

    // MARK: - Cautions every card carries

    static func baseCautions(_ selection: WeldSelection) -> [String] {
        var cautions = [
            "These are starting points from general welding practice, not a specification. Run a test coupon in the same metal, at the same thickness, in the same position, and tune by the sound of the arc and the look of the bead.",
        ]
        if selection.material == .aluminium {
            cautions.append("Aluminium alloy matters as much as thickness. 6061 and 5052 do not behave the same and neither takes the same filler.")
        }
        if selection.thicknessMM >= 10 {
            cautions.append("Anything structural at this thickness is a procedure question, not a dial question. If a drawing calls out a WPS, the WPS wins.")
        }
        return cautions
    }
}

private extension JointType {
    /// The joint note, plus the one extra sentence that only applies at this thickness.
    func selectionNote(_ selection: WeldSelection) -> String {
        if selection.thicknessMM <= 1.6 && self == .butt {
            return note + " At this gauge, tack every 25 mm and skip around — a continuous bead will pull the panel like a banana."
        }
        return note
    }
}
