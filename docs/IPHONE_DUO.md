# Lunet on iPhone Duo

iPhone Duo folds: a compact outer display (466 × 678 pt, the status bar in a column down one side), and a
regular/regular inner display (about 951 × 669 pt sideways) that can lie flat or fold like a book or a
laptop. This page records what Lunet does about Apple's guidance, and what's still open. Nido and Bloom
went first (`~/dev/ios/Nido/docs/IPHONE_DUO.md`, `~/dev/ios/Bloom/docs/IPHONE_DUO.md`).

Sources: Apple's tech talk *Prepare your app for iPhone Duo* (111461), the AVFoundation 27.1 headers,
and WWDC26 *Build a responsive camera app that launches quickly* (303).

## Apple's principles, and Lunet

| Apple says | Lunet |
|---|---|
| Size classes, not idiom, orientation or `UIScreen.main`. | Home and the scanner key off size class and the size they're given. No `UIScreen.main` anywhere. |
| Safe areas are asymmetric: handle each side on its own. | The scanner is edge to edge, so it reads every side of the window's safe area (`ScannerCover.insets`). Its torch and zoom stay clear of the status column; the reticle centers on Close (under the Scan lens), inside the safe area, rather than on the whole screen. |
| Content stays beside the status column; only backdrops run under it. | The code carousel used to slide under the clock. It still lets shadows spill above and below, but stops at the safe area's sides. |
| On the inner display show more, never a stretched phone layout. | Sideways (or on iPad in landscape), Home is two panes: the codes stacked like passes on one side, Recent and the Scan lens on the other. Upright, one column with the codes two to a row. |
| Nothing tappable on the fold; split at the hinge. | `HingeSplit` (Core/Design/DuoLayout.swift) splits at the fold when folded like a book (`reservedRegions(kind: .division)`), at the display's middle when flat, so nothing moves as it folds. The Scan lens sits in the middle of its own pane, never on the hinge. |
| Facing the person, a camera over each display; folding can change which one is in use. | Switch Camera picks `builtInInnerUltraWideCamera` with the Duo open and `builtInOuterUltraWideCamera` closed, and follows the Duo as it opens and closes (`ScannerCamera.setDisplay`). The back camera is the same either way. |

## Every iPhone

- **120 Hz.** `CADisableMinimumFrameDurationOnPhone` was missing, so the Scan lens's opening ran at 60 Hz
  on ProMotion iPhones.
- **The camera is ready before the tap.** Once Home settles, the capture session is configured (not
  started, so no camera indicator) when access is already granted. Opening the scanner only has to
  start the feed. Code reading uses deferred start (iOS 26+), so the preview's first frame comes first.
- **The lens grows into the camera.** The opening edge carries the Scan lens's own colored rim (turning
  with it) instead of a white hairline, thinning and fading as it sweeps out.
- **Home is titled by its content.** "Your codes" is the page's large title; the logo tile and wordmark
  are gone.

## Testing on iPhone Duo

- Xcode 27.1 and the iOS 27.1 simulator runtime. Lunet's own simulator: "Lunet Duo".
- `duoctl`'s helper (`~/.cache/duoctl/duoctl-helper-*`, run with `xcrun simctl spawn <udid>`) takes
  `hinge <degrees>` (0 closed, 180 flat) and `orientation`; on the inner display `portrait` turns it
  sideways. `xcrun simctl io <udid> screenshot --display=3` captures the inner display.
- `-qaSeed YES -qaScreen home -qaFakeCamera YES` opens Home with sample codes, and the scanner without a camera.

## Still open

- **The closed Duo turning sideways** (as Nido and Bloom do). Lunet stays upright on the outer display.
- **The camera across the open display.** Sideways, the scanner fills the inner display with the
  reticle over Close. A layout with the viewfinder on one half and the result on the other was not tried.
- **App Store screenshots for iPhone Duo** (required from April 2027 for apps built with the 27.1 SDK).
- **Checked on a real iPhone Duo**: not yet; everything above was checked in the simulator.
