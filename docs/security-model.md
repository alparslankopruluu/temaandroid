# Security Model — ScreenMotion

*Canonical owner for app-specific data classification, trust boundaries, abuse cases, and incident readiness. Global rules live in `docs/checklists/security.md`.*

## Risk profile

- **Category flags:** sensitive-data (Photos write permission); subscriptions
- **Highest-risk user harm:** a paid entitlement fails to unlock or restore, or exported media is represented as working on the lock screen when the physical device does not accept it.
- **Review-sensitive claims/flows:** monthly/yearly auto-renewing subscriptions, restore purchases, rewarded-export simulator removal for production, Photos add-only permission, Live Photo/Spatial Scene compatibility claims, WidgetKit installation, in-app gyro/touch pixel worlds that must not be described as live lock-screen games.

## Data and SDK inventory

| Data / SDK | Classification | Purpose | Owner/location | Retention/deletion | Client access | Privacy label / manifest |
|---|---|---|---|---|---|---|
| Local favorites, drafts and setup progress | private | Restore user-created configurations without an account | App Group container on device | Until app deletion or user overwrite | App + widget extension only | Not collected; local device data |
| Exported JPEG/MOV/Live Photo resources | sensitive user content | Save the design selected by the user | Temporary app files, then Photos library on explicit action | Temporary resources are removed after export; Photos copy is user-controlled | App writes through Photos add-only flow | Photos permission; no server upload |
| StoreKit transaction and entitlement state | purchase data | Purchase, unlock and restore Pro | Apple; currently evaluated on device | Apple account lifecycle | PurchasesService only | Purchases; not used for tracking |
| RevenueCat SDK | purchase data, identifiers, diagnostics | Cross-device entitlement and offering management | RevenueCat; PurchasesService plus native paywall fallback | Must match the live RevenueCat configuration and privacy policy before release | PurchasesService / ProPaywallView | App Privacy answers currently cover Purchases, Device ID and Product Interaction; tracking remains off |
| Optional HTTPS content overlay | public curation | Titles, visibility, order and artwork URLs | Bundled JSON, last-known-good cache, optional HTTPS manifest | Cache until overwritten or app deletion | ContentStore only; never writes entitlement | Not collected from the user; remote files are public assets |
| Firebase schema-v2 theme recipes | public curation | Localized scene definitions, original artwork and optional in-app ambient audio | Firebase Hosting `screenmotion-dev` / `screenmotion-prod`; versioned client cache | Public; replaced by a later content version | Read-only HTTPS fetch; no Firestore or user write | Not collected; public content only |
| Firebase Anonymous Auth | pseudonymous identifier | Stable app identity linked to RevenueCat for purchase continuity | Firebase Auth in dev/prod project; UID passed to RevenueCat | Until app deletion or Firebase account deletion policy; anonymous cleanup is disabled | Native app only; no account screen | User ID/identifiers need App Privacy review before release |
| Firebase Analytics | usage events and app instance identifier | Measure welcome, editor, export and paywall funnel | Google Analytics linked to Firebase dev/prod | Google Analytics configured retention; review provider settings | Allowlisted event names only, no UID or content parameters | Usage Data/Product Interaction and identifiers need App Privacy review |
| Firebase Crashlytics | diagnostics, crash/install identifiers | Detect crashes and sanitized nonfatal failures | Firebase Crashlytics dev/prod | Firebase retention policy; review provider settings | Sanitized operation codes only; no raw exceptions or user content | Diagnostics/Crash Data and identifiers need App Privacy review |

## Trust boundaries and abuse controls

| Boundary / abuse case | Prevent | Detect | Recover / owner | Test evidence |
|---|---|---|---|---|
| UI → PurchasesService → StoreKit/RevenueCat | Product allowlist, verified transactions/customer info, single service wrapper, bounded load failure and retry | sanitized purchase state/error telemetry only if analytics is later approved | disable offering/product in provider; ship hotfix; product owner | Unit/UI, StoreKit, sandbox and TestFlight purchase/restore evidence required |
| App → Photos library | Add-only purpose string and explicit user action; no library read permission | user-visible success/failure state | user can delete saved media in Photos; app clears temp files | denied/resource-exhaustion/cancellation and physical-device save tests pending |
| App → optional remote catalog | HTTPS-only base URL, path traversal rejection, schema/version gates, last-known-good fallback; accessPolicy describes unlocks but never grants them | decode/validation failure keeps bundled or cached content | disable remote URL in Info.plist; keep bundled catalog | DynamicContentTests |
| Remote manifest/media → iOS | 1 MB manifest cap; 48 themes; 8 layers/theme; 4 emitters and 160 particles/theme; HTTPS, safe path segments, image/audio MIME/extension/byte caps; declarative allowlists only; no code execution | schema-v2 unit tests and Hosting endpoint readback | contentVersion rollback by republishing known-good public JSON/assets; bundled sample remains available | DynamicContentTests and scripts/validate-remote-themes.py |
| Pixel high-score persistence | Local UserDefaults keyed by theme id; no account, no network | N/A | user can delete the app | interaction tests plus local persistence |
| App ↔ widget App Group | Explicit shared container, Codable snapshots, no network or secrets | local decode failure falls back safely | app rewrites snapshot; app deletion clears container | widget compile passed; device install pending |

