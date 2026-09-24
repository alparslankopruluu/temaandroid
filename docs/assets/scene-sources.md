# Scene asset provenance

## Bundled ScreenMotion art

The 16 realistic artworks and existing pixel backgrounds remain the product's canonical
bundled sources. Layered procedural overlays created in code belong to the matching theme and
must be recorded here when a raster asset is added or replaced.

## `template2` reference

- Repository: `https://github.com/alparslankopruluu/template2.git`
- Reviewed revision: `97dadf6693e2057b5c91e4b767ab51ae0d369525`
- Useful behavior references: `AquariumScene.swift`, `SpaceScene.swift`, `NatureScene.swift`,
  `VehicleScene.swift` under `ios/ScreenMotion/Scenes`.
- Eight files under `assets/lock_wallpapers` are opaque 1280×720 JPEG images despite `.png`
  names. They are composition/color references, not transparent portrait sprites.
- Their metadata identifies Grok Imagine generated media; the repository has no LICENSE or
  original `screenmotion-shots/v4` source history. Do not ship them without a separately
  recorded provenance decision.

## Prohibited sources

Screenshots of stock-search results and any visibly watermarked image are reference material
only and must not enter the application bundle.
