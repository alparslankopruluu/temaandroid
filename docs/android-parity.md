# Android parity contract

*Canonical owner for iOS-to-Android behavior parity and platform exceptions. Product truth
stays in `PRODUCT.md`; implementation detail stays in `docs/architecture.md`.*

## Source baseline

- **Owned iOS source revision:** `3e0e6646836012345780098b56bfb6c4c71a2d13` (includes M4 from `75bcc8b`)
- **Snapshot:** iOS source is clean at this revision; Android parity edits are local and no Android release artifact was produced
- **Scope:** current iOS M4 behavior plus shipped iOS behavior and Android/Huawei platform extensions below
- **Delivery boundary:** Google Play Internal Testing release published without assigned testers; production draft prepared but not submitted
- **Android application ID:** `com.screenmotion.studio`
- **Minimum / target SDK:** 26 / 36
- **Content proof:** 29 themes (16 realistic, 13 pixel, including bundled Rainfire Cabin),
  23 owned artwork files and 12 deterministic interaction profiles plus schema-v2 remote
  scene recipes; complete keys across 22 locales
- **Source gate:** current iOS M4 content validation and app/widget/test-bundle build passed.
  Full XCTest execution did not start because CoreSimulator failed to materialize a worker;
  physical-device evidence remains open. See `docs/qa/ios-theme-studio-v2.md`.

## Parity contract

