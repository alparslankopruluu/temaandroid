# Security Model — {{APP_NAME}}

*Canonical owner for app-specific data classification, trust boundaries, abuse cases, and incident readiness. Global rules live in `docs/checklists/security.md`.*

## Risk profile

- **Category flags:** {{RISK_FLAGS}} <!-- health | kids | UGC | AI | finance | sensitive-data | none -->
- **Highest-risk user harm:** {{HIGHEST_RISK}}
- **Review-sensitive claims/flows:** {{REVIEW_SENSITIVE_FLOWS}}

## Data and SDK inventory

| Data / SDK | Classification | Purpose | Owner/location | Retention/deletion | Client access | Privacy label / manifest |
|---|---|---|---|---|---|---|
| {{DATA_OR_SDK}} | public · account · private · sensitive · secret | {{PURPOSE}} | {{OWNER}} | {{RETENTION}} | {{ACCESS}} | {{DISCLOSURE}} |

## Trust boundaries and abuse controls

| Boundary / abuse case | Prevent | Detect | Recover / owner | Test evidence |
|---|---|---|---|---|
| Client → callable/API | Auth + App Check + schema validation + per-user rate limit | redacted metrics/alerts | revoke/disable/rotate; {{OWNER}} | {{EVIDENCE}} |

Include account takeover, replay/duplicate writes, paid-API abuse, entitlement spoofing,
admin escalation, malicious uploads/UGC, data export/deletion, and provider outage when applicable.

For every user-owned resource, include an IDOR negative test proving another authenticated
UID cannot read, update, or delete it. For login/reset and costly AI/email/upload paths,
record user/IP/device abuse controls and privacy-safe detection. Upload surfaces must state
size, MIME/content verification, extension, executable-content, storage owner, and public
access policy.

## Incident and review readiness

- **Credential rotation route:** {{ROTATION_ROUTE}}
- **Kill switches / degraded mode:** {{KILL_SWITCHES}}
- **Account deletion proof:** {{DELETION_PROOF}}
- **Reviewer journey/account:** {{REVIEWER_JOURNEY}}
- **Privacy-label and permission-inventory evidence:** {{PRIVACY_EVIDENCE}}
- **Web security headers / CORS evidence:** {{WEB_SECURITY_EVIDENCE}}
- **Repo-history secret scan / rotation owner:** {{HISTORY_SECRET_EVIDENCE}}

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
