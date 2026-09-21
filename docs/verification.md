# Local verification — 2026-09-21

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
- Final metadata/App Privacy/age-rating/review-contact readback before human review submit. English 13-inch iPad screenshots are uploaded. A draft review submission includes the app version plus monthly/yearly subscriptions and has not been submitted.

## App Store Connect checkpoint — 2026-09-21

- App `6814078185` (`com.screenmotion.studio`) and version `1.0` were created and read back successfully.
- Subscription group `22398612`, monthly subscription `6814078761` (`com.screenmotion.pro.monthly`) and yearly subscription `6814170987` (`com.screenmotion.pro.yearly`) were created and read back. USD prices are $6.99 monthly and $79.99 yearly; pricing and availability cover all 175 territories. Group and both products have 22 localizations. Apple reports both products as `READY_TO_SUBMIT`.
- RevenueCat OAuth was completed. Project `ScreenMotion` (`6eac634f`) has a valid App Store connection, entitlement `pro`, current `default` offering and matching App Store monthly/yearly products. Readback confirms both products are attached to their packages and entitlement. Test Store placeholder products remain available for direct provider testing but were removed from the production offering packages.
- RevenueCat paywall `pw08fc3171c9634bad` remains an optional unpublished remote draft. The shipping app now uses its own native paywall backed by the current offering, so an absent remote presentation does not show RevenueCat's `No Paywall configured` screen. Runtime prices come from the StoreKit products. Legal links point to the live ScreenMotion Terms and Privacy pages.
- Build 4 (`98c09e2a-42a5-4d86-8960-89e68630e726`) is `VALID` and attached to version 1.0. English `APP_IPAD_PRO_3GEN_129` screenshots 01–04 are COMPLETE. Draft review submission `5d33748b-2692-444e-a52a-7d021d5a4d97` contains the app version and both first-time subscriptions, state `READY_FOR_REVIEW`, not submitted.

The local technical core and English store screenshot set are green. The app remains NO-GO for App Review until sandbox/device checks and an explicit human submit.
