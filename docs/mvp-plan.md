# Approved implementation and release progression
Current milestone: M3 — Production purchase setup and App Store release gates.
M0–M2 implementation is present and accepted locally. The StoreKit purchase/expiration regression and paywall compliance UI journey pass on the current simulator runtime.
M0: Kit and native app/widget targets.
M1: Scene engine, 16 realistic scenes, editor, exports, library, icon packs, widgets and installation.
M2: Local StoreKit and rewarded test provider; 22 locales.
M3: App Store Connect/RevenueCat catalog, production purchase integration, build, tests, store assets, simulator visual review and physical-device gates. In-app pixel worlds are local product work inside this studio; they do not change the lock-screen contract or authorize review submission.
## Scope Fence
Production RevenueCat subscription setup and App Store 1.0 review submission are approved. Firebase/R2, production ads, user AI generation, accounts, weather/health services and Android remain out of scope. Review submission remains blocked until the release checklist is green; catalog identifiers and pricing must match the approved production plan.

## Live release state — 2026-09-21

- App Store Connect app `6814078185`, bundle `com.screenmotion.studio`, version `1.0` in `PREPARE_FOR_SUBMISSION`.
- Subscription group `22398612`; monthly product `com.screenmotion.pro.monthly` (`6814078761`) is priced at USD 6.99 and yearly product `com.screenmotion.pro.yearly` (`6814170987`) at USD 79.99. Both have complete 175-territory price coverage and availability plus 22 product/group localizations.
- Apple reports both products as `READY_TO_SUBMIT`. Their review screenshots are present; the first subscription submission still has to be attached to app version 1.0 during Add for Review.
- RevenueCat production SDK integration is active. The app reads the current `default` offering and presents a native, offering-driven paywall with yearly preselection, localized Apple prices, Restore, Terms and Privacy. The remote RevenueCat paywall template is not required by this binary. Runtime product readback and local StoreKit acceptance pass; dashboard readback was unavailable in the latest session because MCP authentication expired.
- Build 4 (`98c09e2a-42a5-4d86-8960-89e68630e726`) is `VALID` and attached to version 1.0. English 13-inch iPad screenshots (2064x2752, four COMPLETE `APP_IPAD_PRO_3GEN_129` assets) are on the version localization. A draft review submission (`5d33748b-2692-444e-a52a-7d021d5a4d97`) includes the app version plus monthly/yearly subscription versions and remains `READY_FOR_REVIEW`; it has not been submitted. Sandbox purchase/restore and physical-device acceptance remain open.
