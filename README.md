# ScreenMotion

Native SwiftUI theme studio with a separate native Kotlin/Compose Android port. Both are
local-first and require no account screen. Firebase silently creates an anonymous identity for purchase continuity. Debug builds connect to `screenmotion-dev`; release builds connect to `screenmotion-prod`. Analytics records allowlisted screen and funnel events, and Crashlytics records sanitized failures. Local Firebase SDK configurations are gitignored and required for builds. See [Firebase setup](docs/firebase-setup.md), [analytics](docs/playbooks/analytics.md) and [security model](docs/security-model.md).

## Run

Open `ScreenMotion.xcodeproj`, choose the **ScreenMotion** scheme and an iPhone simulator, then Run. The scheme uses `App/Resources/Products.storekit` for local subscription testing. No real charge is made. Device installation requires your signing team and the App Group capability.

```sh
xcodegen generate
python3 scripts/verify-content.py
xcodebuild -project ScreenMotion.xcodeproj -scheme ScreenMotion -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO test
```

Android build, test and local AAB instructions are in [android/README.md](android/README.md).
The Google Play app exists as `com.screenmotion.studio`; version `1.0` (code `1`) is published
to Internal Testing, but no testers are assigned. The same earlier AAB is attached to a
production draft. RevenueCat's Play app, products, entitlement and offering are configured.
Code-2 predates the current Android M4 parity changes and must not be treated as the current
parity build; these changes are local and require fresh release validation before another AAB
can be considered. Its replacement upload key becomes valid on 2026-09-25 at 16:14 UTC. Play
setup and RevenueCat service credentials remain release gates.

## iOS 1.0.4 (M6, in progress)

1.0.3 (8) is live; its source was never pushed, so this branch rebuilds the 1.0.3 store promises and adds the monetization work. Version `1.0.4 (9)`. App Store Connect (2026-10-23, user-approved): yearly USD 29.99 in 175 territories and a 3-day free trial on yearly, both from 2026-10-24; a USD 49.99 lifetime non-consumable (`com.screenmotion.pro.lifetime`, RevenueCat `$rc_lifetime` in `pro`); version 1.0.4 with 22-locale metadata, header and search-result videos; a Halloween in-app event (25 Oct – 1 Nov, 10 locales, `screenmotion://discover/halloween`).

- 23 cinematic loops in `App/Resources/Loops`: 16 painted scenes plus 7 code-rendered scenes (Northern Lights, Neon Rain, Bioluminescence, Event Horizon, and the Halloween set Haunted Moon, Pumpkin Patch, Ghost Forest), rendered by `node scripts/loops/render.mjs` (headless Chrome → HEVC, seamless 6 s loops).
- Saving is live-only: every scene and video becomes a Live Photo carrying the camera's Live Photo keys; the still exists only behind the iOS 26 Spatial Scene guide. Plain video export was removed.
- Video → Live Photo: pick or record a clip, choose 3 seconds, Fill or Fit (whole clip over a blurred fill) with a preview that matches the export; 2 free conversions, then Pro.
- Onboarding: three short pages, an interest pick that reorders Discover, then one dismissible offer opening on a Pro scene from those interests; upgraders see the offer once.
- Paywall: monthly, yearly (trial, savings and weekly figures) and lifetime; pinned call to action with the exact post-trial price; animated entrance and selection (off with Reduce Motion). Locked scenes open their free preview; the offer appears on Save.
- Halloween: a Halloween filter, Halloween-first Discover from 10 Oct to 2 Nov, Pumpkin Patch free to save during the season.
- Nightstand mode with an open-on-charge Shortcuts guide and a remembered scene, iOS 26 Spatial Scene guide, tappable widget, Lock Screen-style Discover cards.
- Store assets: `scripts/m6-metadata.py` and `scripts/m6b-metadata.py` prepare metadata (`metadata/`); `scripts/store/compose.mjs` composes 8 localized screenshots from real captures; `scripts/store/hero-video.py [--event halloween]` builds header, search-result and in-app event videos.

## Experience

Discover → interactive preview → Save & set up. Three tabs keep the navigation simple. The editor supports style, motion, optional depth/particles/framing, undo and reset. Favorites, drafts and setup progress persist locally.

M4 provides 16 realistic artworks plus 12 in-app pixel worlds (1.0.4 adds 4 code-rendered loop scenes), four collections, 96 original exported icon glyphs, and WidgetKit photo/date/calendar/collection styles. M5 adds validated schema-v2 Firebase-hosted themes with localized copy, original image layers, optional ambient audio, and safe animation, particle, lighting and interaction recipes. The Rainfire Cabin scene loops continuously and responds to touch, drag and device tilt while preserving editor scrolling; Reduce Motion and scene lifecycle pause animation. Preview and export use the same renderer. Audio plays only after the user taps its control and is not included in Live Photo or system wallpaper exports. Themes and artwork are public read-only static content; no account, Firestore, downloaded code or shader is introduced. JPEG, paired Live Photo and three-second video exports use the matching scene renderer. Preview clocks and icons are excluded from exports. All interface keys and permission text cover 22 locales. Per-design setup tracks the separately user-installed wallpaper, widget and icon steps. The yearly Pro option is selected by default and carries a localized Most Popular badge.

To author and validate themes, see [remote-content/README.md](remote-content/README.md) and run `python3 scripts/validate-remote-themes.py`. The checked-in version-2 manifest and cabin art are live on both ScreenMotion Firebase Hosting sites; both manifest and artwork endpoints were read back successfully. New catalog additions need a versioned Hosting deployment.

Five starter scenes are free. Pro uses the RevenueCat SDK through `PurchasesService`; the native paywall reads the current offering and Apple's localized prices, defaults to yearly, exposes Restore, Terms and Privacy, and handles unavailable products with a bounded retry state. Rewarded access is a clearly labeled, cancellable debug-only test provider. Failed exports retain the reward. App Store Connect prices are $6.99 monthly and $79.99 yearly with Apple-equivalent territory pricing. RevenueCat has matching App Store and Play products attached to the `pro` entitlement and current `default` offering. Google Play has active monthly and yearly subscriptions at USD 6.99 and USD 79.99 with Play-derived regional prices. The Android public SDK key is supplied outside source at build time. The separate native Android parity lane is defined in [docs/android-parity.md](docs/android-parity.md), including a true Android live wallpaper and capability-gated Huawei support.

## Validation and limits

See [verification](docs/verification.md), [feature registry](docs/features.md), and [artwork provenance](docs/artwork.md). App Store Connect readback on 2026-09-24 shows app `6814078185`, bundle `com.screenmotion.studio`, version 1.0.1 ready for sale, build 5 valid, and its review submission complete. Version 1.0.2 is in `PREPARE_FOR_SUBMISSION`; the signed build-6 archive and IPA are prepared locally but not uploaded, and no review submission is claimed. A successful paired-resource test is not proof that iOS accepts playback on the physical lock screen. Pixel and realistic scenes animate and respond inside the app; system wallpapers use Apple's supported still, Live Photo or video behaviors. Frame-rate targets are configured at 60/30 FPS, not yet measured on a physical device.
