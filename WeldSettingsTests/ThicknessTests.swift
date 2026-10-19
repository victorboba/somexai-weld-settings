import XCTest
@testable import WeldSettings

/// The conversions. Every number asserted here is a published decimal equivalent, so these tests
/// are really checking that the tables were not fat-fingered — which is the only kind of error
/// this part of the app can have, and the kind that puts a hole in somebody's panel.
final class ThicknessTests: XCTestCase {

    func testSixteenGaugeIsADifferentThicknessInEachMaterial() {
        let steel = Thickness.millimetres(gauge: 16, material: .mildSteel)!
        let stainless = Thickness.millimetres(gauge: 16, material: .stainless)!
        let aluminium = Thickness.millimetres(gauge: 16, material: .aluminium)!

        XCTAssertEqual(steel, 1.519, accuracy: 0.005)
        XCTAssertEqual(stainless, 1.588, accuracy: 0.005)
        XCTAssertEqual(aluminium, 1.290, accuracy: 0.005)

        // The whole reason the app carries three tables.
        XCTAssertNotEqual(steel, stainless)
        XCTAssertNotEqual(steel, aluminium)
        XCTAssertGreaterThan(steel - aluminium, 0.2)
    }

    func testEveryGaugeTableIsMonotonic() {
        for material in BaseMaterial.allCases {
            let numbers = Thickness.gaugeNumbers(for: material)
            XCTAssertFalse(numbers.isEmpty, "\(material.name) has no gauge table")
            for (thinner, thicker) in zip(numbers.dropFirst(), numbers) {
                let a = Thickness.millimetres(gauge: thinner, material: material)!
                let b = Thickness.millimetres(gauge: thicker, material: material)!
                XCTAssertLessThan(a, b, "gauge \(thinner) should be thinner than \(thicker) in \(material.name)")
            }
        }
    }

    func testInchAndMillimetreRoundTrip() {
        XCTAssertEqual(Thickness.millimetres(inches: 0.125), 3.175, accuracy: 0.0001)
        XCTAssertEqual(Thickness.inches(millimetres: 25.4), 1.0, accuracy: 0.0001)
        for mm in Thickness.steps {
            XCTAssertEqual(Thickness.millimetres(inches: Thickness.inches(millimetres: mm)), mm, accuracy: 0.0001)
        }
    }

    func testNearestGaugeFindsTheGaugeItCameFrom() {
        for material in BaseMaterial.allCases {
            for gauge in Thickness.gaugeNumbers(for: material) {
                let mm = Thickness.millimetres(gauge: gauge, material: material)!
                XCTAssertEqual(Thickness.nearestGauge(millimetres: mm, material: material), gauge,
                               "\(gauge) ga in \(material.name) did not round-trip")
            }
        }
    }

    func testPlateHasNoGaugeNumber() {
        // A quarter inch of plate is not "3 gauge". Inventing a number would be the fabricated
        // precision this app exists to avoid.
        XCTAssertNil(Thickness.nearestGauge(millimetres: 12.7, material: .mildSteel))
        XCTAssertNil(Thickness.nearestGauge(millimetres: 25.4, material: .stainless))
        // And neither is foil.
        XCTAssertNil(Thickness.nearestGauge(millimetres: 0.05, material: .mildSteel))
    }

    func testInchFormattingUsesShopFractions() {
        XCTAssertEqual(Thickness.formatInch(3.175), "1/8 in")
        XCTAssertEqual(Thickness.formatInch(1.5875), "1/16 in")
        XCTAssertEqual(Thickness.formatInch(4.7625), "3/16 in")
        XCTAssertEqual(Thickness.formatInch(6.35), "1/4 in")
        XCTAssertEqual(Thickness.formatInch(25.4), "1 in")
    }

    func testMillimetreFormattingTrimsTrailingZeroes() {
        XCTAssertEqual(Thickness.formatMM(3.0), "3 mm")
        XCTAssertEqual(Thickness.formatMM(1.52), "1.52 mm")
        XCTAssertEqual(Thickness.formatMM(0.5), "0.5 mm")
    }

    func testDescribeLeadsWithTheChosenUnit() {
        let mm = Thickness.millimetres(gauge: 16, material: .mildSteel)!
        XCTAssertTrue(Thickness.describe(mm, material: .mildSteel, preferring: .gauge).hasPrefix("16 ga"))
        XCTAssertTrue(Thickness.describe(mm, material: .mildSteel, preferring: .millimetre).hasPrefix("1.52 mm"))
        XCTAssertTrue(Thickness.describe(mm, material: .mildSteel, preferring: .inch).hasPrefix("0.060 in"))
        // Plate still describes, it just has no gauge to offer.
        let plate = Thickness.describe(12.7, material: .mildSteel, preferring: .millimetre)
        XCTAssertTrue(plate.contains("1/2 in"))
        XCTAssertFalse(plate.contains("ga"))
    }

    func testFlowConversion() {
        XCTAssertEqual(Thickness.litresPerMinute(cfh: 20), 9.44, accuracy: 0.02)
        XCTAssertEqual(Thickness.formatFlow(20, unit: .cfh), "20 CFH")
        XCTAssertEqual(Thickness.formatFlow(20, unit: .litresPerMinute), "9.4 L/min")
        XCTAssertEqual(Thickness.litresPerMinute(cfh: 0), 0)
    }

    func testSnapLandsOnAStockedThickness() {
        XCTAssertEqual(Thickness.snap(2.9), 3.0)
        XCTAssertEqual(Thickness.snap(6.3), 6.4)
        // Below and above the table it clamps to the ends rather than extrapolating.
        XCTAssertEqual(Thickness.snap(0.01), Thickness.steps.first!)
        XCTAssertEqual(Thickness.snap(500), Thickness.steps.last!)
    }
}
