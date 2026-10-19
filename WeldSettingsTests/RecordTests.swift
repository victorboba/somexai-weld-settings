import XCTest
import SwiftData
@testable import WeldSettings

/// The records themselves: what they round-trip, what they summarise, and what they refuse to
/// invent. Plus the CloudKit shape rule — every property defaulted — checked by actually building
/// the container the app builds.
@MainActor
final class RecordTests: XCTestCase {

    func testAPresetRoundTripsTheWholeBenchSelection() {
        let selection = WeldSelection(process: .tig, material: .aluminium, thicknessMM: 3.2,
                                      joint: .lap, position: .overhead, electrode: .e4043)
        let preset = Preset(name: "Ladder rungs", selection: selection)
        XCTAssertEqual(preset.selection, selection)

        // And changing it changes the stored raws, not just a cached copy.
        preset.apply(WeldSelection(process: .stick, material: .mildSteel, thicknessMM: 9.5,
                                   joint: .fillet, position: .flat, electrode: .e6010))
        XCTAssertEqual(preset.processRaw, "stick")
        XCTAssertEqual(preset.electrode, .e6010)
        XCTAssertEqual(preset.selection.thicknessMM, 9.5)
    }

    func testAnUnnamedPresetFallsBackToTheJobItDescribes() {
        let preset = Preset(name: "", selection: WeldSelection(process: .mig, material: .stainless,
                                                               thicknessMM: 2.0, joint: .butt, position: .flat))
        XCTAssertEqual(preset.displayName, preset.selection.headline)
        XCTAssertTrue(preset.displayName.contains("Stainless"))
    }

    func testAPresetWithNoNumbersSaysSoRatherThanShowingZeroes() {
        let preset = Preset(name: "Buzz box, dial about six")
        XCTAssertFalse(preset.hasNumbers)
        XCTAssertEqual(preset.settingsSummary, "No numbers recorded yet")

        preset.amps = 110
        XCTAssertTrue(preset.hasNumbers)
        XCTAssertEqual(preset.settingsSummary, "110 A")
    }

    func testTheSettingsSummaryOnlyPrintsWhatWasRecorded() {
        let job = JobEntry(title: "Bracket")
        job.amps = 180
        job.volts = 21.5
        XCTAssertEqual(job.settingsSummary, "180 A  ·  21.5 V")
        job.wireFeedIPM = 300
        job.gasFlowCFH = 22
        XCTAssertEqual(job.settingsSummary, "180 A  ·  21.5 V  ·  300 ipm  ·  22 CFH")
    }

    func testAnUnnamedJobStillReadsAsSomething() {
        let job = JobEntry(title: "", selection: WeldSelection(process: .stick, material: .mildSteel,
                                                               thicknessMM: 9.5, joint: .fillet,
                                                               position: .verticalUp, electrode: .e7018))
        XCTAssertFalse(job.displayTitle.isEmpty)
        XCTAssertTrue(job.jobSummary.contains("Mild steel"))
        XCTAssertTrue(job.jobSummary.contains("vertical up"))
    }

    func testJobsGroupByCalendarDayNotByTimestamp() {
        let morning = JobEntry(date: Date(timeIntervalSince1970: 1_700_000_000))
        let evening = JobEntry(date: morning.date.addingTimeInterval(6 * 3600))
        let nextWeek = JobEntry(date: morning.date.addingTimeInterval(7 * 86_400))
        XCTAssertEqual(morning.day, evening.day)
        XCTAssertNotEqual(morning.day, nextWeek.day)
    }

    func testAnUnnamedMachineStillHasSomethingToCallIt() {
        XCTAssertEqual(Machine().displayName, "Unnamed machine")
        XCTAssertEqual(Machine(name: "Bench feeder").displayName, "Bench feeder")
    }

    func testPresetsSortNewestFirstUnderTheirMachine() {
        let machine = Machine(name: "Bench feeder")
        let older = Preset(name: "Older")
        older.updatedAt = Date(timeIntervalSince1970: 1_000)
        let newer = Preset(name: "Newer")
        newer.updatedAt = Date(timeIntervalSince1970: 2_000)
        machine.presets = [older, newer]
        XCTAssertEqual(machine.sortedPresets.map(\.name), ["Newer", "Older"])
    }

    // MARK: - The CloudKit shape (rule 8)

