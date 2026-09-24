# M4 verification matrix

Use one row per scene. Do not mark device-only evidence from a simulator result.

| Scene | Idle motion | Touch | Tilt | Controls | Deterministic export | Device Live Photo | Status |
|---|---|---|---|---|---|---|---|
| 16 realistic scenes | Implemented by renderer | Touch reaction implemented | CoreMotion implemented | Renderer values wired | Build-only evidence | Pending | Device review open |
| 12 pixel scenes | Implemented by renderer | Profile reactions implemented | CoreMotion implemented | All five values wired | Repeatability tests compile | Pending | Device review open |

## Required gates

- [x] `python3 scripts/verify-content.py` — 28 themes, 20 artwork files, 8 programmatic scenes, 196 keys, 22 locales
- [x] Generic iOS Simulator build — `BUILD SUCCEEDED` with Xcode 27 / iOS Simulator SDK
- [x] Test targets compile — `TEST BUILD SUCCEEDED`; unit and UI test bundles link successfully
- [ ] Full unit and UI test plan on an available named simulator — runner launch blocked on iOS 18.3.1 with Mach `-308`; iOS 26.2 remained at `waiting for workers to materialize` with and without local ad-hoc signing
- [ ] Normal and Reduce Motion visual evidence
- [ ] Physical iPhone PhotoKit save and Live Photo wallpaper playback
- [ ] Physical widget installation and one icon Shortcut installation
- [ ] Physical 60 FPS target / low-power 30 FPS target and battery observation
- [ ] VoiceOver, accessibility sizes and RTL review

## 2026-09-24 evidence

- `git diff --check`: pass.
- Content validation: pass.
- App, widget extension, unit test bundle and UI test bundle compile/link/validation: pass.
- Realistic scenes include independent, theme-specific moving elements in addition to parallax; pixel scenes use profile-specific motion and reactions.
- Unit and UI sources compile in the test action; XCTest execution did not begin because the local CoreSimulator test-runner service failed before materializing a worker.
- Physical-device rows remain open and no TestFlight/App Store upload was performed.

Build or metadata success never closes the physical-device rows.
