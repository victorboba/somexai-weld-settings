import Foundation

/// What the bead is telling you, and which dial to move.
///
/// A settings chart is only half the job. The other half is reading what came out and knowing
/// which way to go, and that is the half nobody puts in an app because it does not fit in a
/// table. Each entry names the thing you can see with the helmet up, says what usually causes
/// it, and says what to change — in that order, because that is the order a welder thinks in.
struct BeadSymptom: Identifiable, Equatable {
    var id: String { symptom }
    /// What it looks like, in the words used at the bench.
    let symptom: String
    /// The usual cause.
    let cause: String
    /// What to change, first.
    let fix: String
}

enum BeadDiagnostics {

    static func symptoms(for process: WeldProcess) -> [BeadSymptom] {
        switch process {
        case .mig: return mig
        case .tig: return tig
        case .stick: return stick
        }
    }

    static let mig: [BeadSymptom] = [
        BeadSymptom(symptom: "Blowing holes through the metal",
                    cause: "Too much current for the thickness, or the travel is too slow, or the gap is too wide.",
                    fix: "Down 10 A. If it still goes through, stitch it: three seconds on, three off, and let it cool."),
        BeadSymptom(symptom: "Bead sits on top, edges you can trace with a fingernail",
                    cause: "Cold lap. Not enough heat to melt the base metal, only the wire.",
                    fix: "Voltage and wire speed up together, and slow the travel. A bead that is not fused is not a weld."),
        BeadSymptom(symptom: "Tall, narrow, ropey bead",
                    cause: "Voltage too low for the wire speed. The arc is too short to spread the puddle.",
                    fix: "Up 1 V at a time until it flattens out and the crackle evens up."),
        BeadSymptom(symptom: "Wide flat bead and the arc wandering",
                    cause: "Voltage too high. The arc is long enough to lose the plate.",
                    fix: "Down 1 V, and check the stick-out is not stretched out past 1/2 in."),
        BeadSymptom(symptom: "Wire stubs into the plate and pushes the gun back",
                    cause: "Wire speed too high for the voltage.",
                    fix: "Slow the wire 20 ipm, or raise the voltage 1 V. Either brings it back into balance."),
        BeadSymptom(symptom: "Wire burns back and fuses to the contact tip",
                    cause: "Wire speed too low, or the tip is worn oval.",
                    fix: "Speed the wire 20 ipm. Change the tip if it has been on the gun a while."),
        BeadSymptom(symptom: "Heavy spatter and a loud irregular crackle",
                    cause: "Voltage and wire speed out of balance, or no gas reaching the arc.",
                    fix: "Check the bottle and the flow first, then balance the volts to the wire. A steady frying-bacon sound is the target."),
        BeadSymptom(symptom: "Pinholes and pits in the finished bead",
                    cause: "Porosity: air getting to the puddle. Draught, low flow, a blocked nozzle, or oil, paint, rust and galvanising in the joint.",
                    fix: "Clean the joint back to bright metal, shield the work from the wind, and check the nozzle is not bridged with spatter."),
        BeadSymptom(symptom: "A groove melted along the edge of the bead",
                    cause: "Undercut. Too hot, travelling too fast, or the gun is leaning too far.",
                    fix: "Down 10 A, slow down, and pause a beat at each toe so the groove fills."),
        BeadSymptom(symptom: "Wire tangles at the drive rolls",
                    cause: "A feeding problem, not a settings problem: tension too tight, wrong groove, kinked liner, or a soft aluminium wire in a steel liner.",
                    fix: "Back the tension off until the wire slips against a gloved hand, straighten the lead, and use a U-groove roll and a nylon liner for aluminium."),
    ]

    static let tig: [BeadSymptom] = [
        BeadSymptom(symptom: "Tungsten keeps going black and spitting",
                    cause: "It touched the puddle or the filler, or it is too small for the current, or the post-flow is too short.",
                    fix: "Regrind along the taper, not across it. Go up a tungsten size if the current is at the top of its range."),
        BeadSymptom(symptom: "Puddle will not open",
                    cause: "Not enough current, a poor earth, or heat running away into a big cold part.",
                    fix: "Up 10 A, move the earth clamp closer and onto clean metal, and preheat heavy or highly conductive sections."),
        BeadSymptom(symptom: "Filler balls up before it reaches the puddle",
                    cause: "The rod is entering the arc instead of the leading edge of the puddle.",
                    fix: "Come in flatter, almost along the plate, and dab into the front of the puddle."),
        BeadSymptom(symptom: "Grey, sooty, dull weld",
                    cause: "Not enough shielding at the puddle: flow too low, a cracked cup, a draught, or the cup held too far off.",
                    fix: "Check the flow and the post-flow, fit a gas lens, and get the cup down close."),
        BeadSymptom(symptom: "Stainless comes out dark blue or grey and sugary underneath",
                    cause: "Too much heat, and no gas on the back side of the joint.",
                    fix: "Run cooler and faster with stringer beads, and back purge anything that has to stay corrosion resistant."),
        BeadSymptom(symptom: "Aluminium goes dull and collapses with no warning",
                    cause: "Aluminium does not change colour before it melts, and the oxide skin melts far hotter than the metal beneath it.",
                    fix: "Watch the shine of the puddle, not the plate. Clean with a brush kept only for aluminium and weld it the same day."),
        BeadSymptom(symptom: "Arc wanders on aluminium and will not clean",
                    cause: "AC balance too far to electrode negative, or the machine is on DC.",
                    fix: "More electrode positive cleans more oxide. Raise the AC frequency to tighten the cone and stop the wander."),
        BeadSymptom(symptom: "The plate warps out of shape",
                    cause: "Too much heat in for too long.",
                    fix: "Higher current and faster travel puts in less total heat than low current and a slow crawl. Skip weld and let it cool between passes."),
    ]

    static let stick: [BeadSymptom] = [
        BeadSymptom(symptom: "Rod sticks to the plate on the strike",
                    cause: "Amperage too low, or the strike was too slow.",
                    fix: "Up 10 A, and strike like a match rather than stabbing."),
        BeadSymptom(symptom: "Rod glows red halfway down and the flux flakes off",
                    cause: "Amperage too high for that diameter, or the rod has been run too far.",
                    fix: "Down 10 A. A rod that is cooking is going to give porosity whatever else you do."),
        BeadSymptom(symptom: "A groove melted along the edge of the bead",
                    cause: "Undercut: too much current, too long an arc, or travelling too fast.",
                    fix: "Shorten the arc first. Then drop the current 10 A and pause at the toes."),
        BeadSymptom(symptom: "Porosity all along a 7018 bead",
                    cause: "Damp flux, almost always. 7018 pulls moisture out of shop air in hours.",
                    fix: "Fresh rod from a sealed can or a hot oven, and keep the arc tight. Nothing else fixes it."),
        BeadSymptom(symptom: "Slag will not chip off",
                    cause: "The bead is too cold and convex, so the slag is locked under the crown.",
                    fix: "Up the current a little and flatten the bead. Good slag lifts in one curl."),
        BeadSymptom(symptom: "Slag runs ahead of the puddle",
                    cause: "Travelling too slowly, or the arc is pointed too far forward, especially downhill.",
                    fix: "Speed up, tilt the rod back, and let the arc stay in front of the slag."),
        BeadSymptom(symptom: "Arc blows sideways and will not stay in the joint",
                    cause: "Arc blow. The earth's magnetic field, worst at the end of a long part and in corners on DC.",
                    fix: "Move the earth clamp, weld towards it, shorten the arc, or run AC if the machine will."),
    ]
}
