import XCTest
@testable import WeldSettings

/// The advisor. These tests do two jobs: check the arithmetic, and check the **honesty** — that
/// nothing comes back as a single fabricated figure, that stick's published ranges are not quietly
/// rewritten, and that every card carries the sentence saying it is a starting point.
final class WeldAdvisorTests: XCTestCase {

    private func selection(_ process: WeldProcess = .mig,
                           _ material: BaseMaterial = .mildSteel,
                           mm: Double = 3.0,
                           joint: JointType = .butt,
                           position: WeldPosition = .flat,
                           electrode: StickElectrode = .e7018) -> WeldSelection {
        WeldSelection(process: process, material: material, thicknessMM: mm,
                      joint: joint, position: position, electrode: electrode)
    }

    // MARK: - The rule of thumb

    func testOneAmpPerThousandthOfAnInchOnMildSteel() {
        // 1/8 in mild steel is 125 thou, so the range straddles about 125 A.
        let card = WeldAdvisor.recommend(for: selection(.mig, .mildSteel, mm: 3.175))
        XCTAssertLessThan(card.ampsLow, 125)
        XCTAssertGreaterThan(card.ampsHigh, 125)
        XCTAssertEqual(Double(card.ampsLow + card.ampsHigh) / 2, 125, accuracy: 15)
    }

    func testEveryAnswerIsARangeAndNeverASingleNumber() {
        for process in WeldProcess.allCases {
            for material in BaseMaterial.allCases {
                for mm in [0.8, 1.5, 3.0, 6.0, 12.0] {
                    let card = WeldAdvisor.recommend(for: selection(process, material, mm: mm))
                    XCTAssertLessThan(card.ampsLow, card.ampsHigh,
                                      "\(process.shortName)/\(material.name)/\(mm)mm collapsed to one figure")
                    XCTAssertGreaterThan(card.ampsLow, 0)
                    XCTAssertTrue(card.ampsText.contains("–"), "the card should read as a range")
                }
            }
        }
    }

    func testThickerMetalAlwaysAsksForMoreCurrent() {
        for process in [WeldProcess.mig, .tig] {
            var previous = 0
            for mm in [1.0, 2.0, 3.0, 4.0, 5.0] {
                let card = WeldAdvisor.recommend(for: selection(process, .mildSteel, mm: mm))
                XCTAssertGreaterThan(card.ampsHigh, previous, "\(process.shortName) went backwards at \(mm) mm")
                previous = card.ampsHigh
            }
        }
    }

    func testAluminiumTakesMoreCurrentThanSteelAndStainlessTakesLess() {
        let steel = WeldAdvisor.recommend(for: selection(.tig, .mildSteel, mm: 3.0))
        let stainless = WeldAdvisor.recommend(for: selection(.tig, .stainless, mm: 3.0))
        let aluminium = WeldAdvisor.recommend(for: selection(.tig, .aluminium, mm: 3.0))

        XCTAssertGreaterThan(aluminium.ampsLow, steel.ampsLow)
        XCTAssertLessThan(stainless.ampsLow, steel.ampsLow)
    }

    func testOutOfPositionComesDownAndAFilletGoesUp() {
        let flat = WeldAdvisor.recommend(for: selection(.mig, .mildSteel, mm: 4.0, joint: .butt, position: .flat))
        let overhead = WeldAdvisor.recommend(for: selection(.mig, .mildSteel, mm: 4.0, joint: .butt, position: .overhead))
        let fillet = WeldAdvisor.recommend(for: selection(.mig, .mildSteel, mm: 4.0, joint: .fillet, position: .flat))
        let corner = WeldAdvisor.recommend(for: selection(.mig, .mildSteel, mm: 4.0, joint: .outsideCorner, position: .flat))

        XCTAssertLessThan(overhead.ampsHigh, flat.ampsHigh)
        XCTAssertGreaterThan(fillet.ampsHigh, flat.ampsHigh)
        XCTAssertLessThan(corner.ampsHigh, flat.ampsHigh)
    }

    // MARK: - MIG

    func testMigAsksForVoltageAndWireSpeedAndTigDoesNot() {
        let mig = WeldAdvisor.recommend(for: selection(.mig))
        XCTAssertTrue(mig.lines.contains { $0.label == "Voltage" })
        XCTAssertTrue(mig.lines.contains { $0.label == "Wire speed" })

        let tig = WeldAdvisor.recommend(for: selection(.tig))
        XCTAssertFalse(tig.lines.contains { $0.label == "Voltage" })
        XCTAssertFalse(tig.lines.contains { $0.label == "Wire speed" })
        XCTAssertTrue(tig.lines.contains { $0.label == "Tungsten" })
    }

