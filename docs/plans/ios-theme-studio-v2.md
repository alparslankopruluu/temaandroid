# M4 — Interactive Theme Studio v2

Approved on 2026-09-24. This milestone keeps the existing three-tab SwiftUI product and
expands it to 16 realistic and 12 pixel scenes. Interaction runs inside the app; iOS system
wallpapers use supported still images and Live Photos that the user installs manually.

## Delivery contract

- Every scene has visible ambient movement plus a distinct touch or tilt response.
- Preview, catalog thumbnails, widgets and exports derive from the same scene configuration.
- Motion, particles, depth, framing and color style either affect the output or are hidden
  for a scene that cannot support them.
- Pixel additions are UFO, aquarium, autumn, race, koi and snow. Existing identifiers stay
  compatible with favorites and saved designs.
- Theme preparation produces a lock-screen Live Photo, the existing icon pack and a
  configuration-aware widget snapshot. The product does not present a static Home Screen
  image as fulfillment of the requested continuous interactive experience.
- Saving media and completing the manual iOS installation are separate persisted states.

## Implementation order

1. Make scene simulation deterministic for arbitrary render times and wire every editor
   configuration value into rendering.
2. Prove the approach with UFO, aquarium and motorcycle behavior before applying the same
   renderer contract to the remaining catalog.
3. Expand the pixel catalog to twelve and add scene-specific realistic overlays for all
   sixteen existing artworks.
4. Return typed export receipts, retain share files safely and persist installation progress
   per saved design.
5. Make widget snapshots use the selected scene configuration and complete the coordinated
   setup guide.
6. Run content, unit, UI, accessibility, performance and physical-device gates.

## Product boundaries

- The full continuous scene runs in the app. The app does not use private wallpaper APIs and
  does not claim continuous gyro/touch physics on the iOS Lock Screen, Home Screen, Search
  surface or widgets. iOS exposes no public App Store API for that system behavior.
- Live Photo creation is not proof of physical lock-screen playback. PhotoKit save,
  wallpaper selection and wake animation are separate acceptance steps.
- No new backend, account system, production ads, user-facing AI generation, pricing change,
  Android change, deploy, upload or App Review mutation is included.
- Watermarked reference art is never shipped. `template2` behavior may be adapted, but its
  landscape opaque images are references rather than ready-made portrait sprites.

## Acceptance

- Content validator reports 16 realistic and 12 pixel scenes across all 22 locales.
- Deterministic tests cover repeated, sequential and direct-at-time rendering plus poster /
  video-frame parity.
- Visual review confirms independent movement instead of whole-bitmap panning alone.
- Simulator build and tests pass. Physical-device Live Photo, widget installation, sustained
  frame rate, battery, VoiceOver and sandbox purchase/restore remain explicitly separate.
