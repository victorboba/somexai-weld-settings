import XCTest
import PDFKit
import UIKit
@testable import WeldSettings

/// The two exports. The PDF is the deliverable — the card that gets taped inside a cabinet door
/// and the record that goes to whoever asked what was done — so it is tested for content, not
/// just for existing.
///
/// CLAUDE.md rule 7 applies throughout: `PDFDocument` re-wraps at the column width, so every
/// multi-word assertion goes through `flattened` first, and label/value pairs are asserted
/// separately rather than as one adjacent string.
@MainActor
final class ExportTests: XCTestCase {

    // MARK: - Fixtures

    private func makeJob(title: String = "Trailer fender bracket",
                         machine: String = "Bench feeder",
                         selection: WeldSelection = WeldSelection(process: .mig, material: .mildSteel,
                                                                  thicknessMM: 6.4, joint: .fillet, position: .flat),
                         amps: Double = 180, volts: Double = 21.5, wfs: Double = 300,
                         outcome: JobOutcome = .firstTry,
                         daysAgo: Int = 0,
                         notes: String = "Good wash on both toes.") -> JobEntry {
        let job = JobEntry(date: Date(timeIntervalSince1970: 1_700_000_000 - Double(daysAgo) * 86_400),
                           title: title, selection: selection)
        job.machineName = machine
        job.amps = amps
        job.volts = volts
        job.wireFeedIPM = wfs
        job.gasFlowCFH = 22
        job.consumable = "0.035 ER70S-6"
        job.gas = "75/25 C25"
        job.outcome = outcome
        job.notes = notes
        return job
    }

    private func makeMachineWithPresets() -> Machine {
        let machine = Machine(name: "Bench feeder", detail: "220 V, 250 A, C25 bottle")
        machine.notes = "Feeder reads low under 100 A."
        let preset = Preset(name: "Trailer brackets",
                            selection: WeldSelection(process: .mig, material: .mildSteel,
                                                     thicknessMM: 6.4, joint: .fillet, position: .flat))
        preset.amps = 180
        preset.volts = 21.5
        preset.wireFeedIPM = 300
        preset.gasFlowCFH = 22
        preset.consumable = "0.035 ER70S-6"
        preset.gas = "75/25 C25"
        preset.polarity = .dcep
        preset.notes = "Back off 10 A on a long lead."
        preset.machine = machine
        machine.presets = [preset]
        return machine
    }

    private func flattened(_ url: URL) throws -> String {
        let document = try XCTUnwrap(PDFDocument(url: url))
        let raw = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: " ")
        return raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: - CSV

    func testJobCSVHasAHeaderAndOneRowPerWeld() {
        let jobs = [makeJob(), makeJob(title: "Exhaust hanger", daysAgo: 1)]
        let csv = CSVExporter.jobsCSV(for: jobs)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(String(lines[0]), CSVExporter.jobHeader)
        XCTAssertEqual(lines[0].split(separator: ",").count, lines[1].split(separator: ",").count)
    }

    func testJobCSVCarriesBothThicknessUnitsAndTheSettings() {
        let csv = CSVExporter.jobsCSV(for: [makeJob()])
        XCTAssertTrue(csv.contains("\"6.4\""), "millimetres missing")
        XCTAssertTrue(csv.contains("\"0.252\""), "inches missing")
        XCTAssertTrue(csv.contains("\"180\""))
        XCTAssertTrue(csv.contains("\"21.5\""))
        XCTAssertTrue(csv.contains("\"MIG\""))
        XCTAssertTrue(csv.contains("\"Right first try\""))
        XCTAssertTrue(csv.contains("\"Bench feeder\""))
    }

