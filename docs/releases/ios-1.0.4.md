# iOS 1.0.4 resubmission evidence

Resubmitted on 2026-11-18 for App Store Connect app `6814078185`.

## Previous review

- Submission `41c7e4ba-e1cd-4fcc-8e9d-bac6a379a039` (2026-10-29) was rejected under 2.3.8 (app name vs device name) and 2.3.7 (price wording in the in-app event), then removed by the developer.
- 2.3.8: the editable app info now names every locale with "ScreenMotion" (en-US "Live Wallpaper: ScreenMotion"); `CFBundleDisplayName` stays "ScreenMotion"; the bundle ID is unchanged. Local `metadata/app-info/{en-US,tr}.json` and `scripts/m6-metadata.py` now match ASC.
- 2.3.7: all 10 event localizations read back without price or free wording. The event (`6826118291`, 2026-10-30 to 2026-11-02) has ended, stays DRAFT, and was not resubmitted.

## Resubmission

- Submission `0008ed39-9ebc-4003-a4a5-24dd10bb8c40`, submitted 2026-11-18T17:37:19Z, read back as `WAITING_FOR_REVIEW`.
- Items: App Store version `d84fe749-824c-4244-96d9-467c19e2d486` with build 1.0.4 (11) `04ac21f1-e509-4119-8caf-2e8c711bca36`, and IAP version `2aff6f9d-e50a-4f16-a73f-f429fab8dbe2` (Pro Lifetime).
- The Resolution Center thread of the removed submission rejects replies (web API 409, no reply box in the web UI). The fix summary is at the top of the App Review notes instead, read back.

## Validation

- Full `ScreenMotion` test plan on iPhone 17 Pro / iOS 26.2 from commit `fe74d49` (the build-11 source): `TEST SUCCEEDED`, 0 failures; the two on-request store-capture tests skipped by design.
- `asc review doctor`: only blocker was the missing fresh submission.

## Compliance (2026-11-18)

- Regulated medical device: declared not a device (EEA, GBR, USA); `COLLECTED`.
- China mainland AIGC services: No. Security Assessment features: No (user-approved; catalog artwork is pre-made, partly OpenAI-generated, with no in-app generation or messaging). Both Active.
- ICP filing number and Vietnam game license: not applicable, left empty. DSA trader status was already set.
