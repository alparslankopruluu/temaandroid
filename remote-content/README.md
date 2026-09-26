# Remote theme catalog

ScreenMotion loads a small public JSON catalog from Firebase Hosting and downloads only the
referenced HTTPS assets. The app accepts declarative, allowlisted recipes; it never downloads
or executes Swift, JavaScript, shaders, or other code. There is no user account or Firestore
collection in this delivery path.

## Add a theme

1. Create original or properly licensed artwork. Add a full-screen PNG/JPEG/WebP background
   under `remote-content/public/v2/assets/<contentVersion>/`; optional ambient audio may be
   M4A, MP3, or AAC. Versioned paths are required by immutable CDN caching.
2. Add a schema-v2 entry to `remote-content/public/v2/manifest.json`. Include an English title,
   localized title/summary, asset paths, 1–8 layers and a recipe using the supported animation,
   particle and interaction names. The app caps each recipe at 4 emitters and 160 particles.
3. Increment `contentVersion` for every published catalog or asset change. Keep asset filenames
   immutable and store them below that version's directory. The manifest is revalidated in-app; invalid entries are ignored
   and bundled themes remain available.
4. Run `python3 scripts/validate-remote-themes.py` and `python3 scripts/verify-content.py`.
5. After the ScreenMotion Firebase Hosting sites have been provisioned and each target is
   verified, stage a deployment with `python3 scripts/deploy-remote-themes.py --environment dev`.
   The script rewrites only a temporary manifest copy so its asset URL matches the selected
   project; review the dry-run output, then pass `--deploy` to publish. Production uses
   `--environment prod --deploy` and must follow the release approval gate.

The manifest is served without a stale cache; versioned assets use immutable cache headers.
Do not put private information, credentials, analytics identifiers, or user-generated data in
this public catalog. Ambient audio plays only after the user taps its in-app control; iOS does
not put audio into a Live Photo or system wallpaper.

`public/v2/manifest.json` is the source of the live version-2 sample package. Debug reads the
`screenmotion-dev` site; Release reads `screenmotion-prod`. Both Hosting sites are provisioned
and currently serve this catalog.