    func testJobCSVRecordsWhetherThereIsAPhoto() {
        let without = CSVExporter.jobsCSV(for: [makeJob()])
        XCTAssertTrue(without.contains("\"no\""))

        let job = makeJob()
        job.photoData = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
            .image { _ in UIColor.orange.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
            .jpegData(compressionQuality: 0.8)
        XCTAssertTrue(CSVExporter.jobsCSV(for: [job]).contains("\"yes\""))
    }

    func testAnEmptyJobCSVIsStillAValidFileWithItsHeader() {
        let csv = CSVExporter.jobsCSV(for: [])
        XCTAssertEqual(csv, CSVExporter.jobHeader + "\n")
    }

    func testBlankNumbersExportAsEmptyCellsRatherThanZero() {
        // A buzz box with an unmarked dial has no amperage to record, and "0" would be a lie.
        let job = makeJob(amps: 0, volts: 0, wfs: 0)
        job.gasFlowCFH = 0
        let row = CSVExporter.jobsCSV(for: [job]).split(separator: "\n")[1]
        XCTAssertTrue(row.contains(",\"\",\"\",\"\",\"\","), "empty numbers should stay empty")
    }

    func testPresetCSVCarriesTheMachineNameAndTheRecommendedRange() {
        let machine = makeMachineWithPresets()
        let csv = CSVExporter.presetsCSV(for: machine.sortedPresets)
        XCTAssertEqual(String(csv.split(separator: "\n")[0]), CSVExporter.presetHeader)
        XCTAssertTrue(csv.contains("\"Bench feeder\""))
        XCTAssertTrue(csv.contains("\"Trailer brackets\""))
        let recommendation = WeldAdvisor.recommend(for: machine.sortedPresets[0].selection)
        XCTAssertTrue(csv.contains("\"\(recommendation.ampsLow)-\(recommendation.ampsHigh)\""))
    }

    func testCSVEscapesQuotesAndCommas() {
        XCTAssertEqual(CSVExporter.quote(#"say "hi""#), #""say ""hi""""#)
        let job = makeJob(title: #"A "special" one, twice"#)
        let csv = CSVExporter.jobsCSV(for: [job])
        XCTAssertTrue(csv.contains(#""A ""special"" one, twice""#))
        XCTAssertEqual(csv.split(separator: "\n").count, 2, "an embedded comma must not split the row")
    }

    func testCSVNumberFormattingDropsTrailingZeroes() {
        XCTAssertEqual(CSVExporter.number(180), "180")
        XCTAssertEqual(CSVExporter.number(21.5), "21.5")
    }

    // MARK: - The setting card

    func testSettingCardNamesTheMachineAndItsPresets() throws {
        let url = try PDFExporter.exportSettingCard(for: makeMachineWithPresets())
        let text = try flattened(url)

        XCTAssertTrue(text.contains("Machine setting card"))
        XCTAssertTrue(text.contains("Bench feeder"))
        XCTAssertTrue(text.contains("Trailer brackets"))
        // Label and value are drawn as two runs, so they are asserted separately (rule 7).
        XCTAssertTrue(text.contains("Set to"))
        XCTAssertTrue(text.contains("180 A"))
        XCTAssertTrue(text.contains("Starting point"))
        XCTAssertTrue(text.contains("Back off 10 A on a long lead."))
    }

    func testEveryPdfCarriesTheStartingPointAndIndependenceNotices() throws {
        let card = try flattened(try PDFExporter.exportSettingCard(for: makeMachineWithPresets()))
        let record = try flattened(try PDFExporter.exportWeldRecord([makeJob()]))

        for text in [card, record] {
            XCTAssertTrue(text.contains("starting points"), "the starting-point notice is missing")
            XCTAssertTrue(text.contains("not a specification"))
            XCTAssertTrue(text.contains("not affiliated with"), "the independence notice is missing")
        }
    }

    func testASettingCardForAMachineWithNoPresetsSaysSoRatherThanPrintingBlank() throws {
        let machine = Machine(name: "New TIG")
        let text = try flattened(try PDFExporter.exportSettingCard(for: machine))
        XCTAssertTrue(text.contains("New TIG"))
        XCTAssertTrue(text.contains("No presets have been saved on this machine yet."))
    }

    // MARK: - The weld record

    func testWeldRecordListsEachWeldWithItsMetalAndSettings() throws {
        let jobs = [makeJob(), makeJob(title: "Exhaust hanger", daysAgo: 3, notes: "Came down to 48.")]
        let text = try flattened(try PDFExporter.exportWeldRecord(jobs))

        XCTAssertTrue(text.contains("Weld record"))
        XCTAssertTrue(text.contains("2 welds logged"))
        XCTAssertTrue(text.contains("Trailer fender bracket"))
        XCTAssertTrue(text.contains("Exhaust hanger"))
        XCTAssertTrue(text.contains("Mild steel"))
        XCTAssertTrue(text.contains("6.4 mm"))
        XCTAssertTrue(text.contains("1/4 in"))
        XCTAssertTrue(text.contains("Right first try"))
        XCTAssertTrue(text.contains("Came down to 48."))
    }

    func testWeldRecordSaysOneWeldInTheSingular() throws {
        let text = try flattened(try PDFExporter.exportWeldRecord([makeJob()]))
        XCTAssertTrue(text.contains("1 weld logged"))
        XCTAssertFalse(text.contains("1 welds logged"))
    }

    func testAnEmptyWeldRecordStillRendersAPage() throws {
        let url = try PDFExporter.exportWeldRecord([])
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
        XCTAssertTrue(try flattened(url).contains("No welds have been logged yet."))
    }

    func testALongRecordPaginatesRatherThanRunningOffThePage() throws {
        let jobs = (0..<40).map { makeJob(title: "Weld number \($0)", daysAgo: $0) }
        let document = try XCTUnwrap(PDFDocument(url: try PDFExporter.exportWeldRecord(jobs)))
        XCTAssertGreaterThan(document.pageCount, 1)
        let text = try flattened(try PDFExporter.exportWeldRecord(jobs))
        XCTAssertTrue(text.contains("Weld number 0"))
        XCTAssertTrue(text.contains("Weld number 39"))
    }

    func testStickWeldsPrintTheElectrodeAndMigWeldsDoNot() throws {
        let stick = makeJob(title: "Gate hinge",
                            selection: WeldSelection(process: .stick, material: .mildSteel, thicknessMM: 9.5,
                                                     joint: .fillet, position: .verticalUp, electrode: .e7018))
        let stickText = try flattened(try PDFExporter.exportWeldRecord([stick]))
        XCTAssertTrue(stickText.contains("E7018"))
        XCTAssertTrue(stickText.contains("Electrode"))

        let migText = try flattened(try PDFExporter.exportWeldRecord([makeJob()]))
        XCTAssertFalse(migText.contains("E7018"))
    }

    func testNoManufacturerNameReachesAnExport() throws {
        let brands = ["Miller", "Lincoln", "Hobart", "ESAB", "Fronius"]
        let card = try flattened(try PDFExporter.exportSettingCard(for: makeMachineWithPresets()))
        let record = try flattened(try PDFExporter.exportWeldRecord([makeJob()]))
        let csv = CSVExporter.jobsCSV(for: [makeJob()]) + CSVExporter.presetsCSV(for: makeMachineWithPresets().sortedPresets)
        for brand in brands {
            for text in [card, record, csv] {
                XCTAssertFalse(text.contains(brand), "\(brand) reached an export")
            }
        }
    }
}
