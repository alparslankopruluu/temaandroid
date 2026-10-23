# Features — local implementation registry

| Feature | Screens / routes | Analytics events | String namespace | Since |
|---|---|---|---|---|
| Interactive welcome | Welcome | onboarding_viewed, onboarding_completed | welcome.* | iOS baseline; Firebase M5 |
| 16 realistic scenes | Discover | None | discover.*, theme.*, filter.realistic | iOS baseline |
| 12 pixel scenes | Discover / Editor | None | filter.pixel, editor.scoreMode, theme.pixel-* | iOS M4 |
| Scene editor | Editor | editor_viewed, design_saved | editor.*, style.* | iOS baseline; Firebase M5 |
| Dynamic catalog overlay | Discover | None | remote titles | iOS baseline |
| JPEG, video and Live Photo | Export | export_started, export_completed, export_failed | export.*, platform.* | iOS baseline; Firebase M5 |
| Favorites and designs | Library | None | library.* | iOS baseline |
| Per-design guided installation | Export / Install | None | install.* | iOS M4 |
| 96 icons | Package | None | package.* | iOS baseline |
| Widgets | Widget extension / Package | None | widget.* | iOS baseline |
| Pro | Paywall / Settings | pro_paywall_viewed, pro_purchase_completed, pro_purchase_failed, pro_restore_completed, pro_restore_failed | pro.*, purchase.*, legal.* | iOS baseline; Firebase M5 |
| Rewarded export | Export | None | ad.* | iOS baseline |
| 20 cinematic loops (16 painted + 4 code-rendered scenes) | Discover / Editor / Export / Nightstand | export_started(kind=loop), export_completed | theme.aurora, theme.neon-rain, theme.abyss, theme.event-horizon | iOS 1.0.4 (M6) |
| Video to Live Photo (2 free, then Pro) | VideoLive | video_picker_viewed, video_converted, export_started(kind=video) | video.* | iOS 1.0.4 (M6) |
| Nightstand mode | Nightstand | nightstand_opened | nightstand.*, discover.nightstand* | iOS 1.0.4 (M6) |
| iOS 26 Spatial Scene guide | SpatialGuide | tilt_guide_viewed | spatial.* | iOS 1.0.4 (M6) |
| Tappable widget (day → dusk → night + effect) | Widget extension | None | widget.tap | iOS 1.0.4 (M6) |
| Lock Screen cards, pill filters, free featured scene | Discover | None | discover.video*, filter.* | iOS 1.0.4 (M6) |
| Paywall v2: trial timeline, per-week price, welcome offer, locked-scene offer with free preview | Paywall | pro_paywall_viewed(source), pro_paywall_closed, pro_preview_chosen | pro.* | iOS 1.0.4 (M6) |
| Rating prompt after 1st and 3rd successful save | Export / VideoLive | review_requested | None | iOS 1.0.4 (M6) |
| Onboarding v2: 3 value pages, interest pick, personalized offer (Skip always visible); one-time trial offer for upgraders | Welcome / Root | onboarding_step, onboarding_interests, onboarding_completed, pro_paywall_viewed(source=welcome/upgrade) | onboarding.*, welcome.* | iOS 1.0.4 (M6) |
| Paywall v3: lifetime plan, yearly savings badge, pinned CTA with trial price line, plan-aware terms, Pro loop header | Paywall | pro_plan_selected, pro_purchase_completed/cancelled(source, plan) | pro.lifetime*, pro.save, pro.trial.then, pro.terms.lifetime | iOS 1.0.4 (M6) |
| Halloween season: 3 code-rendered Pro loops, Halloween filter, season-first Discover order, `screenmotion://discover/halloween` | Discover / Onboarding | None | theme.halloween-*, filter.halloween | iOS 1.0.4 (M6) |
| Live-only saving (Live Photo; Spatial still on iOS 26), Lock Screen Live Photo metadata, Fill/Fit video framing, preview-first locked scenes, Pumpkin Patch seasonal gift | Export / VideoLive / Discover | scene_opened, video_converted(framing) | export.description, platform.short, video.framing/fill/fit | iOS 1.0.4 (M6) |
| Nightstand open-on-charge guide (Shortcuts automation) and remembered scene | Nightstand | charging_guide_viewed | nightstand.auto.* | iOS 1.0.4 (M6) |
| 22 languages | All screens and widget | None | all | iOS baseline |
| 22-locale App Store screenshots | Store listing | None | store.screenshots | iOS 1.0 |
| Native Android experience | Welcome / Discover / Editor / Library / Settings | onboarding_viewed, onboarding_completed, editor_viewed, design_saved | canonical shared keys | Android 1.0; Firebase M5 |
| Android live wallpaper | Export / system wallpaper preview | None | android_live_wallpaper_note | Android 1.0 |
| Android media export | Export | export_completed | export.*, action_export_* | Android 1.0; Firebase M5 |
| Android icon packs | Package | None | icons.*, package.* | Android 1.0 |
| Android widgets | System widget picker / Package | None | widget.* | Android 1.0 |
| Android purchases | Paywall | pro_paywall_viewed, pro_purchase_completed, pro_restore_completed, pro_restore_failed | pro.*, purchase.* | Android 1.0; Firebase M5 |
| Android and Huawei guidance | Install | None | android_install_*, huawei_theme_note | Android 1.0 |
| Android M4 parity | Discover / Editor / Export / Install / widgets | None | 196 shared keys plus platform strings | Android M4 local |
| Firebase dynamic scene catalog | Discover / Editor / Export | None | remote theme localized text, audio.* | iOS M5 |
| Remote scene recipes | Editor / export renderer | None | existing editor.* | iOS M5; touch/drag share editor scrolling |
| Rainfire cabin pixel scene | Discover / Editor / export | None | theme.pixel-rainfire | iOS M5 sample |
| Google Play Internal Testing release | Play Console | None | release metadata | Android 1.0 |
| Google Play subscriptions | Play Console / Paywall | None | pro.*, purchase.* | Android 1.0 |

Firebase Anonymous Auth, Analytics and Crashlytics are integrated into both native apps under M5. RevenueCat remains isolated to purchases and entitlement management, with Firebase anonymous UID linked through its wrapper. Realtime event and crash receipt validation remains a device/provider gate. Android delivery evidence and remaining device/provider gates are recorded in
[`android-parity.md`](android-parity.md); iOS release evidence remains in the platform release
documents.
`app_opened` is emitted by both app roots when the main UI starts.