Include account takeover, replay/duplicate writes, paid-API abuse, entitlement spoofing,
admin escalation, malicious uploads/UGC, data export/deletion, and provider outage when applicable.

For every user-owned resource, include an IDOR negative test proving another authenticated
UID cannot read, update, or delete it. For login/reset and costly AI/email/upload paths,
record user/IP/device abuse controls and privacy-safe detection. Upload surfaces must state
size, MIME/content verification, extension, executable-content, storage owner, and public
access policy.

## Incident and review readiness

- **Credential rotation route:** RevenueCat public SDK key is injected through release configuration and rotated in RevenueCat; no secret/provider key may enter the app or repository. Current production key is not configured.
- **Kill switches / degraded mode:** Keep four starter scenes usable offline; a failed product/offering load must show a recoverable unavailable state and retry, never an indefinite spinner or false Pro access.
- **Remote content degraded mode:** Invalid, unsafe or newer-than-app manifests fall back to last-known-good cache, then bundled catalog. Remote titles and artwork never unlock Pro.
- **Account deletion proof:** Anonymous Firebase identity is created silently. The next release needs an in-app identity deletion path or verified deletion-request handling and a documented RevenueCat entitlement consequence before distribution.
- **Reviewer journey/account:** No demo account. Reviewer opens Discover, previews free and locked scenes, opens Pro, purchases/restores through Apple sandbox, exports to Photos, and follows installation guidance.
- **Privacy-label and permission-inventory evidence:** Current permission inventory is Photos add-only. Firebase Auth, Analytics and Crashlytics disclosures, privacy manifests, policy publication and live App Privacy readback are required before shipping this integration.
- **Web security headers / CORS evidence:** N/A for the native app; required privacy/support/terms HTTPS pages are not yet provided.
- **Repo-history secret scan / rotation owner:** Working-tree and history scans are required before archive; product owner owns any rotation. No production provider credentials have been added.

## Deterministic guards (kit-enforced, not app-specific)

The kit layers four mechanical controls in front of agent actions; prose rules in
AGENTS.md are the policy, these are the enforcement:

1. **`.claude/settings.json` `deny`** — secret files (`**/.env*`, `**/*.p8`, keystores,
   `GoogleService-Info.plist`, `google-services.json`) are unreadable, and destructive
   provider commands (project/bucket/certificate deletion) are unrunnable.
2. **`ask`** — irreversible or spend-adjacent commands (`asc review submit`,
   `asc publish appstore`, `git push`, `rm`, installs) require a human click.
3. **`allow`** — everything else routine is pre-approved so work flows.
4. **Hook backstop** — `scripts/hooks/guard_bash.py` (PreToolUse) tokenizes compound
   commands with shlex and blocks what the string-prefix matcher cannot see: broad
   `rm -rf` (quoting/variables/long flags included), `find -delete`/`xargs rm` over
   broad roots, one level of `sh -c`/`python3 -c` indirection, decoder-to-shell pipes,
   bare `firebase deploy`, force-pushes to main (including `+refspec` and `HEAD:main`
   forms), `--dangerously-skip-permissions`, and secret-file reads routed through Bash.
   `scripts/hooks/guard_edit.py` (PostToolUse, Write/Edit/MultiEdit) nudges on
   force-unwraps, stray `console.log`/`print`, and world-writable Firestore rules.

Contracts: exit 0 allows, exit 2 blocks with the reason on stderr; **internal hook
errors fail closed** (exit 2), so a broken guard can never silently disable itself.
Known limits: the guard models one level of interpreter indirection and no variable
expansion — it is a backstop against plausible agent output, not a sandbox. Coverage is
pinned by table-driven tests in `tests/test_hooks.py`; `install.sh --existing` merges
these settings into a pre-existing `.claude/settings.json` via
`scripts/merge_settings.py` (backup: `settings.json.pre-factory`).
