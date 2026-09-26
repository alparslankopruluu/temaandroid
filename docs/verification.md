# Local verification — 2026-09-21

This is the historical M4 baseline. Latest dynamic-scene and iOS 1.0.2-candidate evidence is recorded below.

## Firebase identity, diagnostics and events — 2026-09-26

- Firebase dev/prod each have iOS and Android app registrations for `com.screenmotion.studio`; Anonymous Auth and Google Analytics show enabled in both projects. SDK configuration files are local and gitignored.
- iOS Debug and Release simulator builds passed. Debug app bundle contains the dev Firebase app ID, Release bundle contains the prod app ID; Release ran the Crashlytics symbol upload phase.
- Android Debug and Release builds plus `testDebugUnitTest` passed. Final merged manifests retain Analytics configuration with Advertising ID collection disabled and omit AD_ID permissions.
- On the iPhone 17 Pro simulator, the dev Firebase Authentication console showed one new Anonymous user after launch. Firebase Analytics DebugView showed `first_open`, `user_engagement`, then the custom `app_opened` event; the latest device property was `non_personalized_ads = 1`.
- A locally signed iOS simulator build passed. Its controlled debug nonfatal reached the dev Crashlytics dSYM page: the matching app dSYM UUID was uploaded and processed with one event. Older unsigned simulator builds left five reports awaiting three unavailable debug dSYMs; they are not evidence about a shipped build. The specific issue row is not yet visible. Android runtime Analytics/Auth/Crashlytics receipts remain open because no Android device was attached. No Firebase-enabled binary has been shipped to users, and App Store/Play privacy labels have not yet been updated.

Environment: Xcode 27.0 (27A266a), iPhone 17 Pro simulator, iOS 26.2, plus a 13-inch iPad simulator build. No physical-device acceptance is recorded.

## Passed
- Native app and WidgetKit extension compile with complete strict concurrency diagnostics.
- Focused unit tests: catalog/free-tier integrity for 16 realistic plus 6 pixel scenes, persisted favorites/designs/rewards/setup steps, cancelled rewarded test, four packs of 24 distinct icon files, renderer visible pixels/exact dimensions, deterministic animation, missing-art rejection, matching Live Photo JPEG/MOV identifiers with 1.5-second timed metadata and 3-second duration, pixel interaction bounds, dynamic-content HTTPS/schema fallback, and catalog compatibility for legacy theme IDs.
- UI tests: discover → editor → draft → export options; Turkish and Arabic discover/editor navigation and screenshots; Turkish export-hint regression; Pixel filter → pixel-car editor inside the existing chrome.
- Local StoreKit acceptance: the monthly product loads, purchase unlocks `pro`, and simulated expiration/revocation removes access. The earlier `0 products` / `notEntitled` failure does not reproduce on the current simulator runtime.
- Paywall acceptance: the Discover PRO action opens the native offering-driven paywall; monthly/yearly localized products, renewal disclosure, Restore, Terms and Privacy are present; the RevenueCat `No Paywall configured` fallback is absent. The header stacking fix prevents the featured card accessibility frame from intercepting the PRO action.
- Content validator: 22 themes (20 artwork files, 2 programmatic pixel backdrops), 190 nonempty keys in 22 locales.
- Dynamic localization-key validator rejects interpolated `LocalizedStringKey` construction. The focused Turkish export UI test confirms all three localized hints and the absence of raw `export.hint.*` keys.
- Full current suite: 22 XCTest cases, 4 Swift Testing cases and 5 UI journeys pass with zero failures. Current English paywall capture: `evidence/paywall-en.png`; Turkish/Arabic and earlier journey captures remain under `evidence/`.

## Not accepted yet
- Full PhotoKit save verification, including denied permission, resource exhaustion and cancellation race; paired-file metadata passing alone is insufficient.
- Physical Live Photo lock-screen playback and Spatial Scene compatibility. No app-side gyro/touch execution is claimed on the lock screen.
- Physical-device 60 FPS / low-power 30 FPS measurements, battery profiling, full VoiceOver / accessibility-size audit, native-language review, widget installation and Pro restore/pending/cancellation paths.
- Sandbox purchase/restore against Apple's live sandbox account on a signed physical-device build. Runtime offering/package readback works, but the current RevenueCat dashboard state was not independently re-read because MCP authentication expired.
- Signed archive/IPA 1.0 (4) uploaded and `VALID`. Physical-device sandbox purchase/restore remains open.
- Physical-device PhotoKit, Live Photo lock-screen playback, sandbox purchase/restore, widget install, and performance remain open. App Review submission is now live (`WAITING_FOR_REVIEW`) and does not close those gates.

## App Store Connect checkpoint — 2026-09-21

- App `6814078185` (`com.screenmotion.studio`) and version `1.0` were created and read back successfully.
- Subscription group `22398612`, monthly subscription `6814078761` (`com.screenmotion.pro.monthly`) and yearly subscription `6814170987` (`com.screenmotion.pro.yearly`) were created and read back. USD prices are $6.99 monthly and $79.99 yearly; pricing and availability cover all 175 territories. Group and both products have 22 localizations. Apple now reports monthly, yearly, and group version `4962b340-2bca-4120-ab79-5a0ea3e77a97` as `WAITING_FOR_REVIEW`.
- RevenueCat OAuth was completed. Project `ScreenMotion` (`6eac634f`) has a valid App Store connection, entitlement `pro`, current `default` offering and matching App Store monthly/yearly products. Readback confirms both products are attached to their packages and entitlement. Test Store placeholder products remain available for direct provider testing but were removed from the production offering packages.
- RevenueCat paywall `pw08fc3171c9634bad` remains an optional unpublished remote draft. The shipping app now uses its own native paywall backed by the current offering, so an absent remote presentation does not show RevenueCat's `No Paywall configured` screen. Runtime prices come from the StoreKit products. Legal links point to the live ScreenMotion Terms and Privacy pages.
- Build 4 (`98c09e2a-42a5-4d86-8960-89e68630e726`) is `VALID` and attached to version 1.0. All 22 localizations have exactly four COMPLETE `APP_IPHONE_67` and four COMPLETE `APP_IPAD_PRO_3GEN_129` screenshots after English iPad duplicates were deleted. Review submission `5d33748b-2692-444e-a52a-7d021d5a4d97` includes the app version, monthly/yearly subscription versions, and subscription group version; it was submitted at `2026-09-21T11:05:17.78Z` and is `WAITING_FOR_REVIEW`.

