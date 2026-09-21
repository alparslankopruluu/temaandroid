# Features — local implementation registry

| Feature | Screens | Evidence / status | Strings |
|---|---|---|---|
| Interactive welcome | Welcome | UI journey, no account/paywall barrier | welcome.* |
| 16 realistic scenes | Discover | Catalog, artwork and compatibility checks | discover.*, theme.*, filter.realistic |
| 6 pixel scenes | Discover / Editor | In-app SpriteKit gyro/touch plus optional score mode; lock-screen gyro is not claimed | filter.pixel, editor.scoreMode, theme.pixel-* |
| Scene editor | Editor | Shared editor chrome; deterministic renderer and simulator pixel journey | editor.*, style.* |
| Dynamic catalog overlay | Discover | HTTPS-only remote titles/visibility/order; never grants Pro | (remote titles) |
| JPEG / video / Live Photo | Export | Pair identity, timed track and duration test; physical playback pending | export.*, platform.* |
| Favorites / designs | Library | Persistence tests | library.* |
| Guided installation | Install | Persisted steps, wallpaper/icons/widgets instructions | install.* |
| 96 icons | Package | Four packs × 24 distinct PNGs tested | package.* |
| Widgets | Widget extension / package | Compiled, shared snapshot; device install pending | widget.* |
| Pro | Paywall / settings | RevenueCat SDK wrapper and native offering-driven paywall; localized prices, yearly preselection/Most Popular, retry, Restore, Terms and Privacy; local purchase plus expiration/revocation and paywall UI tests pass; ASC monthly/yearly products at $6.99/$79.99 are `READY_TO_SUBMIT`; signed-device sandbox acceptance pending | pro.*, purchase.*, legal.* |
| Rewarded export | Export | Clearly labeled local simulator, cancellation tested | ad.* |
| 22 languages | All screens and widget | Key completeness; Turkish/Arabic UI captures; dynamic-key guard and Turkish export-hint regression | all |

Analytics: no external analytics SDK is currently included. RevenueCat is included for purchases and entitlement management. App Privacy currently declares Purchases, Device ID and Product Interaction with tracking disabled; recheck the signed release binary and provider configuration before submission.
