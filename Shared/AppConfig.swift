import Foundation

/// The one file to edit when starting a new app from this template.
/// Everything user-facing that changes per app (name, copy, product IDs, links) lives here.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Weld Settings"
    static let bundleID = "com.example.weld-settings"
    static let appGroupID = "group.com.example.weld-settings"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.(the number in the App Store URL).
    static let appStoreID = ""

    // MARK: Sync
    /// Set to true only after enabling iCloud + CloudKit on the App ID (see docs/capabilities.md).
    /// With false, SwiftData stores locally and the app works with no Apple capabilities at all.
    static let iCloudSyncEnabled = false

    // MARK: StoreKit (must match App Store Connect and StoreKit/Products.storekit)
    /// Apple allows only letters, digits, underscores and periods in product IDs, so hyphens in the bundle ID are dropped.
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    /// Hosted copy of PrivacyPolicyView, one page per app under somexai.com/privacy (somexai_corp repo, scripts/privacy.py).
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/weld-settings/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Shown in Settings, on every export and in the store listing. Every settings app on the App
    /// Store today belongs to a machine manufacturer and covers that manufacturer's own product
    /// line; this one covers none of them, ships no brand list, and says so plainly.
    static let independenceNotice = "Weld Settings is an independent app. It is not affiliated with, "
        + "endorsed by or connected to any welding machine manufacturer. It describes settings by "
        + "process and material, and any machine name in the app is one you typed yourself."

    /// Repeated wherever a number is shown, because a plausible-looking figure somebody trusts is
    /// worse than an honest range.
    static let startingPointNotice = "Every figure in this app is a starting point drawn from "
        + "general welding practice, not a specification. Run a test coupon in the same metal, at "
        + "the same thickness, in the same position, and tune it by the sound of the arc and the "
        + "look of the bead. Where a drawing or a welding procedure specification applies, that "
        + "document governs."

    // MARK: Copy
    /// What the app calls one record.
    static let entryNoun = "Weld"
    static let entryNounPlural = "Welds"
    /// File name stem for exports: "weld-settings-2026-09-14.csv".
    static let exportFileStem = "weld-settings"

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "slider.horizontal.3", title: "One reference for a mixed shop",
                       body: "Pick the process, the metal, the thickness, the joint and the position. The card gives you an amperage range, wire speed, gas, filler and polarity — by process and material, not by brand."),
        OnboardingPage(symbol: "eye", title: "And which way to move it",
                       body: "Every setting says what to change when the bead comes out ropey, cold, undercut or full of holes. That is the half a chart leaves out."),
        OnboardingPage(symbol: "tray.full", title: "Then save what actually worked",
                       body: "Presets live under the machine you ran them on, named by you. Log the job with a photo of the bead and print a setting card for the cabinet door."),
    ]

    static let paywallSymbol = "flame.fill"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "MIG, TIG and stick on steel, stainless and aluminium",
        "Unlimited presets, saved per machine",
        "Job log with a photo of the bead",
        "Printable setting card, PDF and CSV export",
        "Works with no signal, in a shed, all of it offline",
    ]

    // MARK: How-to guide (Settings → How do I use this app; also the ? button on the home screen)
    static let howToIntro = "Five steps. The first one takes about ten seconds and is the whole app."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "slider.horizontal.3", title: "Set the bench",
                  body: "On the Bench tab, tap MIG, TIG or Stick. Then tap the metal, drag the thickness slider, and tap the joint and the position. The card underneath changes as you go.",
                  tip: "Switch the thickness control between mm, inch and gauge with the three-way switch. Gauge is a different thickness in steel, stainless and aluminium, and the app uses the right table for the metal you picked."),
        HowToStep(symbol: "doc.text.magnifyingglass", title: "Read the card",
                  body: "The big number is the amperage range to start at. Tap any row — Voltage, Wire speed, Gas flow — to see which way to move it and what you are looking at when you decide.",
                  tip: "Tap If the bead looks wrong for a list of what goes wrong on that process, what causes it, and what to change first."),
        HowToStep(symbol: "tray.and.arrow.down", title: "Save what worked as a preset",
                  body: "Tap Save as a preset, give it a name, pick the machine, and type the numbers you actually ran. Use Add a machine the first time — the machine is whatever you call it on the bench.",
                  tip: "This is the part a manufacturer's calculator cannot do. Their chart knows their machine; a preset knows yours, including that the feeder reads low."),
        HowToStep(symbol: "book.closed", title: "Log the weld",
                  body: "Tap Log this weld on the bench, or the plus on the Job log tab. Record what you welded, what was on the machine, how it came out, and take a photo of the bead with Add Photo.",
                  tip: "Fill from a preset drops last time's numbers straight in."),
        HowToStep(symbol: "printer", title: "Print the setting card",
                  body: "On the Presets tab, under each machine, tap Setting card for the cabinet door (PDF). That is the one to print and tape inside the door next to the feeder. Export on the Job log tab gives you the weld record as a PDF or every weld as a CSV."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$6.99", lifetime: "$12.99")

    // MARK: Behaviour
    /// Ask for an App Store review after this many successful saves (once per app version).
    static let reviewAfterSuccesses = 3
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
