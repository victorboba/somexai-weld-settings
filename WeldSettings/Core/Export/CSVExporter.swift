import Foundation

/// Two spreadsheets, because the two things this app keeps are different shapes.
///
/// The job log is one row per weld — what it was, what was on the machine, how it came out. The
/// preset export is one row per saved setting, grouped by the machine name, which is what somebody
/// setting up a second shop or handing a machine to an apprentice actually wants.
enum CSVExporter {

    static let jobHeader = "date,title,machine,process,material,thickness_mm,thickness_in,joint,position,electrode,amps,volts,wire_feed_ipm,gas_flow_cfh,consumable,gas,polarity,outcome,has_photo,notes"

    static func jobsCSV(for jobs: [JobEntry]) -> String {
        var lines = [jobHeader]
        for job in jobs.sorted(by: { $0.date < $1.date }) {
            let cells = [
                ISO8601DateFormatter.day.string(from: job.date),
                job.displayTitle,
                job.machineName,
                job.process.shortName,
                job.material.name,
                number(job.thicknessMM),
                String(format: "%.3f", Thickness.inches(millimetres: job.thicknessMM)),
                job.joint.name,
                job.position.name,
                job.process == .stick ? job.electrode.name : "",
                job.amps > 0 ? number(job.amps) : "",
                job.volts > 0 ? number(job.volts) : "",
                job.wireFeedIPM > 0 ? number(job.wireFeedIPM) : "",
                job.gasFlowCFH > 0 ? number(job.gasFlowCFH) : "",
                job.consumable,
                job.gas,
                job.polarity.shortName,
                job.outcome.name,
                job.photoData == nil ? "no" : "yes",
                job.notes.replacingOccurrences(of: "\n", with: " "),
            ]
            lines.append(cells.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static let presetHeader = "machine,preset,process,material,thickness_mm,thickness_in,joint,position,electrode,amps,volts,wire_feed_ipm,gas_flow_cfh,consumable,gas,polarity,recommended_amps,notes"

    static func presetsCSV(for presets: [Preset]) -> String {
        var lines = [presetHeader]
        let sorted = presets.sorted {
            ($0.machine?.displayName ?? "", $0.displayName) < ($1.machine?.displayName ?? "", $1.displayName)
        }
        for preset in sorted {
            let recommendation = WeldAdvisor.recommend(for: preset.selection)
            let cells = [
                preset.machine?.displayName ?? "",
                preset.displayName,
                preset.process.shortName,
                preset.material.name,
                number(preset.thicknessMM),
                String(format: "%.3f", Thickness.inches(millimetres: preset.thicknessMM)),
                preset.joint.name,
                preset.position.name,
                preset.process == .stick ? preset.electrode.name : "",
                preset.amps > 0 ? number(preset.amps) : "",
                preset.volts > 0 ? number(preset.volts) : "",
                preset.wireFeedIPM > 0 ? number(preset.wireFeedIPM) : "",
                preset.gasFlowCFH > 0 ? number(preset.gasFlowCFH) : "",
                preset.consumable,
                preset.gas,
                preset.polarity.shortName,
                "\(recommendation.ampsLow)-\(recommendation.ampsHigh)",
                preset.notes.replacingOccurrences(of: "\n", with: " "),
            ]
            lines.append(cells.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func exportJobs(_ jobs: [JobEntry]) throws -> URL {
        let url = ExportFile.temporaryURL(extension: "csv")
        try jobsCSV(for: jobs).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func exportPresets(_ presets: [Preset]) throws -> URL {
        let url = ExportFile.temporaryURL(stem: "\(AppConfig.exportFileStem)-presets", extension: "csv")
        try presetsCSV(for: presets).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Trims a trailing `.0` so a spreadsheet column of amps reads 140 rather than 140.0.
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(stem: String = AppConfig.exportFileStem, extension ext: String) -> URL {
        let stamp = DateFormatter.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(stem)-\(stamp)")
            .appendingPathExtension(ext)
    }
}

extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()

    static let report: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

extension ISO8601DateFormatter {
    static let day: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
