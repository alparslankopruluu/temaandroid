# Approved implementation and release progression
Current milestone: M3 — Production purchase setup and App Store release gates.
M0–M2 implementation is present and accepted locally. The StoreKit purchase/expiration regression and paywall compliance UI journey pass on the current simulator runtime.
M0: Kit and native app/widget targets.
M1: Scene engine, 16 realistic scenes, editor, exports, library, icon packs, widgets and installation.
M2: Local StoreKit and rewarded test provider; 22 locales.
M3: App Store Connect/RevenueCat catalog, production purchase integration, build, tests, store assets, simulator visual review and physical-device gates. In-app pixel worlds are local product work inside this studio; they do not change the lock-screen contract or authorize review submission.
## Scope Fence
Production RevenueCat subscription setup and App Store 1.0 review submission are approved. Firebase/R2, production ads, user AI generation, accounts, weather/health services and Android remain out of scope. Version 1.0 is now waiting for App Review. Catalog identifiers and pricing must continue to match the approved production plan. Sandbox purchase/restore and physical-device acceptance remain open evidence, not implied by WAITING_FOR_REVIEW.

## Live release state — 2026-09-21

- App Store Connect app `6814078185`, bundle `com.screenmotion.studio`, version `1.0` is `WAITING_FOR_REVIEW`.
- Subscription group `22398612`; monthly product `com.screenmotion.pro.monthly` (`6814078761`) is priced at USD 6.99 and yearly product `com.screenmotion.pro.yearly` (`6814170987`) at USD 79.99. Both have complete 175-territory price coverage and availability plus 22 product/group localizations.
- Monthly, yearly, and group version `4962b340-2bca-4120-ab79-5a0ea3e77a97` are `WAITING_FOR_REVIEW` with app version 1.0. Review screenshots remain present; promotional subscription images are still absent and are not required for this first review.
- RevenueCat production SDK integration is active. The app reads the current `default` offering and presents a native, offering-driven paywall with yearly preselection, localized Apple prices, Restore, Terms and Privacy. The remote RevenueCat paywall template is not required by this binary. Runtime product readback and local StoreKit acceptance pass; dashboard readback was unavailable in the latest session because MCP authentication expired.
- Build 4 (`98c09e2a-42a5-4d86-8960-89e68630e726`) is `VALID` and attached to version 1.0. All 22 localizations have exactly four COMPLETE iPhone 6.7 (`APP_IPHONE_67`) and four COMPLETE 13-inch iPad (`APP_IPAD_PRO_3GEN_129`) screenshots. Review submission `5d33748b-2692-444e-a52a-7d021d5a4d97` was submitted at `2026-09-21T11:05:17.78Z` and is `WAITING_FOR_REVIEW`. Sandbox purchase/restore and physical-device acceptance remain open and are not implied by this store state.
