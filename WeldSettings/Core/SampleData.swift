import Foundation
import SwiftData

#if DEBUG
/// Debug-only sample data for screenshots and manual testing: a small mixed fleet, the presets a
/// shop like that accumulates, and a fortnight of jobs.
/// Launch with `-sampleData`, or use Settings → Debug → Insert sample data.
enum SampleData {
    static func insert(into context: ModelContext) {
        let feeder = Machine(name: "Bench feeder", detail: "220 V, 250 A, C25 bottle")
        feeder.notes = "Feeder reads about 20 ipm low under 100 A. Liner is due a change."
        let tig = Machine(name: "AC/DC TIG", detail: "200 A inverter with a foot pedal")
        let buzzBox = Machine(name: "Old buzz box", detail: "AC transformer, no numbers on the dial")
        buzzBox.notes = "Dial is marked one to ten only. Six is about 110 A."
        for machine in [feeder, tig, buzzBox] { context.insert(machine) }

        let presets: [(Machine, String, WeldSelection, Double, Double, Double, Double, String, String, Polarity, String)] = [
            (feeder, "Trailer brackets, 1/4 fillet",
             WeldSelection(process: .mig, material: .mildSteel, thicknessMM: 6.4, joint: .fillet, position: .flat),
             180, 21.5, 300, 22, "0.035 ER70S-6", "75/25 C25", .dcep,
             "Runs hot at this setting on a short lead. Back off 10 A on a long one."),
            (feeder, "18 gauge patch panel",
             WeldSelection(process: .mig, material: .mildSteel, thicknessMM: 1.2, joint: .butt, position: .flat),
             45, 16.0, 150, 20, "0.023 ER70S-6", "75/25 C25", .dcep,
             "Stitch it. Three on, five off, and move around the panel."),
            (tig, "16 ga stainless fillet",
             WeldSelection(process: .tig, material: .stainless, thicknessMM: 1.6, joint: .fillet, position: .flat),
             55, 0, 0, 18, "1/16 lanthanated, 1/16 ER308L", "100% argon", .dcen,
             "Pedal barely off the floor. Back purge anything that has to stay bright."),
            (tig, "1/8 aluminium bracket",
             WeldSelection(process: .tig, material: .aluminium, thicknessMM: 3.2, joint: .fillet, position: .flat),
             130, 0, 0, 20, "3/32 lanthanated, 1/8 ER4043", "100% argon", .ac,
             "Balance 70% EN, 120 Hz. Clean it with the aluminium brush first."),
            (buzzBox, "1/8 7018 on 3/8 plate",
             WeldSelection(process: .stick, material: .mildSteel, thicknessMM: 9.5, joint: .fillet, position: .flat, electrode: .e7018),
             125, 0, 0, 0, "1/8 E7018", "", .dcep,
             "Dial about six. Rods live in the oven."),
        ]

        for (machine, name, selection, amps, volts, wfs, flow, consumable, gas, polarity, notes) in presets {
            let preset = Preset(name: name, selection: selection)
            preset.machine = machine
            preset.amps = amps
            preset.volts = volts
            preset.wireFeedIPM = wfs
            preset.gasFlowCFH = flow
            preset.consumable = consumable
            preset.gas = gas
            preset.polarity = polarity
            preset.notes = notes
            context.insert(preset)
        }

        let calendar = Calendar.current
        let jobs: [(Int, String, String, WeldSelection, Double, Double, Double, Double, JobOutcome, String)] = [
            (0, "Trailer fender bracket", "Bench feeder",
             WeldSelection(process: .mig, material: .mildSteel, thicknessMM: 6.4, joint: .fillet, position: .flat),
             180, 21.5, 300, 22, .firstTry, "Straight off the preset. Good wash on both toes."),
            (1, "Exhaust hanger", "AC/DC TIG",
             WeldSelection(process: .tig, material: .stainless, thicknessMM: 1.6, joint: .lap, position: .horizontal),
             48, 0, 0, 18, .tuned, "Started at 55 and it was too hot in the lap. Came down to 48."),
            (2, "Gate hinge repair", "Old buzz box",
             WeldSelection(process: .stick, material: .mildSteel, thicknessMM: 9.5, joint: .fillet, position: .verticalUp, electrode: .e7018),
             115, 0, 0, 0, .tuned, "Uphill at 115. Any hotter and it ran out of the joint."),
            (4, "Quarter panel patch", "Bench feeder",
             WeldSelection(process: .mig, material: .mildSteel, thicknessMM: 1.2, joint: .butt, position: .flat),
             45, 16.0, 150, 20, .redone, "Blew through twice before I slowed down and stitched it."),
            (6, "Aluminium ladder rung", "AC/DC TIG",
             WeldSelection(process: .tig, material: .aluminium, thicknessMM: 3.2, joint: .fillet, position: .flat),
             130, 0, 0, 20, .firstTry, "Cleaned it first this time. Night and day."),
            (9, "Shelf frame, four corners", "Bench feeder",
             WeldSelection(process: .mig, material: .mildSteel, thicknessMM: 3.0, joint: .outsideCorner, position: .flat),
             110, 18.5, 230, 22, .tuned, "Outside corner burns through fast. Dropped 15 A from the card."),
            (12, "Handrail return", "Bench feeder",
             WeldSelection(process: .mig, material: .stainless, thicknessMM: 2.0, joint: .butt, position: .horizontal),
             85, 18.0, 190, 22, .firstTry, "Tri-mix would have been flatter but this passed."),
        ]

        for (daysAgo, title, machineName, selection, amps, volts, wfs, flow, outcome, notes) in jobs {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now),
                  let time = calendar.date(bySettingHour: 9 + (daysAgo % 6), minute: (daysAgo * 7) % 60, second: 0, of: day)
            else { continue }
            let job = JobEntry(date: time, title: title, selection: selection)
            job.machineName = machineName
            job.amps = amps
            job.volts = volts
            job.wireFeedIPM = wfs
            job.gasFlowCFH = flow
            job.outcome = outcome
            job.notes = notes
            job.polarity = WeldAdvisor.recommend(for: selection).polarity
            context.insert(job)
        }

        try? context.save()
    }
}
#endif