    func testWireGetsFatterAsThePlateGetsThicker() {
        XCTAssertEqual(WeldAdvisor.wireDiameter(for: selection(.mig, .mildSteel, mm: 1.0)), 0.6)
        XCTAssertEqual(WeldAdvisor.wireDiameter(for: selection(.mig, .mildSteel, mm: 3.0)), 0.8)
        XCTAssertEqual(WeldAdvisor.wireDiameter(for: selection(.mig, .mildSteel, mm: 5.0)), 0.9)
        XCTAssertEqual(WeldAdvisor.wireDiameter(for: selection(.mig, .mildSteel, mm: 10.0)), 1.2)
    }

    func testAluminiumNeverGetsHairThinWire() {
        // Soft wire under 0.9 mm buckles in the liner. Thin aluminium gets the bigger wire and a
        // warning, rather than a setting that cannot physically be fed.
        XCTAssertEqual(WeldAdvisor.wireDiameter(for: selection(.mig, .aluminium, mm: 1.0)), 0.9)
        let card = WeldAdvisor.recommend(for: selection(.mig, .aluminium, mm: 1.0))
        XCTAssertTrue(card.cautions.contains { $0.contains("very hard with short-circuit MIG") })
        XCTAssertTrue(card.lines.contains { $0.label == "Feeding" })
    }

    func testWireSpeedFallsAsTheWireGetsFatterAtTheSameCurrent() {
        let thin = WeldAdvisor.meltOffRate(diameterMM: 0.6, material: .mildSteel)
        let mid = WeldAdvisor.meltOffRate(diameterMM: 0.9, material: .mildSteel)
        let fat = WeldAdvisor.meltOffRate(diameterMM: 1.2, material: .mildSteel)
        XCTAssertGreaterThan(thin, mid)
        XCTAssertGreaterThan(mid, fat)
        // Aluminium wire is far less dense, so the same current pushes more of it.
        XCTAssertGreaterThan(WeldAdvisor.meltOffRate(diameterMM: 0.9, material: .aluminium), mid)
    }

    func testWireCeilingProducesAWarningRatherThanAnImpossibleNumber() {
        let heavy = WeldAdvisor.recommend(for: selection(.mig, .mildSteel, mm: 25.4, joint: .fillet))
        XCTAssertLessThanOrEqual(heavy.ampsHigh, WeldAdvisor.wireCeiling(diameterMM: 1.2))
        XCTAssertTrue(heavy.cautions.contains { $0.contains("go up a wire size") })
    }

    func testGasFollowsTheMetal() {
        XCTAssertTrue(WeldAdvisor.gas(for: selection(.mig, .mildSteel)).primary.contains("C25"))
        XCTAssertTrue(WeldAdvisor.gas(for: selection(.mig, .stainless)).primary.contains("2% CO2"))
        XCTAssertEqual(WeldAdvisor.gas(for: selection(.mig, .aluminium)).primary, "100% argon")
    }

    func testMigPolarityIsAlwaysElectrodePositive() {
        for material in BaseMaterial.allCases {
            XCTAssertEqual(WeldAdvisor.recommend(for: selection(.mig, material)).polarity, .dcep)
        }
    }

    // MARK: - TIG

    func testTigPolarityIsDcenExceptOnAluminium() {
        XCTAssertEqual(WeldAdvisor.recommend(for: selection(.tig, .mildSteel)).polarity, .dcen)
        XCTAssertEqual(WeldAdvisor.recommend(for: selection(.tig, .stainless)).polarity, .dcen)
        XCTAssertEqual(WeldAdvisor.recommend(for: selection(.tig, .aluminium)).polarity, .ac)
    }

    func testAluminiumTigGetsAnAcBalanceRowAndSteelDoesNot() {
        let aluminium = WeldAdvisor.recommend(for: selection(.tig, .aluminium))
        XCTAssertTrue(aluminium.lines.contains { $0.label == "AC balance" })
        let steel = WeldAdvisor.recommend(for: selection(.tig, .mildSteel))
        XCTAssertFalse(steel.lines.contains { $0.label == "AC balance" })
    }

    func testTungstenSizesAndTheirLimits() {
        XCTAssertEqual(WeldAdvisor.tungstenDiameter(for: 1.0), 1.6)
        XCTAssertEqual(WeldAdvisor.tungstenDiameter(for: 3.0), 2.4)
        XCTAssertEqual(WeldAdvisor.tungstenDiameter(for: 10.0), 3.2)
        // AC costs roughly a third of the DC capacity, because half the cycle heats the tungsten.
        XCTAssertLessThan(WeldAdvisor.tungstenCeiling(diameterMM: 2.4, ac: true),
                          WeldAdvisor.tungstenCeiling(diameterMM: 2.4, ac: false))
    }

