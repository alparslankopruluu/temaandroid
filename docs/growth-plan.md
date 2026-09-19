# Growth Plan — {{APP_NAME}}

*Canonical owner for acquisition, activation, retention, conversion, launch sequencing, and experiment backlog. Metrics definitions remain in `docs/playbooks/analytics.md`.*

## Growth thesis

- **North-star metric:** {{NORTH_STAR_METRIC}}
- **Primary acquisition channel:** {{PRIMARY_CHANNEL}}
- **Why we can win there:** {{CHANNEL_THESIS}}
- **Natural sharing/referral loop:** {{REFERRAL_LOOP}} <!-- "none" unless sharing is native to product value -->
- **Break-even CAC / LTV evidence:** {{CAC_LTV_EVIDENCE}}

## MRR ladder

**Current rung:** {{MRR_RUNG}} <!-- rung-1 | rung-2 | rung-3; every week's work names the rung it serves -->

| Rung | Goal | How | Graduation evidence |
|---|---|---|---|
| 1 | $0 → first $100 MRR | Unscalable by design: 20 people paying ~$5. DM your own network, reply to every store review personally, send the first ~100 outreach messages by hand. This is validation, not scale — if 20 humans won't pay, no creator budget fixes the idea. | 20 paying users + the sentence that made them understand the app |
| 2 | $100 → $1,000 MRR | One reliably working channel before adding a second: organic posting cadence, meme-page buys, first small creator deals (`docs/playbooks/distribution.md`). | a channel that repeats profitably for ≥2 consecutive cycles |
| 3 | $1,000 → $10,000 MRR | Paid ads — only after organic creatives already convert and the audience is known. Reinvest revenue; mind the ~1.5-month Apple payout lag. | proven creatives + ARPU/CPM math that clears margin |