| ID | iOS evidence | User behavior to preserve | Android-native implementation | Required states | Acceptance evidence | Status / exception |
|---|---|---|---|---|---|---|
| A01 | `App/App.swift`, `WelcomeView.swift` | Immediate preview, optional welcome, Discover/Library/Settings, theme deep links | Single-activity Compose app and `screenmotion://theme/{id}` | first run, returning, deep link | Debug and minified-release emulator smoke | verified locally |
| A02 | `DiscoverView.swift`, `catalog.json` | Hero, search, four categories, All/Realistic/Pixel, 28-theme grid, packages | Material 3 lazy surfaces and equivalent hierarchy | loading, populated, empty, search, Pro prompt | 28-theme/196-key content contract; emulator visual walkthrough | content contract and tablet Discover smoke verified; remaining states pending |
| A03 | `EditorView.swift`, scene sources | Same preview, favorite/save/undo, three styles, motion/depth/particles/zoom and supported score mode | One configuration-aware native Canvas renderer shared by Compose preview, JPEG/video, and live wallpaper | normal, reduced motion, low power, missing asset, scoring/collision | All-profile physics tests, renderer bitmap contract and editor smoke | unit tests and Pixel UFO tablet smoke passed; full visual/device review pending |
| A04 | `LibraryView.swift`, `LibraryStore.swift` | Persistent favorites, deduplicated drafts, deletion and per-design setup progress | DataStore values keyed by theme plus complete scene configuration | empty, populated, relaunch, delete, exported/not-installed/installed | Instrumented persistence and deduplication test | persistence test passed on tablet emulator |
| A05 | `ExportView.swift`, `ExportService.swift` | Still and 3-second video export, share/save/errors | JPEG and H.264 MP4 at 1080x1920 through MediaStore; export frames use deterministic profile simulation | storage failure, success | Nonblank frame plus playable 30 FPS MP4 dimensions/duration test | media contract passed on tablet emulator; error/progress UI remains simpler than iOS |
| A06 | Live Photo path | Install a moving result as wallpaper | `WallpaperService` preview/install for a genuine animated Android live wallpaper using the shared scene renderer and profile simulation | preview, apply, visible/hidden, surface loss, low power | Release manifest/service build and lifecycle implementation | implemented; physical-device acceptance pending |
| A07 | `InteractiveSceneBehavior.swift`, `PixelThemeScene.swift` | Tilt, drag, tap and optional score behavior for 12 profiles | SensorManager + touch input; deterministic Kotlin physics; wallpaper receives touch where launcher supplies it | touch, tilt, sensor absent, calm, collision, background | Determinism/bounds/score tests and emulator interaction | unit tests passed; physical sensor pending |
| A08 | `PackageView.swift`, `IconExportService.swift` | Four packs of 24 distinct 512px icons | Matching geometric PNG packs, ZIP/share plus launcher instructions | free/Pro, progress, share failure | 24-entry ZIP and distinctness instrumentation | verified locally |
| A09 | Widget extension and bridge | Photo/date/calendar/collection widgets and theme deep links | Four native RemoteViews providers render the selected theme's saved configuration as a snapshot | placeholder, selected scene, resize, tap | Manifest/resource build and config-specific bitmap assertion | configuration-aware source/build and bitmap assertion passed; launcher smoke pending |
| A10 | `InstallView.swift` | Three checkable setup guides | Android wallpaper/icons/widgets guides plus Huawei capability note; per-design steps persist and completion requires export plus all steps | standard Android, Huawei/EMUI | Turkish and English platform text; relaunch persistence | persistence test passed; Android-only additions fall back to English in other locales |
| A11 | purchase service/paywall | `pro`, current offering, annual preselection, localized prices, restore, retry, revoke | `PurchasesRepository` and RevenueCat Google Play adapter; UI never calls SDK directly | loading, empty, purchase, cancel, restore, revoke, offline | Debug/release compile and RevenueCat-enabled release build | implemented; service credentials and real billing acceptance remain external |
| A12 | debug reward path | Cancellable simulated reward grants one successful export only in debug | BuildConfig-gated local reward with cancel and success-only consumption | cancel, grant, failed export retains, success consumes | Release UI excludes grant path | implemented; focused UI automation pending |
| A13 | dynamic content services | Bundled first, schema-v2 themes may add scenes, v1 items only overlay owned IDs, last-good fallback; never grants Pro | Same manifest contract, recipe validation, HTTPS asset cache, shared Canvas recipe renderer and user-triggered ambient audio | invalid schema/path/version/URL/size, offline, last-good | Validator, catalog recipe contract, remote/cache fallback unit tests | local contract matched to iOS 1.0.2; device playback of hosted audio remains pending |
| A14 | 22-locale string catalog | All 196 UI keys; RTL and accessibility | Android resources for the same 22 locales with platform additions | RTL, 200% font, TalkBack, reduced motion | 22-locale/196-key scanner and lint | content scanner and lint passed; RTL/TalkBack/large-font device review pending |
| A15 | iOS-only Photos/Live Photo/widget accessories | Preserve the outcome with platform-native behavior | MediaStore, Live Wallpaper, Android widgets; no Apple Live Photo or lock accessory claims | supported/unsupported capability | device/capability evidence | exception — mapped substitute |
| A16 | New Huawei request | Use additional Huawei flexibility where supported | Android features require no HMS; Theme Studio handoff maps owned art/icon outputs to dynamic lock, home and icons | EMUI supported, Huawei capability unavailable | `android/huawei/README.md` | handoff prepared; Huawei device/Theme Studio evidence pending |
| A17 | HarmonyOS 5+ native | Make platform boundary explicit | Separate ArkTS/HAP product lane; Android APK compatibility is not acceptance | native HAP absent | explicit report | exception — separate future project |

## Platform integration contract

| Concern | iOS | Android / Huawei | Evidence / status |
|---|---|---|---|
| Navigation/state | SwiftUI + Observation | Compose route state + ViewModel/StateFlow/UDF | verified locally |
| Local storage | UserDefaults/App Group | DataStore; no account/cloud sync | persistence test passes |
| Motion | Core Motion + SpriteKit | SensorManager + deterministic Canvas renderer | physics tests pass; physical sensor pending |
| Wallpaper | JPEG/Live Photo/video export | JPEG/MP4 plus true `WallpaperService` | build/export tests pass; physical apply pending |
| Widgets | WidgetKit | Four native RemoteViews providers | builds; launcher smoke pending |
| Purchases | RevenueCat + App Store | RevenueCat + Google Play; exact `pro` semantics | Play products active and linked to `pro`/`default`; service credentials pending |
| Huawei purchases | App Store contract has no analogue | Huawei IAP would require a separate billing adapter/catalog and approval | exception; excluded from local build |
| Remote content | Optional HTTPS manifest, no Firebase | Same schema and entitlement boundary; no Firebase added | validator/cache tests pass; URL disabled |
| Privacy | Apple privacy metadata | Minimal media/sensor permissions; Play declaration remains external | source reviewed; store form pending |