    func testFillerRodIsAboutTheThicknessOfTheMetal() {
        XCTAssertEqual(WeldAdvisor.fillerDiameter(for: 1.6), 1.6)
        XCTAssertEqual(WeldAdvisor.fillerDiameter(for: 3.2), 3.2)
        // Thin sheet still gets a rod somebody stocks rather than a fabricated 0.7 mm.
        XCTAssertEqual(WeldAdvisor.fillerDiameter(for: 0.6), 1.6)
        XCTAssertEqual(WeldAdvisor.fillerDiameter(for: 25.4), 4.0)
    }

    func testHeavySectionTigIsToldToBevelAndDoMultiplePasses() {
        let card = WeldAdvisor.recommend(for: selection(.tig, .mildSteel, mm: 8.0))
        XCTAssertTrue(card.cautions.contains { $0.contains("multiple passes") })
    }

    // MARK: - Stick

    func testStickUsesThePublishedRangeUntouched() {
        // The whole point: joint and position do not distort a rod maker's published numbers.
        let flat = WeldAdvisor.recommend(for: selection(.stick, .mildSteel, mm: 9.5, joint: .butt, position: .flat, electrode: .e7018))
        let overhead = WeldAdvisor.recommend(for: selection(.stick, .mildSteel, mm: 9.5, joint: .fillet, position: .overhead, electrode: .e7018))

        XCTAssertEqual(flat.ampsLow, overhead.ampsLow)
        XCTAssertEqual(flat.ampsHigh, overhead.ampsHigh)
        XCTAssertEqual(flat.ampsLow, 140)
        XCTAssertEqual(flat.ampsHigh, 190)
        // Instead of rewriting them, the card says where in the range to sit.
        XCTAssertTrue(overhead.cautions.contains { $0.contains("lower part of the published range") })
        XCTAssertFalse(flat.cautions.contains { $0.contains("lower part of the published range") })
    }

    func testDifferentRodsAtTheSameDiameterAreDifferentRanges() {
        let sixOhTen = WeldAdvisor.recommend(for: selection(.stick, .mildSteel, mm: 5.0, electrode: .e6010))
        let seventyEighteen = WeldAdvisor.recommend(for: selection(.stick, .mildSteel, mm: 5.0, electrode: .e7018))
        XCTAssertEqual(sixOhTen.ampsLow, 75)
        XCTAssertEqual(seventyEighteen.ampsLow, 110)
        XCTAssertNotEqual(sixOhTen.ampsHigh, seventyEighteen.ampsHigh)
    }

    func testElectrodeDiameterFollowsTheThickness() {
        XCTAssertEqual(WeldAdvisor.electrodeDiameter(for: 2.0), 2.4)
        XCTAssertEqual(WeldAdvisor.electrodeDiameter(for: 5.0), 3.2)
        XCTAssertEqual(WeldAdvisor.electrodeDiameter(for: 12.0), 4.0)
    }

    func testStickHasNoGasRowValueAndNoWireSpeed() {
        let card = WeldAdvisor.recommend(for: selection(.stick))
        XCTAssertEqual(card.lines.first { $0.label == "Gas" }?.value, "None. The flux is the shielding.")
        XCTAssertFalse(card.lines.contains { $0.label == "Wire speed" })
        XCTAssertFalse(card.lines.contains { $0.label == "Gas flow" })
    }

    func testAnIllegalRodForTheMetalIsCorrectedRatherThanUsed() {
        // A 7018 left selected while the metal is switched to aluminium must not produce a
        // mild-steel range against an aluminium job.
        var choice = selection(.stick, .aluminium, mm: 5.0, electrode: .e7018)
        choice.normalise()
        XCTAssertEqual(choice.electrode, .e4043)

        let card = WeldAdvisor.recommend(for: selection(.stick, .aluminium, mm: 5.0, electrode: .e7018))
        XCTAssertEqual(card.selection.electrode, .e4043)
        XCTAssertEqual(card.ampsLow, 70)
        XCTAssertTrue(card.cautions.contains { $0.contains("last resort") })
    }

    func testStickOnSheetIsWarnedAbout() {
        let card = WeldAdvisor.recommend(for: selection(.stick, .mildSteel, mm: 1.5, electrode: .e6013))
        XCTAssertTrue(card.cautions.contains { $0.contains("blows through") })
    }

