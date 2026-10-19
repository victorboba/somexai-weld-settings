import Foundation
import UIKit

/// Two documents, and neither of them is a data dump.
///
/// **The setting card** is the one that gets printed. It is a machine's presets on one page, in
/// the order a welder reads them, meant to be taped inside the cabinet door next to the wire
/// feeder. That is a real object in real shops, usually a piece of card with biro on it, and it
/// is the thing a settings app can actually replace.
///
/// **The weld record** is the job log: what was welded, on what, at what settings, how it came
/// out, with the bead photo printed beside it. That is what goes to a customer who asked what was
/// done to their trailer, or into a folder for the next person who has to repair it.
///
/// Every page carries the same two sentences: these are starting points, and this app is not
/// affiliated with any machine manufacturer.
enum PDFExporter {

    /// The machine's presets, on one page, for the cabinet door.
    static func exportSettingCard(for machine: Machine, asOf today: Date = .now) throws -> URL {
        let presets = machine.sortedPresets
        return try render(named: "\(AppConfig.exportFileStem)-setting-card-\(ISO8601DateFormatter.day.string(from: today))") { draw in
            draw.title("Machine setting card")
            draw.line(machine.displayName, size: 14, weight: .semibold, gapAfter: 2)
            if !machine.detail.isEmpty {
                draw.line(machine.detail, size: 10, colour: .secondaryLabel, gapAfter: 2)
            }
            draw.line("Printed \(today.formatted(date: .long, time: .omitted))", size: 9, colour: .secondaryLabel)
            draw.rule()

            if presets.isEmpty {
                draw.line("No presets have been saved on this machine yet.", size: 11, colour: .secondaryLabel)
            }

            for preset in presets {
                let recommendation = WeldAdvisor.recommend(for: preset.selection)
                draw.line(preset.displayName, size: 12, weight: .semibold, gapAfter: 2)
                draw.line(preset.selection.headline, size: 9, colour: .secondaryLabel, gapAfter: 3)

                draw.field("Set to", preset.settingsSummary,
                           valueWeight: preset.hasNumbers ? .semibold : .regular)
                draw.field("Polarity", preset.polarity.name)
                if !preset.consumable.isEmpty { draw.field("Consumable", preset.consumable) }
                if !preset.gas.isEmpty { draw.field("Gas", preset.gas) }
                draw.field("Starting point", "\(recommendation.ampsLow) to \(recommendation.ampsHigh) amps")
                if !preset.notes.isEmpty {
                    draw.field("Notes", preset.notes)
                }
                draw.rule(gap: 12)
            }

            if !machine.notes.isEmpty {
                draw.line("About this machine", size: 11, weight: .semibold, gapAfter: 3)
                draw.line(machine.notes, size: 10, gapAfter: 6)
            }

            draw.line(disclaimer, size: 8, colour: .secondaryLabel, gapAfter: 3)
            draw.line(independence, size: 8, colour: .secondaryLabel)
        }
    }

    /// The job log as a record somebody else can read.
    static func exportWeldRecord(_ jobs: [JobEntry], asOf today: Date = .now) throws -> URL {
        let sorted = jobs.sorted { $0.date > $1.date }
        return try render(named: "\(AppConfig.exportFileStem)-\(ISO8601DateFormatter.day.string(from: today))") { draw in
            draw.title("Weld record")
            if let newest = sorted.first?.date, let oldest = sorted.last?.date {
                draw.line("\(oldest.formatted(date: .long, time: .omitted)) to \(newest.formatted(date: .long, time: .omitted))",
                          size: 11, colour: .secondaryLabel, gapAfter: 2)
            }
            draw.line("\(sorted.count) \(sorted.count == 1 ? "weld" : "welds") logged", size: 11, colour: .secondaryLabel)
            draw.rule()

            if sorted.isEmpty {
                draw.line("No welds have been logged yet.", size: 11, colour: .secondaryLabel)
            }

            for job in sorted {
                draw.line(job.displayTitle, size: 13, weight: .semibold, gapAfter: 2)
                draw.line(job.date.formatted(date: .long, time: .shortened), size: 9, colour: .secondaryLabel, gapAfter: 4)

                draw.field("Process", job.process.name)
                draw.field("Metal", "\(job.material.name), \(Thickness.formatMM(job.thicknessMM)) (\(Thickness.formatInch(job.thicknessMM)))")
                draw.field("Joint", "\(job.joint.name), \(job.position.name.lowercased())")
                if job.process == .stick { draw.field("Electrode", job.electrode.name) }
                if !job.machineName.isEmpty { draw.field("Machine", job.machineName) }
                draw.field("Settings", job.settingsSummary, valueWeight: .semibold)
                draw.field("Polarity", job.polarity.name)
                if !job.consumable.isEmpty { draw.field("Consumable", job.consumable) }
                if !job.gas.isEmpty { draw.field("Gas", job.gas) }
                draw.field("Outcome", job.outcome.name,
                           valueColour: job.outcome == .firstTry ? .systemGreen : .label)
                if !job.notes.isEmpty { draw.field("Notes", job.notes) }

                if let data = job.photoData, let image = UIImage(data: data) {
                    draw.image(image, maxHeight: 150)
                }
                draw.rule(gap: 14)
            }

            draw.line(disclaimer, size: 8, colour: .secondaryLabel, gapAfter: 3)
            draw.line(independence, size: 8, colour: .secondaryLabel)
        }
    }