## Approved implementation blueprint and delivered architecture

### Modules

- The delivered local lane uses one `:app` Gradle module with strict `model`, `data`,
  `purchase`, `scene`, `export`, `wallpaper`, `widget` and `ui` package boundaries. This
  keeps the first native port reviewable while preserving extraction seams for later modules.
- Widgets use platform `RemoteViews` instead of Glance. The minified Glance/WorkManager
  dependency caused a release-start crash and added no product value for these static styles;
  removal was confirmed by the final minified APK smoke.
- The app uses a small explicit application container rather than Hilt because the graph has
  two repositories and no scoped feature graph yet. No service locator is exposed to UI code.

### Proposed dependencies

- Android Gradle Plugin 9, Kotlin, Compose BOM, Material 3, Activity Compose,
  Lifecycle/ViewModel, DataStore and Kotlin serialization.
- RevenueCat Android only behind `PurchasesRepository`; release configuration receives the
  Play public SDK key from a user-level Gradle property outside source.
- Native AppWidget/RemoteViews for widgets. Rendering, sensors, MediaCodec, MediaStore and
  `WallpaperService` use Android platform APIs.
- JUnit, kotlinx-coroutines-test, Android instrumentation, lint, R8 and bundletool for
  verification. Benchmark/profile plugins remain deferred until physical-device profiling.
- No Firebase, ads, account SDK, third-party animation engine or Huawei HMS dependency in
  the local milestone.

### Build and acceptance sequence

1. Resolve the iOS purchase-test source gate and freeze portable renderer fixtures.
2. Scaffold the modules under `android/`; copy only owned catalog/artwork and generated
   localization resources.
3. Implement models, persistence, catalog validation and the deterministic renderer.
4. Implement the three-tab journeys, editor, library and platform-correct installation help.
5. Add JPEG/MP4 export, true live wallpaper, icon packs and native RemoteViews widgets.
6. Add the RevenueCat boundary with fake-provider tests; enable the production provider only
   after the Android app config and public SDK key are available.
7. Run unit/UI/golden/accessibility/localization/lint/Detekt gates, then benchmark and test the
   minified build on the available emulator.
8. Produce and bundletool-validate a signed release AAB plus R8 mapping and an Android port
   report; upload only after the matching release gate is explicitly approved.

### External writes and protected actions

The original implementation blueprint authorized local files under `android/` and canonical
documentation updates. On 2026-09-23 the user separately approved the Google Play app,
Internal Testing publication, Play subscription catalog, RevenueCat Android configuration and
production submission. The RevenueCat Android app and catalog links are configured; Play
service credentials, Data Safety, tester management and the final production submission
remain gated by their current evidence and required inputs.

### Expected evidence

- Cross-platform fixtures for all 12 interaction profiles and the current 28-theme catalog.
- Emulator screenshots for welcome, discover, editor, export, library, packages, widgets and
  paywall states in English, Turkish and Arabic.
- Installed live-wallpaper visibility/touch/sensor/lifecycle smoke; still and MP4 media
  inspection; TalkBack/RTL/font-scale checks.
- Debug and minified release tests, R8/resource-shrinking report, Baseline Profile, startup
  and frame timing, AAB identity/hash and bundletool install result.

## Android extension limits

- The live wallpaper renders only while visible, suspends sensors and frames when hidden,
  and targets 60 FPS with a 30 FPS low-power fallback.