Rules: **don't skip rungs** — starting at rung 3 sets money on fire. **Ramen profitable
(covers the founder's living costs) is the real milestone**, not $10k: a bootstrapped
app with a tool subscription and a $99 developer account is default-alive from day one —
nobody can make you stop, and every party (creators included) treats you better when you
are not desperate. Momentum is the managed resource; revenue is how you buy it.

## Funnel baseline

| Stage | Source | Current | Target | Evidence window |
|---|---|---:|---:|---|
| Impression → product page | ASC | {{IMPRESSIONS_TO_PAGE}} | {{IMPRESSIONS_TO_PAGE_TARGET}} | {{WINDOW}} |
| Product page → download | ASC | {{PAGE_TO_DOWNLOAD}} | {{PAGE_TO_DOWNLOAD_TARGET}} | {{WINDOW}} |
| Download → activation | Firebase/GA | {{DOWNLOAD_TO_ACTIVATION}} | {{DOWNLOAD_TO_ACTIVATION_TARGET}} | {{WINDOW}} |
| Paywall → trial | Firebase + RevenueCat | {{PAYWALL_TO_TRIAL}} | {{PAYWALL_TO_TRIAL_TARGET}} | {{WINDOW}} |
| Trial → paid | RevenueCat | {{TRIAL_TO_PAID}} | {{TRIAL_TO_PAID_TARGET}} | {{WINDOW}} |
| D1 / D7 retention | Firebase/GA | {{RETENTION}} | {{RETENTION_TARGET}} | {{WINDOW}} |

Use `unknown` when evidence is unavailable; never manufacture a baseline.

## Launch system

- **Locale keyword matrices:** canonical ASC metadata/keyword evidence paths: {{KEYWORD_EVIDENCE}}
- **First-three screenshot hooks:** {{SCREENSHOT_HOOKS}}
- **Strongest first-two screenshot benefits:** {{FIRST_TWO_SCREENSHOT_BENEFITS}}
- **Three-second demo / video-ready state:** {{DEMOABILITY}} / {{VIDEO_READY_STATE}}
- **Landing / CPP / PPO / In-App Event plan:** {{STORE_GROWTH_SURFACES}}
- **Product-page narrative:** {{PRODUCT_PAGE_NARRATIVE}}
- **Supported store locales:** {{STORE_LOCALES}}
- **CPP mapping (audience / intent+keyword / creative / iOS 18+ deep link / analytics):** {{CPP_MAPPING}}
- **PPO contract (one variable / metric / sample / duration / stop):** {{PPO_CONTRACT}}
- **In-App Event opportunity or N/A reason:** {{IN_APP_EVENT_OPPORTUNITY}}
- **Header/search-result creative plan:** {{NEW_CREATIVE_PLAN}} <!-- local preview until live ASC support is proven -->
- **Rating and review-response moment:** {{REVIEW_PLAN}}
- **Lifecycle/retention triggers:** {{RETENTION_TRIGGERS}}
- **Paid-channel hypotheses:** {{PAID_HYPOTHESES}} <!-- plan only; no automatic spend -->

## Organic creative hypotheses

Cadence is a testable hypothesis, not a growth guarantee. Use real build evidence and
select only formats that fit the product: screen recording, problem→solution,
before→after, disclosed founder/user demo, or an honest listicle.

| Rank | Channel / audience | First 3s hook | Real product proof | Format | CTA | Variant | Primary metric | Stop condition | Status |
|---:|---|---|---|---|---|---|---|---|---|
| 1 | {{CREATIVE_CHANNEL}} | {{CREATIVE_HOOK}} | {{PRODUCT_PROOF}} | {{FORMAT}} | {{CTA}} | {{VARIANT}} | {{METRIC}} | {{CREATIVE_STOP}} | proposed |

Never hide the founder/brand relationship, pretend to have discovered your own app,
seed fake accounts/reviews, post planted/seeded comments on the app's own promotions,
run incentivized reviews, buy purchased engagement/followers, spam communities, or
manipulate platform engagement.

## Post-launch content operations

- **Cadence:** {{CONTENT_CADENCE}} <!-- daily health, weekly creative, monthly strategy by default -->
- **Content pillars:** {{CONTENT_PILLARS}}
- **Approved real product proof states:** {{CONTENT_PROOF_STATES}}
- **X / Instagram / TikTok / Reddit account ownership:** {{SOCIAL_ACCOUNTS}}
- **Community/brand safety boundaries:** {{COMMUNITY_BOUNDARIES}}
- **UTM campaign/content naming:** {{UTM_CONVENTION}}
- **Publishing approval owner:** {{PUBLISH_APPROVER}}

| Platform | Audience intent | Native format | Primary metric | Guardrail | Current hypothesis |
|---|---|---|---|---|---|
| X | {{X_INTENT}} | {{X_FORMAT}} | {{X_METRIC}} | {{X_GUARDRAIL}} | {{X_HYPOTHESIS}} |
| Instagram | {{IG_INTENT}} | {{IG_FORMAT}} | {{IG_METRIC}} | {{IG_GUARDRAIL}} | {{IG_HYPOTHESIS}} |
| TikTok | {{TIKTOK_INTENT}} | {{TIKTOK_FORMAT}} | {{TIKTOK_METRIC}} | {{TIKTOK_GUARDRAIL}} | {{TIKTOK_HYPOTHESIS}} |
| Reddit | {{REDDIT_INTENT}} | {{REDDIT_FORMAT}} | {{REDDIT_METRIC}} | {{REDDIT_GUARDRAIL}} | {{REDDIT_HYPOTHESIS}} |

## Landing-page operating baseline

- **Primary conversion and destination:** {{WEB_CONVERSION}}
- **Visitor intent / search topics:** {{WEB_INTENT}}
- **Shipped proof asset/state:** {{WEB_PRODUCT_PROOF}}
- **Current message / CTA:** {{WEB_MESSAGE}}
- **Analytics events and consent owner:** {{WEB_MEASUREMENT}}
- **Performance/accessibility baseline:** {{WEB_QUALITY_BASELINE}}
- **Last reconciled with public app version:** {{WEB_APP_VERSION_DATE}}

Working research, platform drafts, asset prompts, and the full website design brief live
under ignored `.factory/post-launch/<date>/`; only durable decisions belong here.

## Six-week launch calendar

Each week's Outcome names the MRR-ladder rung it serves.

| Week | Outcome | Actions | Evidence / stop condition |
|---|---|---|---|
| 1 | {{W1_OUTCOME}} | {{W1_ACTIONS}} | {{W1_EVIDENCE}} |
| 2 | {{W2_OUTCOME}} | {{W2_ACTIONS}} | {{W2_EVIDENCE}} |
| 3 | {{W3_OUTCOME}} | {{W3_ACTIONS}} | {{W3_EVIDENCE}} |
| 4 | {{W4_OUTCOME}} | {{W4_ACTIONS}} | {{W4_EVIDENCE}} |
| 5 | {{W5_OUTCOME}} | {{W5_ACTIONS}} | {{W5_EVIDENCE}} |
| 6 | {{W6_OUTCOME}} | {{W6_ACTIONS}} | {{W6_EVIDENCE}} |

## Ranked experiment backlog

Only one experiment may be active on a surface. Starting Remote Config, RevenueCat,
PPO/CPP, In-App Event, price, or paid-media changes requires explicit apply approval.
Operate Apple product-page variants through `/app-store-growth`; record version/build,
surface IDs, locales, immutable manifest, readback, and decision evidence.

| Rank | Bottleneck | Hypothesis | Primary metric | Minimum runtime/sample | Stop condition | Status | Decision evidence |
|---:|---|---|---|---|---|---|---|
| 1 | {{BOTTLENECK}} | {{HYPOTHESIS}} | {{PRIMARY_METRIC}} | {{MINIMUM_RUNTIME}} | {{STOP_CONDITION}} | proposed | {{EVIDENCE}} |
