# Lunet

A free, native iOS QR & barcode scanner that tells you what a code means before you act on it:
every link is checked for scams first, and each kind of code gets its own answer — join a Wi-Fi
network, add a boarding pass to Wallet, save a contact, look up a product.

- **Native SwiftUI**, iOS 17+ (Liquid Glass on iOS 26, material fallbacks before)
- **On-device**: scanning, parsing, safety heuristics and history never leave the iPhone
- **Everywhere**: Control Center, Lock Screen, Action button, Live Activity for multi-scan, widgets, Shortcuts
- **Create**: 15 symbologies, a styling studio (dots, corners, colors, logo, frames) with on-device scan verification
- English, Spanish, French

Bundle ID `com.rvp97.scanner` (the App Store listing that used to be "Fast QR & Barcode"; the app
imports history from the previous Expo version on first launch).

## Repository

| Path | What |
| --- | --- |
| `Lens/` | The iOS app, widget extension and tests. The Xcode project is generated from `Lens/project.yml`. |
| `wallet-service/` | Cloudflare Worker that signs Apple Wallet passes, gated by App Attest. See its README. |
| `screenshots/` | Next.js tool for composing App Store screenshots. |

## Build & run

```bash
brew install xcodegen
cd Lens && xcodegen generate && open Lens.xcodeproj
```

Tests: `xcodebuild -project Lens/Lens.xcodeproj -scheme Lens -destination 'platform=iOS Simulator,name=iPhone 17' test`

Signing: set your team in Xcode (or `DEVELOPMENT_TEAM` in `project.yml`). Capabilities used: App Groups
(`group.com.rvp97.scanner`), Hotspot Configuration, App Attest (production).

### Debug QA harness

Debug builds accept launch arguments that open any screen with sample data, for design review and
screenshots without a camera — see `Lens/App/QAHarness.swift`:

```bash
xcrun simctl launch booted com.rvp97.scanner -qaAppearance dark -qaSeed YES -qaScreen result:danger
```

## Wallet signing service

Live at `bloom.vallepinto.com/lens/*` (Cloudflare account "Rovapin@gmail.com's Account"). The Pass Type ID
certificate (`pass.com.rvp97.scanner`, team `JWDA82S3B5`) expires **2027-10-28** — renew it and re-upload the
secrets before then (steps in `wallet-service/README.md`). Kill switch: set `KILL_SWITCH = "1"` and redeploy.