    static let disclaimer = "Settings shown as starting points are drawn from general welding practice and are not a specification. "
        + "They are tuned by the welder against a test coupon, by the sound of the arc and the appearance of the bead. "
        + "Where a drawing or a welding procedure specification applies, that document governs."

    static let independence = "Weld Settings is an independent application. It is not affiliated with, endorsed by or connected to "
        + "any welding machine manufacturer, and machine names in this record were typed by the user."

    // MARK: - Page plumbing

    final class Draw {
        let ctx: UIGraphicsPDFRendererContext
        let pageWidth: CGFloat = 612, pageHeight: CGFloat = 792, margin: CGFloat = 48
        var y: CGFloat = 48

        init(_ ctx: UIGraphicsPDFRendererContext) { self.ctx = ctx }

        func title(_ text: String) { line(text, size: 22, weight: .semibold) }

        func line(_ text: String, size: CGFloat = 11, weight: UIFont.Weight = .regular,
                  colour: UIColor = .label, indent: CGFloat = 0, gapAfter: CGFloat = 4) {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
            let width = pageWidth - margin * 2 - indent
            let bounding = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            if y + bounding.height > pageHeight - margin { ctx.beginPage(); y = margin }
            (text as NSString).draw(
                with: CGRect(x: margin + indent, y: y, width: width, height: bounding.height),
                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            y += bounding.height + gapAfter
        }

        /// A label and its value as two drawn runs in one row. Deliberately **not** a padded
        /// string: `PDFDocument` hands padded columns back out of order and any assertion on
        /// their adjacency is a coin flip (CLAUDE.md rule 7). Two rectangles are also what makes
        /// a long value wrap under itself instead of running off the page.
        func field(_ label: String, _ value: String, valueWeight: UIFont.Weight = .regular,
                   valueColour: UIColor = .label) {
            let labelWidth: CGFloat = 104
            let labelFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let valueFont = UIFont.systemFont(ofSize: 10, weight: valueWeight)
            let valueWidth = pageWidth - margin * 2 - labelWidth
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: valueColour]
            let bounding = (value as NSString).boundingRect(
                with: CGSize(width: valueWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], attributes: valueAttrs, context: nil)
            let height = max(bounding.height, 12)
            if y + height > pageHeight - margin { ctx.beginPage(); y = margin }
            (label as NSString).draw(
                with: CGRect(x: margin, y: y + 1, width: labelWidth - 8, height: 12),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: labelFont, .foregroundColor: UIColor.secondaryLabel], context: nil)
            (value as NSString).draw(
                with: CGRect(x: margin + labelWidth, y: y, width: valueWidth, height: height),
                options: [.usesLineFragmentOrigin], attributes: valueAttrs, context: nil)
            y += height + 3
        }

        func image(_ image: UIImage, maxHeight: CGFloat) {
            let scale = min(maxHeight / max(image.size.height, 1), (pageWidth - margin * 2) / max(image.size.width, 1), 1)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            if y + size.height > pageHeight - margin { ctx.beginPage(); y = margin }
            image.draw(in: CGRect(origin: CGPoint(x: margin, y: y), size: size))
            y += size.height + 6
        }

        func rule(gap: CGFloat = 10) {
            y += gap / 2
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor.separator.setStroke()
            path.lineWidth = 0.5
            path.stroke()
            y += gap / 2
        }
    }

    static func render(named name: String, _ body: (Draw) -> Void) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            body(Draw(ctx))
        }
        return url
    }
}
