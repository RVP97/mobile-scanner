# App Store screenshots

Generates Lunet's App Store screenshots from real app screens, in every locale, at the exact
sizes App Store Connect wants:

| Device | Size (portrait) | File prefix |
| --- | --- | --- |
| iPhone 6.9" (17 Pro Max) | 1320 × 2868 | `NN_iPhone69_<scene>.png` |
| iPad 13" (iPad Pro M5) | 2064 × 2752 | `NN_iPadPro13_<scene>.png` |

Output goes to `appstore/screenshots/<locale>/` (fastlane `deliver` layout; the store order is
the `NN` prefix).

## One command

```sh
appstore/screenshots-src/make.sh                  # every locale in strings.json
appstore/screenshots-src/make.sh en-US de-DE      # only these
SKIP_CAPTURE=1 appstore/screenshots-src/make.sh   # re-compose from existing captures (copy/design changes)
```

`make.sh` builds the Debug app (the QA harness only exists in Debug), installs it on the two
simulators, captures every screen in each locale's app language, then renders.
Needs Xcode + XcodeGen, Node 18+, and Google Chrome (headless; override with `CHROME=`).

Simulators default to the iPhone 17 Pro Max `DD0DB49F-…` and an iPad Pro 13-inch (M5) `665EC18A-…`;
point elsewhere with `IPHONE_UDID=` / `IPAD_UDID=`. Create an iPad with
`xcrun simctl create "iPad Pro 13 Shots" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB`.
Capturing the iPad switches that simulator's system language (its status bar shows the date) and
reboots it.

## Adding a language

1. The app must already be localized in that language (String Catalogs in `Lens/`).
2. Add a block to `strings.json` keyed by the App Store locale, with `app` set to the app's
   language code (`"de"`, `"pt-BR"`, …). Several store locales can share one `app` language; it
   is captured once.
3. `make.sh <locale>`.

Headline rules: about 28 characters, `\n` for the line break you want, `*word*` for the scene's
highlight color. Sublines are one short sentence (two lines at most on iPhone).

## Files

- `strings.json`: every headline and subline, per locale.
- `render.mjs`: the scenes (order, backgrounds, device frames, the Answers collage), rendered to
  PNG with headless Chrome. `node render.mjs en-US --device iphone --only hero,safety` for quick
  iteration.
- `capture.sh`: the raw screens for one device + language, via the DEBUG QA harness
  (`-qaScreen`, `-qaSeed`, `-qaLargeSheet`, `-qaPreset`, …; see `Lens/App/QAHarness*.swift`).
- `shot.sh`, `statusbar.sh`, `setlocale.sh`: launch-and-capture, the 9:41 status bar, the
  simulator language.
- `raw/` (ignored): the latest captures. `.build/` (ignored): the generated HTML.

## The set

1. **Hero**: Home with Your codes, Recent and the Scan lens (dark).
2. **Safety**: the n0rthbank lookalike stopped, with "Don't Open" (dark).
3. **Answers**: Wi-Fi, boarding pass and contact results, cropped from real result sheets.
4. **Show code**: a Wi-Fi code full screen at full brightness.
5. **Studio**: a styled QR (Lagoon preset, Wi-Fi glyph) with the Verified check.
6. **Everywhere**: the onboarding page for Control Center, Action button and Lock Screen
   (the iPad copy leaves out the Action button, which iPad doesn't have).
7. **History**: Safe, Danger and Caution tags, search.
8. **Privacy**: Settings › Privacy (dark).

Everything shown is the app as it ships; the only arrangement is cropping in scene 3.
