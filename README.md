# Weld Settings

A settings reference for MIG, TIG and stick welding on steel, stainless and aluminum, with presets saved per machine and a job log. It is for welders in a mixed shop.

One of a set of niche iPhone apps built from a shared SwiftUI template ([somexai-ios-template](https://github.com/victorboba/somexai-ios-template)). It was never released on the App Store; the code is here for anyone to use. The other apps are collected in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Bench**: pick the process, metal, thickness, joint and position. The card shows an amperage range, voltage, wire speed, gas, filler and polarity, by process and material rather than by brand.
- **Thickness** in mm, inches or gauge. Gauge uses the right table for the metal chosen; storage is always millimeters.
- **Which way to move it**: every setting row says what to change, and an If the bead looks wrong list covers what goes wrong on that process, the cause and what to change first.
- **Presets** saved under the machine you ran them on, named by you, with the numbers you actually used.
- **Job log**: record what you welded, what was on the machine and how it came out, with a photo of the bead. Fill from a preset to reuse last time's numbers.
- **Export**: a printable setting card for the cabinet door (PDF), a weld record PDF, and every weld as CSV.
- Works fully offline. A widget and a How do I use this app guide are included.

## The boundary

Settings shown are starting points drawn from general welding practice, not a specification. Follow your welding procedure specification, the machine manual and the filler manufacturer's data.

## Privacy

Data stays on the device in SwiftData. There is no account, no analytics and no network access; iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the device only when you share them.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17 or later.

```bash
xcodegen generate
open WeldSettings.xcodeproj
```

Pick the `WeldSettings` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme WeldSettings -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

`scripts/ci.sh WeldSettings` is an alternative.

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.

To run on your own device or ship it:

- Set your team in `project.yml` (`DEVELOPMENT_TEAM`).
- Change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`.
- Update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

- `WeldAdvisor` builds the settings card from a `WeldSelection` value that the bench, a saved preset and a logged job all share.
- Debug launch arguments: `-unlock`, `-sampleData`, `-resetData`, `-skipOnboarding`, `-mockPrices`.

## Project layout

- `WeldSettings/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, app).
- `WeldSettings/Core/`: CSV/PDF export, photo field, StoreKit entitlement store, App Intents, review prompt, sample data, shared UI.
- `WeldSettings/Features/`: Home (Bench, Presets, Job log), Settings, Help, Onboarding, Paywall.
- `WeldSettings/Models/`: `WeldAdvisor`, `BeadDiagnostics`, `Machine`, `JobEntry`, `StickElectrode`, `Thickness`.
- `WeldSettingsWidget/`: home screen widget reading a snapshot from the App Group.
- `WeldSettingsTests/`, `WeldSettingsUITests/`: unit tests and screenshot UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, onboarding, how-to guide).
- App Shortcut: "Log a weld in Weld Settings".

## License

MIT. See [LICENSE](LICENSE).
