# ScreenMotion Android

Native Kotlin/Compose port of the owned iOS app. It keeps the same 28-theme catalog,
editor controls, favorites, saved designs, still/video exports, four 24-icon packs,
four widget styles, Pro entitlement name and 22-locale canonical string catalog. Android
adds a real touch- and tilt-aware `WallpaperService` with a low-power frame-rate fallback.
Firebase Anonymous Auth silently links a stable app identity to RevenueCat; Analytics and
Crashlytics collect allowlisted events and sanitized diagnostics. Debug builds use the
gitignored `app/src/debug/google-services.json` from `screenmotion-dev`; release builds
use `app/src/release/google-services.json` from `screenmotion-prod`.
Preview, media export, live wallpaper and widget snapshots use the same configuration-aware
scene renderer; setup progress is persisted per theme and configuration.

## Build and verify

Use JDK 17 and Android SDK 36.

```sh
python3 scripts/sync_ios_content.py
python3 scripts/verify_android_content.py
./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest :app:lintDebug
./gradlew :app:bundleRelease
```

The release bundle is `app/build/outputs/bundle/release/app-release.aab`. It is minified
and resource-shrunk. `bundletool validate` and an installed universal APK smoke are part
of the recorded local acceptance. Google Play uploads use a repository-external upload
keystore through `SCREENMOTION_UPLOAD_STORE_FILE`, `SCREENMOTION_UPLOAD_STORE_PASSWORD`
and `SCREENMOTION_UPLOAD_KEY_PASSWORD`; secret values must stay outside source and logs.

## Purchases

The app only configures RevenueCat when the Gradle property below is supplied at build
time. The key is a public SDK key and must still correspond to an approved Google Play
app, products, `pro` entitlement and current offering.

```sh
./gradlew :app:assembleRelease -PSCREENMOTION_REVENUECAT_PUBLIC_KEY=goog_public_sdk_key
```

Without that property, release builds keep paid content locked and show an unavailable
state. Debug builds offer the clearly labeled local Pro and rewarded-export simulations.

## External gates

The Google Play Internal Testing release is published, and the monthly/yearly Play products
are connected to RevenueCat's `pro` entitlement and `default` offering. RevenueCat still
needs Google Play service-account credentials for store validation. The signed billing-enabled
code-2 AAB predates the current M4 source and is not a parity artifact; a fresh release build
requires local validation after device acceptance. Its replacement upload key becomes valid
on 2026-09-25 at 16:14 UTC.
Tester assignment, upload after activation, production rollout and AppGallery remain external
gates. See
[`docs/android-parity.md`](../docs/android-parity.md) for the evidence and platform limits.
