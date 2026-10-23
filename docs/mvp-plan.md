# Approved implementation and release progression

## M6 — iOS 1.0.4 recovery and monetization (approved 2026-10-19)
Live App Store state: 1.0.3 (8) READY_FOR_DISTRIBUTION; repository source is 1.0.2 (6) and the 1.0.3 source is lost. Rebuild the five missing 1.0.3 store promises (cinematic loops, video→Live Photo, tappable widgets, iOS 26 Spatial Scene guide, Nightstand mode, Lock Screen-style cards with a simpler Discover) and ship monetization fixes: featured-order bug, review prompt after a successful save, export failure reasons, dismissible paywall after welcome and on locked scenes, visual paywall with trial timeline, 2 free video conversions. Pricing change (yearly USD 29.99 + 3-day trial), metadata apply, asset upload and review submission each need a separate exact approval.

- [ ] Featured/remote order fix + regression test
- [ ] Paywall v2, welcome soft paywall, locked-card paywall, review prompt, export diagnostics
- [ ] Video→Live Photo (2 free) 
- [ ] Code-rendered cinematic loops (20) in app + Live Photo export
- [ ] Nightstand mode, Spatial Scene guide, tappable widgets, Lock Screen cards / Discover
- [ ] 22-locale strings, tests green, version 1.0.4 (9)
- [ ] ASO metadata, screenshots, App Preview, header/search videos (local prepare → approved apply)
- [x] 2026-10-23 (user-approved): yearly equalized to USD 29.99 in 175 territories and a 3-day free trial on yearly in 175 territories, both effective 2026-10-24; version 1.0.4 created in ASC with 22-locale metadata applied (1.0.3 screenshots carried over)
- [x] Purchase cancel no longer shows an error or counts as `pro_purchase_failed`; Ask to Buy shows a pending note; purchase events carry `source`/`plan`; the store-unavailable copy no longer tells customers to run Xcode
Current milestones: M5 — Firebase-delivered dynamic scene catalog and iOS 1.0.2; M4 — Interactive Theme Studio v2; M3 — iOS App Store release gates; A0 — Android parity contract and source gate.
M0–M2 implementation is present and accepted locally. The StoreKit purchase/expiration regression and paywall compliance UI journey pass on the current simulator runtime.
M0: Kit and native app/widget targets.
M1: Scene engine, 16 realistic scenes, editor, exports, library, icon packs, widgets and installation.
M2: Local StoreKit and rewarded test provider; 22 locales.
M3: App Store Connect/RevenueCat catalog, production purchase integration, build, tests, store assets, simulator visual review and physical-device gates. In-app pixel worlds are local product work inside this studio; they do not change the lock-screen contract or authorize review submission.
M4: Expand the local iOS catalog to 16 realistic plus 12 pixel scenes, make scene-specific motion and editor controls perceptible, align preview/export rendering, and coordinate per-design wallpaper/widget/icon setup. On 2026-09-24 the user separately authorized local Android parity work against this current M4 source: sync the 28-theme/22-locale content, add the six pixel interaction profiles, share configuration-aware rendering across Android preview/export/live wallpaper, apply saved configuration to widgets, and persist per-design setup progress. This local authorization does not include a new upload, review mutation, provider write, pricing change, signing change, or production action. The implementation contract and evidence matrix live in `docs/plans/ios-theme-studio-v2.md`, `docs/qa/ios-theme-studio-v2.md`, and `docs/android-parity.md`.
M5: On 2026-09-24 the user expanded iOS scope to publish original realistic or pixel scenes dynamically through Firebase, including artwork, optional ambient audio, localized text and allowlisted motion/interaction recipes. Use a schema-v2 static manifest and assets served through Firebase Hosting; validate all content; support continuous animation, tap/drag, device tilt and scene-specific effects in-app; use the same deterministic renderer for export. Audio is an in-app opt-in only and is not included in Live Photos or system wallpapers. Do not download executable code or shaders; no user data, authentication or Firestore is in scope. Add an original rainy pixel cabin sample with bundled offline art and prepare iOS 1.0.2. Hosting provisioning/deployment, binary upload and review submission require separate verified release gates.

On 2026-09-26 the user separately authorized Firebase Anonymous Authentication, Crashlytics, Analytics and app events for both iOS and the native Android port. This extends M5 for silent identity, diagnostic reports and privacy-safe event measurement. There is no account screen, Firestore collection, user-content upload, or release submission in this authorization. Debug builds use `screenmotion-dev`; release builds use `screenmotion-prod`. Production privacy disclosures and live telemetry require a new verified binary and provider readback.