The local technical core and 22-locale store screenshot sets are green. Version 1.0 is waiting for App Review. That is not approval, sandbox proof, or physical-device acceptance.

## M5 dynamic themes and iOS 1.0.2 candidate — 2026-09-24

- `python3 scripts/validate-remote-themes.py`: valid schema-v2 catalog, 1 theme and 1 versioned artwork asset.
- `python3 scripts/verify-content.py`: 29 local themes, 196 complete keys across 22 locales, and safe dynamic localization keys.
- iPhone 17 Pro / iOS 26.2: 31/31 targeted tests passed (30 unit tests plus the Rainfire Firebase journey). The UI journey opens the remote theme, taps and drags within its preview, and confirms the editor remains available. A separate maximum Dynamic Type run passed (1/1 UI test). Last-known-good offline catalog behavior is covered by unit tests.
- Rainfire's pan recognizer now shares vertical-scroll gestures with the enclosing editor; the simulator screenshot after the UI drag still shows the editor scroll offset changing. The test is a gesture smoke test and does not measure visual displacement or tilt fidelity.
- Light appearance at maximum Dynamic Type was inspected on the iPhone simulator. Content remains scrollable, though the simulated lock-screen date/time overlays a large part of the scene at the largest text setting; review this on-device before treating accessibility acceptance as complete.
- `asc xcode archive`: signed iOS device archive succeeded for `com.screenmotion.studio` 1.0.2 (6). App and widget plist readback both report 1.0.2/6; Release embeds `https://screenmotion-prod.web.app/v2/manifest.json`.
- `asc xcode export`: local IPA export succeeded. Artifact: `.asc/artifacts/ScreenMotion-1.0.2-build6.ipa`; SHA-256 `6a7006b27c75f6e0ee01db2996d499da2dd647a2ea7b8a645ce131379932ab24`. App and widget in the IPA both report 1.0.2 (6); the IPA signature verifies as iPhone Distribution and `get-task-allow=false`.
- Firebase Hosting readback: both dev and prod serve schema 2/contentVersion 2, minimum app 1.0.2, and `pixel-rainfire`. The prod manifest and its 2,175,887-byte PNG return HTTP 200; PNG is served as `image/png` with one-year immutable caching under a content-versioned path.
- Current App Store Connect readback: version 1.0.2 remains `PREPARE_FOR_SUBMISSION`; build 6 is uploaded but not attached to the App Store version. `asc validate` reports one blocking issue (the missing version build attachment), 24 warnings (What's New localizations and optional subscription promotional images), and one App Privacy publish-state info. App Review submission remains separate and has not been submitted.

### TestFlight upload — 2026-09-24

- Uploaded the signed `ScreenMotion-1.0.2-build6.ipa` to App Store Connect app `6814078185` (`com.screenmotion.studio`). SHA-256: `6a7006b27c75f6e0ee01db2996d499da2dd647a2ea7b8a645ce131379932ab24`; IPA ZIP integrity and Apple Distribution signature passed before upload.
- Build ID `a102959f-6542-48cd-8a60-0b0e14594916`, version `1.0.2 (6)`, processing state `VALID`; TestFlight `internalBuildState` is `READY_FOR_BETA_TESTING`. Minimum iOS is 17.0, architecture is arm64, encryption declaration is `false`, and 22 locales are present.
- ASC returned 124 device size variants. Exact download/install byte pairs and model counts: 46,287,626/52,149,248 (5); 46,287,671/52,149,248 (34); 46,289,016/52,153,344 (26); 46,289,120/52,153,344 (58); 50,410,237/52,370,432 (1). Largest download is about 50.4 MB, below the 200 MB cellular threshold. Full readback: `.asc/artifacts/ScreenMotion-1.0.2-build6-variant-sizes.json`. No processing warning was returned in `asc builds info`. Bundle metadata says `includesSymbols=true`, while `asc builds dsyms` returned no downloadable dSYM files.
- `asc validate testflight` reports five missing fields: beta contact first name, last name, email, phone, and at least one “What to Test” localization. No TestFlight group/tester was assigned. An older same-version/build upload reservation `16ae99e0-dbff-4918-8543-b11f92ce0531` remains `AWAITING_UPLOAD`; it was left untouched.

Motion-quality review: **BLOCK**. Per-frame layer resizing and the hard-edged light disc are fixed, and the editor pan recognizer now permits scene input alongside parent scrolling. Reduce Motion, interrupted/repeated gestures, background/resume, low-power frame pacing, live tilt, and physical-device FPS/battery still lack acceptance evidence. No physical iPhone was connected during this run.

Physical-device performance and tilt feel, the largest-text clock overlay, VoiceOver/Voice Control, Live Photo lock-screen behavior, and sandbox purchase/restore remain open acceptance evidence.
