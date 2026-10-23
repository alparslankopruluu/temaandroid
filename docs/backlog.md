# Backlog — parking lot

*Every idea that is not in the current milestone lands here — never in code. Reviewed when planning the next release. Format: one line, newest on top.*

| Date | Idea | Source | Notes |
|---|---|---|---|
| 2026-09-21 | Per-theme mini-games beyond shared pixel physics | user | Keep realistic studio UI; do not promise lock-screen gyro. |
| 2026-09-21 | Longer Live Photo / better lock animation | user | Still Apple's playback, not app physics. |
| 2026-09-21 | iPad layout beyond required 13-inch store screenshots | product | 22-locale 13-inch shots are uploaded; a dedicated iPad layout remains later work. |
| 2026-09-21 | Device widget install, sandbox purchase, StoreKit `notEntitled` | release | Open evidence, not claimed complete. |
| 2026-09-21 | Android native Kotlin/Compose port | user | Separate project after iOS. |
<!-- /new-app seeds the Scope Fence items here; append everything else during development. -->

## From the iScreen review (2026-10-23)
iScreen – Widgets & Wallpaper (App Store 1534704608): 153K ratings, 4.7★, Sensor Tower est. 1M–10M downloads and $100K–$500K revenue per month, active paid UA. 1.0.4 took its "theme saved" moment (Complete the look after a save) and its `charging` keyword. Candidates for 1.0.5+, each needing its own approval:
- Daily-updated theme catalog through the existing Firebase schema-v2 manifest (their main retention and revenue engine), with a paid UA test once trial conversion is measured.
- Theme bundles per scene: matching widget skin and icon tint generated from the scene palette, not only per collection.
- Dynamic Island / Live Activity scene companion and a Control Center control for Nightstand and Video → Live Photo.
- Interactive widget mini-moments (tap to change time of day already exists; add one game-like widget).
- Couple widgets: needs accounts, a backend and a privacy review — product decision first.
- Rejected: a discount wheel without a real promotional offer (deceptive promotion).
