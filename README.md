# ScreenMotion iOS

Native SwiftUI theme studio built with app-factory 4.5.0. iOS 17+, local-first; no account required.

## Run

Open `ScreenMotion.xcodeproj`, choose the **ScreenMotion** scheme and an iPhone simulator, then Run. The scheme uses `App/Resources/Products.storekit` for local subscription testing. No real charge is made. Device installation requires your signing team and the App Group capability.

```sh
xcodegen generate
python3 scripts/verify-content.py
xcodebuild -project ScreenMotion.xcodeproj -scheme ScreenMotion -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -parallel-testing-enabled NO test
```

## Experience

Discover → interactive preview → Save & set up. Three tabs keep the navigation simple. The editor supports style, motion, optional depth/particles/framing, undo and reset. Favorites, drafts and setup progress persist locally.

16 original realistic artworks plus 6 in-app pixel worlds, four collections, 96 original exported icon glyphs, WidgetKit photo/date/calendar/collection styles. JPEG, paired Live Photo and three-second video exports use the matching scene renderer. Preview clocks and icons are excluded from exports. All 190 interface keys and permission text cover 22 locales. Pixel gyro, touch and optional score mode stay inside the editor. The yearly Pro option is selected by default and carries a localized Most Popular badge.

Four starter scenes are free. Pro uses the RevenueCat SDK through `PurchasesService`; the native paywall reads the current offering and Apple's localized prices, defaults to yearly, exposes Restore, Terms and Privacy, and handles unavailable products with a bounded retry state. Rewarded access is a clearly labeled, cancellable local test provider. Failed exports retain the reward. App Store Connect prices are $6.99 monthly and $79.99 yearly with Apple-equivalent territory pricing. RevenueCat has matching App Store products, the `pro` entitlement and a current `default` offering. Local StoreKit purchase, expiration/revocation and paywall UI acceptance pass. Sandbox acceptance on a signed physical-device build remains a release gate. Production ads and Android remain later work.

## Validation and limits

See [verification](docs/verification.md), [feature registry](docs/features.md), and [artwork provenance](docs/artwork.md). App Store Connect app `6814078185` has valid build 4 attached to version 1.0. All 22 locales have four iPhone 6.7 and four 13-inch iPad store screenshots. Review submission `5d33748b-2692-444e-a52a-7d021d5a4d97` is `WAITING_FOR_REVIEW` with the app version, monthly/yearly subscriptions, and subscription group. That is not App Review approval. A successful paired-resource test is not proof that iOS accepts playback on the physical lock screen. Pixel and realistic motion are interactive inside the app; system wallpapers use Apple's supported still, Live Photo or video behaviors. Frame-rate targets are configured at 60/30 FPS, not yet measured on a physical device.
