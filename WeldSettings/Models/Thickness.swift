import Foundation

/// Thickness, and the three ways a shop says it.
///
/// Half the bench thinks in gauge, half in millimetres, and the drawing is in inches. Worse,
/// **gauge is not one scale**: sheet steel uses the manufacturers' standard gauge, stainless
/// uses the US standard gauge, and aluminium uses Brown and Sharpe. 16 gauge is 1.52 mm in mild
/// steel, 1.59 mm in stainless and 1.29 mm in aluminium — a quarter of a millimetre apart at the
/// thin end, which is the difference between a weld and a hole.
///
/// Everything inside the app is millimetres. The unit is a display choice, never a stored one.
enum Thickness {
    static let mmPerInch = 25.4

    // MARK: - Gauge tables
    //
    // Published decimal equivalents, in inches. They are reference data, not estimates: the
    // whole point of this table is that it is the real one for that material.

    /// Manufacturers' standard gauge for sheet steel.
    static let steelGauge: [Int: Double] = [
        3: 0.2391, 4: 0.2242, 5: 0.2092, 6: 0.1943, 7: 0.1793, 8: 0.1644, 9: 0.1495,
        10: 0.1345, 11: 0.1196, 12: 0.1046, 13: 0.0897, 14: 0.0747, 15: 0.0673,
        16: 0.0598, 17: 0.0538, 18: 0.0478, 19: 0.0418, 20: 0.0359, 21: 0.0329,
        22: 0.0299, 23: 0.0269, 24: 0.0239, 25: 0.0209, 26: 0.0179,
    ]

    /// US standard gauge, used for stainless sheet.
    static let stainlessGauge: [Int: Double] = [
        3: 0.2500, 4: 0.2344, 5: 0.2187, 6: 0.2031, 7: 0.1875, 8: 0.1719, 9: 0.1563,
        10: 0.1406, 11: 0.1250, 12: 0.1094, 13: 0.0938, 14: 0.0781, 15: 0.0703,
        16: 0.0625, 17: 0.0563, 18: 0.0500, 19: 0.0438, 20: 0.0375, 21: 0.0344,
        22: 0.0313, 23: 0.0281, 24: 0.0250, 25: 0.0219, 26: 0.0188,
    ]

    /// Brown and Sharpe (American wire gauge), used for aluminium sheet.
    static let aluminiumGauge: [Int: Double] = [
        3: 0.2294, 4: 0.2043, 5: 0.1819, 6: 0.1620, 7: 0.1443, 8: 0.1285, 9: 0.1144,
        10: 0.1019, 11: 0.0907, 12: 0.0808, 13: 0.0720, 14: 0.0641, 15: 0.0571,
        16: 0.0508, 17: 0.0453, 18: 0.0403, 19: 0.0359, 20: 0.0320, 21: 0.0285,
        22: 0.0253, 23: 0.0226, 24: 0.0201, 25: 0.0179, 26: 0.0159,
    ]

    static func gaugeTable(for material: BaseMaterial) -> [Int: Double] {
        switch material {
        case .mildSteel: return steelGauge
        case .stainless: return stainlessGauge
        case .aluminium: return aluminiumGauge
        }
    }

    /// The gauge numbers offered, thickest first, so a picker reads the way a rack does.
    static func gaugeNumbers(for material: BaseMaterial) -> [Int] {
        gaugeTable(for: material).keys.sorted()
    }

    // MARK: - Conversions

    static func millimetres(gauge: Int, material: BaseMaterial) -> Double? {
        guard let inches = gaugeTable(for: material)[gauge] else { return nil }
        return inches * mmPerInch
    }

    static func millimetres(inches: Double) -> Double { inches * mmPerInch }

    static func inches(millimetres mm: Double) -> Double { mm / mmPerInch }