    func testSeventyEighteenGetsItsRodStorageRow() {
        let card = WeldAdvisor.recommend(for: selection(.stick, .mildSteel, mm: 9.5, electrode: .e7018))
        XCTAssertTrue(card.lines.contains { $0.label == "Rod storage" })
        let sixOhTen = WeldAdvisor.recommend(for: selection(.stick, .mildSteel, mm: 9.5, electrode: .e6010))
        XCTAssertFalse(sixOhTen.lines.contains { $0.label == "Rod storage" })
    }

    // MARK: - Honesty

    func testEveryCardSaysItIsAStartingPoint() {
        for process in WeldProcess.allCases {
            for material in BaseMaterial.allCases {
                let card = WeldAdvisor.recommend(for: selection(process, material, mm: 3.0))
                XCTAssertTrue(card.cautions.contains { $0.contains("starting points") },
                              "\(process.shortName)/\(material.name) card has no starting-point notice")
                XCTAssertFalse(card.technique.isEmpty)
                XCTAssertFalse(card.polarityNote.isEmpty)
            }
        }
    }

    func testEverySettingRowSaysWhichWayToMoveIt() {
        for process in WeldProcess.allCases {
            let card = WeldAdvisor.recommend(for: selection(process, .mildSteel, mm: 3.0))
            XCTAssertFalse(card.lines.isEmpty)
            for line in card.lines {
                XCTAssertFalse(line.moveIt.isEmpty, "\(process.shortName) · \(line.label) has no advice")
                XCTAssertFalse(line.value.isEmpty)
            }
        }
    }

    func testStructuralPlateIsPointedAtTheProcedureNotTheDial() {
        let card = WeldAdvisor.recommend(for: selection(.mig, .mildSteel, mm: 12.0))
        XCTAssertTrue(card.cautions.contains { $0.contains("WPS wins") })
    }

    func testNoBrandNameAppearsAnywhereOnACard() {
        // Trademark safety, enforced rather than remembered. Apple's IP process can pull an app
        // after review, so a stray "Miller" in a technique note is a real risk.
        let brands = ["Miller", "Lincoln", "Hobart", "ESAB", "Fronius", "Kemppi", "Everlast", "Hypertherm"]
        for process in WeldProcess.allCases {
            for material in BaseMaterial.allCases {
                for position in WeldPosition.allCases {
                    let card = WeldAdvisor.recommend(for: selection(process, material, mm: 4.0, position: position))
                    let text = ([card.polarityNote] + card.technique + card.cautions
                                + card.lines.map { "\($0.label) \($0.value) \($0.alternate ?? "") \($0.moveIt)" })
                        .joined(separator: " ")
                    for brand in brands {
                        XCTAssertFalse(text.contains(brand), "\(brand) appears on a \(process.shortName) card")
                    }
                }
            }
        }
    }

    func testBeadDiagnosticsCoverEveryProcessAndNameAFix() {
        for process in WeldProcess.allCases {
            let symptoms = BeadDiagnostics.symptoms(for: process)
            XCTAssertGreaterThanOrEqual(symptoms.count, 7, "\(process.shortName) has too few symptoms to be useful")
            for symptom in symptoms {
                XCTAssertFalse(symptom.cause.isEmpty)
                XCTAssertFalse(symptom.fix.isEmpty)
            }
            XCTAssertEqual(Set(symptoms.map(\.id)).count, symptoms.count, "duplicate symptom on \(process.shortName)")
        }
    }

    // MARK: - Edges

    func testTheThinnestAndThickestStepsBothProduceASaneCard() {
        for process in WeldProcess.allCases {
            let thin = WeldAdvisor.recommend(for: selection(process, .mildSteel, mm: Thickness.steps.first!))
            let thick = WeldAdvisor.recommend(for: selection(process, .mildSteel, mm: Thickness.steps.last!))
            XCTAssertGreaterThanOrEqual(thin.ampsLow, 10)
            XCTAssertLessThan(thin.ampsLow, thin.ampsHigh)
            XCTAssertLessThan(thick.ampsHigh, 500)
            XCTAssertLessThan(thick.ampsLow, thick.ampsHigh)
        }
    }

    func testZeroThicknessDoesNotProduceZeroOrNegativeAmps() {
        for process in WeldProcess.allCases {
            let card = WeldAdvisor.recommend(for: selection(process, .mildSteel, mm: 0))
            XCTAssertGreaterThan(card.ampsLow, 0, "\(process.shortName) returned a non-positive current")
            XCTAssertGreaterThan(card.ampsHigh, card.ampsLow)
        }
    }

    func testTheHeadlineReadsLikeAWelderWouldSayIt() {
        let choice = selection(.tig, .stainless, mm: 1.6, joint: .fillet)
        XCTAssertEqual(choice.headline, "TIG · Stainless · 1.6 mm · fillet or tee")
    }
}