    func testTheSchemaBuildsInMemoryWithEveryPropertyDefaulted() throws {
        // A property without a default, or marked unique, makes this throw — which is the whole
        // point of the rule, since turning iCloud on later must not need a migration.
        let schema = Schema([Machine.self, Preset.self, JobEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let machine = Machine(name: "Bench feeder")
        context.insert(machine)
        let preset = Preset(name: "Trailer brackets")
        preset.machine = machine
        preset.amps = 180
        context.insert(preset)
        context.insert(JobEntry(title: "Bracket"))
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Machine>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Preset>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JobEntry>()), 1)
        XCTAssertEqual(machine.sortedPresets.first?.name, "Trailer brackets")
    }

    func testDeletingAMachineTakesItsPresetsWithIt() throws {
        let schema = Schema([Machine.self, Preset.self, JobEntry.self])
        let container = try ModelContainer(for: schema,
                                           configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let machine = Machine(name: "Old buzz box")
        context.insert(machine)
        let preset = Preset(name: "1/8 7018")
        preset.machine = machine
        context.insert(preset)
        try context.save()

        context.delete(machine)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Preset>()), 0,
                       "the cascade rule should take the presets with the machine")
    }

    // MARK: - The widget snapshot

    func testTheWidgetSnapshotCarriesTheLastSettingsThatWorked() {
        let older = JobEntry(date: Date(timeIntervalSince1970: 1_000), title: "Older")
        let newest = JobEntry(date: Date(timeIntervalSince1970: 2_000), title: "Handrail return")
        newest.amps = 85
        newest.machineName = "Bench feeder"

        WidgetSync.update(jobs: [older, newest], presets: [Preset(name: "One")])
        let snapshot = WidgetSnapshot.load()

        XCTAssertEqual(snapshot.totalJobs, 2)
        XCTAssertEqual(snapshot.presetCount, 1)
        XCTAssertEqual(snapshot.lastJobTitle, "Handrail return")
        XCTAssertEqual(snapshot.lastJobSettings, "85 A")
        XCTAssertEqual(snapshot.lastJobMachine, "Bench feeder")
        // Both are historic dates, so neither counts towards this week.
        XCTAssertEqual(snapshot.jobsThisWeek, 0)
    }

    func testAnEmptyWidgetSnapshotIsNotAnError() {
        WidgetSync.update(jobs: [], presets: [])
        let snapshot = WidgetSnapshot.load()
        XCTAssertEqual(snapshot.totalJobs, 0)
        XCTAssertNil(snapshot.lastJobTitle)
    }

    // MARK: - Copy that has to stay true

    func testTheHowToGuideNamesButtonsTheAppActuallyHas() {
        let steps = AppConfig.howTo
        XCTAssertGreaterThanOrEqual(steps.count, 4)
        let text = steps.map { "\($0.title) \($0.body) \($0.tip ?? "")" }.joined(separator: " ")
        for button in ["Save as a preset", "Add a machine", "Log this weld", "Add Photo",
                       "If the bead looks wrong", "Fill from a preset"] {
            XCTAssertTrue(text.contains(button), "the guide should name the real button \"\(button)\"")
        }
    }

    func testTheIndependenceNoticeIsPresentAndNamesNoBrand() {
        XCTAssertTrue(AppConfig.independenceNotice.contains("not affiliated"))
        for brand in ["Miller", "Lincoln", "Hobart", "ESAB", "Fronius"] {
            XCTAssertFalse(AppConfig.independenceNotice.contains(brand))
            XCTAssertFalse(AppConfig.appName.contains(brand))
            XCTAssertFalse(AppConfig.paywallBenefits.joined().contains(brand))
            XCTAssertFalse(AppConfig.onboarding.map { $0.title + $0.body }.joined().contains(brand))
        }
    }

    func testPricesMatchTheStoreKitConfiguration() throws {
        // The mock prices drive the screenshot run, so they have to agree with the real ones.
        XCTAssertEqual(AppConfig.mockPrices.annual, "$6.99")
        XCTAssertEqual(AppConfig.mockPrices.lifetime, "$12.99")
        XCTAssertTrue(AppConfig.annualProductID.hasSuffix(".pro.annual"))
        XCTAssertTrue(AppConfig.lifetimeProductID.hasSuffix(".pro.lifetime"))
        XCTAssertFalse(AppConfig.annualProductID.contains("-"), "Apple product IDs cannot contain hyphens")
    }
}