- Launcher-provided live-wallpaper touch events are supported; lock-screen touch and launcher
  behavior vary by OEM and cannot be promised without device evidence.
- Android cannot silently apply launcher icon packs across OEM launchers. The app exports the
  complete pack and opens supported system/launcher flows.
- Huawei Theme Studio can package dynamic lock screens, home wallpapers and icons for
  supported EMUI devices, but its project generation and device application require Huawei's
  tool/device validation. HarmonyOS 5+ native delivery requires a separate ArkTS/HAP app.

## Release evidence

- **M4 local validation:** the 28-theme/196-key content scanner, all 13 Android JVM tests,
  lint, and debug app/test APK builds pass. Six instrumentation tests, including MediaStore
  video, per-design setup progress, and configuration-sensitive rendering, pass on the tablet
  emulator. The second connected emulator has an existing differently signed ScreenMotion
  package and rejected installation; its existing app was preserved.
- **Media:** the emulator test decoded the H.264 output as a playable 3-second 1080×1920,
  30 FPS video; the still-render test produced a nonblank frame.
- **Current AAB:** no M4 AAB has been built. The prior code-2 AAB and its performance evidence
  predate these source/resource changes and must not be used as the current parity build.
  Rebuild, revalidate R8/resource shrinking, and recalculate the artifact hash after device
  acceptance.
- **Previous performance:** release cold-start `TotalTime` samples were 1241/1371/1863 ms.
  Emulator GPU frame data was highly janky during the continuous full-screen scene and is not
  accepted as physical-device performance proof; the current M4 renderer has not been measured.
- **Previous code-1 AAB SHA-256:** `57a711f87253237a05f4902ce1e78971160911c6b32556f2542b658d9e5f7b8b`
  (historical artifact only).
- **Signing:** the original upload keystore was unavailable. A replacement repository-external
  key is stored under the user profile with passwords in macOS Keychain. Google Play accepted
  the reset request and will activate it on `2026-09-25T16:14:00Z`. New certificate SHA-256 is
  `6A:92:B1:DD:C0:E5:46:04:48:02:72:3C:BD:E9:75:B0:91:F6:4F:66:26:6F:03:78:50:8A:CF:7A:97:1B:93:4B`.
- **Google Play:** ScreenMotion app `4972931594499621456`, package
  `com.screenmotion.studio`; Internal Testing release `1.0 (1) Internal` is published and
  contains version `1.0` / code `1`, API 26+, target SDK 36, 48 MB download and attached
  ReTrace mapping. No testers are assigned.
- **Play billing:** `com.screenmotion.pro.monthly` / base plan `monthly` and
  `com.screenmotion.pro.yearly` / base plan `yearly` are active auto-renewing subscriptions.
  US prices are USD 6.99 monthly and USD 79.99 yearly; Google Play generated prices for 177
  countries/regions.
- **RevenueCat:** project `ScreenMotion` (`6eac634f`) contains Play app `app9272737cfc` for
  `com.screenmotion.studio`. Monthly product `com.screenmotion.pro.monthly:monthly` and yearly
  product `com.screenmotion.pro.yearly:yearly` each attach to `pro` and the corresponding
  `$rc_monthly` / `$rc_annual` package in the current `default` offering. The public SDK key
  is supplied outside source. Google Play service-account credentials are still absent, so
  RevenueCat reports that it cannot check store status.
- **Previous replacement build:** version `1.0` / code `2` compiled with RevenueCat enabled
  before the M4 Android changes and is signed by the replacement upload key. Its AAB SHA-256
  is `fc9e83c3ca1ebfdfa6ee6b19c3d92f66de5369e1e7c95257ef42549d5bcdfc12`; it is not evidence
  for the current source. Google Play upload timing and external release gates are unchanged.
- **Play production:** release draft `1.0 (1) Production` contains the same AAB and release
  notes. Submission is blocked by incomplete Play setup, full description, production
  country selection, financial-features declaration and health declaration; it was not
  submitted.