    /// The gauge number whose published thickness is nearest, or nil when the material is
    /// thicker than any sheet gauge — plate is called by its inch or millimetre size and
    /// pretending otherwise would be inventing a number.
    static func nearestGauge(millimetres mm: Double, material: BaseMaterial) -> Int? {
        let table = gaugeTable(for: material)
        guard let thickest = table.values.max(), mm <= thickest * mmPerInch * 1.05 else { return nil }
        guard let thinnest = table.values.min(), mm >= thinnest * mmPerInch * 0.95 else { return nil }
        return table.min { lhs, rhs in
            abs(lhs.value * mmPerInch - mm) < abs(rhs.value * mmPerInch - mm)
        }?.key
    }

    // MARK: - Display

    /// Millimetres, trimmed: 1.5 rather than 1.50, 10 rather than 10.0.
    static func formatMM(_ mm: Double) -> String {
        let rounded = (mm * 100).rounded() / 100
        return rounded == rounded.rounded() ? "\(Int(rounded)) mm" : String(format: "%g mm", rounded)
    }

    /// Inches as a shop fraction where one lands within a thirty-second, and as a decimal where
    /// it does not. "3/16 in" is what gets said out loud; "0.1875 in" is not.
    static func formatInch(_ mm: Double) -> String {
        let inches = Thickness.inches(millimetres: mm)
        let thirtySeconds = (inches * 32).rounded()
        // Within 1.5% of a thirty-second, call it that fraction; otherwise print the decimal.
        // A relative tolerance is what keeps 6.4 mm reading as 1/4 in (0.8% out) while 16 gauge
        // steel stays 0.060 in rather than being rounded up to a 1/16 it is 4% away from.
        if thirtySeconds >= 1, abs(inches * 32 - thirtySeconds) <= 0.015 * inches * 32 {
            var numerator = Int(thirtySeconds)
            var denominator = 32
            while numerator % 2 == 0 && denominator > 1 {
                numerator /= 2
                denominator /= 2
            }
            return denominator == 1 ? "\(numerator) in" : "\(numerator)/\(denominator) in"
        }
        return String(format: "%.3f in", inches)
    }

    /// The whole line as the bench wants it: the chosen unit first, the other two after, so the
    /// welder reading a drawing in inches and a rack labelled in gauge never has to convert.
    static func describe(_ mm: Double, material: BaseMaterial, preferring unit: ThicknessUnit) -> String {
        let mmText = formatMM(mm)
        let inchText = formatInch(mm)
        let gaugeText = nearestGauge(millimetres: mm, material: material).map { "\($0) ga" }

        switch unit {
        case .millimetre:
            return [mmText, inchText, gaugeText].compactMap { $0 }.joined(separator: "  ·  ")
        case .inch:
            return [inchText, mmText, gaugeText].compactMap { $0 }.joined(separator: "  ·  ")
        case .gauge:
            return [gaugeText, mmText, inchText].compactMap { $0 }.joined(separator: "  ·  ")
        }
    }

    /// The thicknesses the bench slider steps through, in millimetres. Dense where sheet metal
    /// lives, coarse out in plate, because 0.1 mm matters at 22 gauge and nothing at 12 mm.
    static let steps: [Double] = [
        0.5, 0.6, 0.8, 0.9, 1.0, 1.2, 1.5, 1.6, 1.8, 2.0, 2.3, 2.5, 2.7, 3.0, 3.2,
        3.5, 4.0, 4.5, 5.0, 6.0, 6.4, 7.0, 8.0, 9.5, 10.0, 11.0, 12.0, 12.7, 14.0,
        16.0, 19.0, 22.0, 25.4,
    ]

    /// Snaps to the nearest step so the slider always lands on a thickness somebody stocks.
    static func snap(_ mm: Double) -> Double {
        steps.min { abs($0 - mm) < abs($1 - mm) } ?? mm
    }

    /// Flow, the other unit the shop is split on. 1 CFH is 0.4719 L/min.
    static func litresPerMinute(cfh: Double) -> Double { cfh * 0.4719474 }

    static func formatFlow(_ cfh: Int, unit: FlowUnit) -> String {
        switch unit {
        case .cfh: return "\(cfh) CFH"
        case .litresPerMinute: return String(format: "%.1f L/min", litresPerMinute(cfh: Double(cfh)))
        }
    }
}