## Scope Fence
Production iOS RevenueCat subscription setup and App Store 1.0 review submission are approved. A separate native Android app covers all shipped iOS behavior plus the Android/Huawei extensions in `docs/android-parity.md`. Its Google Play Internal Testing release is published, monthly/yearly Play subscriptions are active, and the RevenueCat Play app/products are attached to `pro` and the current `default` offering. The signed RevenueCat-enabled code-2 AAB predates the current Android M4 source and is not a current parity artifact. Google Play accepted the upload-key reset request; the new key becomes valid on 2026-09-25 at 16:14 UTC. The production release remains blocked by that activation time, Play setup declarations/store listing and RevenueCat Play service-account credentials. Firebase Hosting for the public dynamic scene catalog plus Anonymous Auth, Analytics and Crashlytics are in scope under M5; Firestore/R2, production ads, user AI generation, interactive account screens, weather/health services and Play tester assignment remain out of scope. App Store Connect readback on 2026-09-24 shows iOS 1.0.1 ready for sale and its review submission complete; a 1.0.2 review submission requires separate authorization. Catalog identifiers and pricing must continue to match the approved production plan. Sandbox purchase/restore and physical-device acceptance remain open evidence, not implied by store state.

## M5 acceptance checklist — dynamic scene catalog and iOS 1.0.2

- [x] Schema-v2 manifest, allowlisted recipes, supported image/audio formats, byte bounds and invalid-input rejection.
- [x] Hosting-only static content layout, cache headers, local validator and rainy pixel cabin sample.
- [x] Continuous in-app animation, particle/light effects, touch/drag, tilt parallax, Reduce Motion/lifecycle pause and user-toggled ambient audio.
- [x] Preview/export share the deterministic scene renderer; the bundled sample remains available offline.
- [x] Run 30 unit tests plus the Rainfire dev-catalog UI journey with tap/drag input; build/export signed 1.0.2 (6) archive/IPA.
- [x] Move stable layer sizing out of the per-frame update, replace the hard-edged light disc with a soft radial glow, and let scene pan input coexist with editor scrolling.
- [x] Exercise Rainfire tap/drag and maximum Dynamic Type editor navigation on iPhone 17 Pro / iOS 26.2 simulator; offline last-known-good fallback is covered by unit tests.
- [ ] Verify Reduce Motion, interrupted/repeated gestures, background/resume, low-power mode and device tilt; measure frame pacing and battery on physical hardware.
- [x] Provision `screenmotion-dev` and `screenmotion-prod`; deploy the versioned sample to Hosting only and read back both manifest/artwork endpoints.
- [x] Confirm the existing App Store Connect 1.0.2 `PREPARE_FOR_SUBMISSION` version and prepare local build 6 archive/IPA.
- [x] Upload iOS 1.0.2 (6) to App Store Connect/TestFlight and verify processing as `VALID` (`a102959f-6542-48cd-8a60-0b0e14594916`); App Store review submission remains a separate authorization gate.
- [ ] Complete TestFlight beta contact details and at least one localized “What to Test” note before tester distribution; no group or tester was assigned during the upload.
- [ ] Physical-device performance, tilt feel, accessibility and Live Photo export/playback acceptance.

## Android progression

A0: Passing owned-source baseline, parity contract and approved implementation blueprint.
A1: Native Compose shell, catalog, deterministic renderer, editor, local persistence and 22 locales.
A2: JPEG/MP4 export, true Android live wallpaper, icon packs, widgets and Android/Huawei install guides.
A3: RevenueCat Play adapter behind the purchase boundary, quality/performance/R8 gates and verified local AAB. Play products, Internal Testing and the RevenueCat catalog links are live; the signed billing-enabled AAB awaits upload-key activation. Play service credentials, production submission, AppGallery upload and HarmonyOS 5+ native HAP remain separate gates.

## Live release state — 2026-09-21

- App Store Connect app `6814078185`, bundle `com.screenmotion.studio`, version `1.0` is `WAITING_FOR_REVIEW`.
- Subscription group `22398612`; monthly product `com.screenmotion.pro.monthly` (`6814078761`) is priced at USD 6.99 and yearly product `com.screenmotion.pro.yearly` (`6814170987`) at USD 79.99. Both have complete 175-territory price coverage and availability plus 22 product/group localizations.
- Monthly, yearly, and group version `4962b340-2bca-4120-ab79-5a0ea3e77a97` are `WAITING_FOR_REVIEW` with app version 1.0. Review screenshots remain present; promotional subscription images are still absent and are not required for this first review.
- RevenueCat production SDK integration is active. The app reads the current `default` offering and presents a native, offering-driven paywall with yearly preselection, localized Apple prices, Restore, Terms and Privacy. The remote RevenueCat paywall template is not required by this binary. Runtime product readback and local StoreKit acceptance pass; dashboard readback was unavailable in the latest session because MCP authentication expired.
- Build 4 (`98c09e2a-42a5-4d86-8960-89e68630e726`) is `VALID` and attached to version 1.0. All 22 localizations have exactly four COMPLETE iPhone 6.7 (`APP_IPHONE_67`) and four COMPLETE 13-inch iPad (`APP_IPAD_PRO_3GEN_129`) screenshots. Review submission `5d33748b-2692-444e-a52a-7d021d5a4d97` was submitted at `2026-09-21T11:05:17.78Z` and is `WAITING_FOR_REVIEW`. Sandbox purchase/restore and physical-device acceptance remain open and are not implied by this store state.
