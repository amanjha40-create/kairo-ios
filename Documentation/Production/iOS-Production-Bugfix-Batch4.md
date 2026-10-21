# Production bugfix Batch 4 — Home hierarchy and Light Mode

## Baseline and scope

Starting SHA: `39039dd3445674b987791b844288f495b6db32bb`.
Isolated branch: `codex/ios-production-bugfix-batch4`.
Presentation only: no service, payload, authentication, verification, bottom-tab,
provider, backend, Android or Production configuration changes. No TestFlight
upload or main merge. Historical dirty checkout remains excluded.

## Phase 0 — Home inventory (recorded before implementation)

Exact current order from `HomeOverviewScreenView` at the baseline. Dimensions
are source-defined, content-dependent, not fabricated fixed device measurements.

| Order / section | Purpose | Priority | Current size / visual weight | Actionable? | Redundancy | Decision |
|---|---|---|---|---|---|---|
| 1. Header: 108-point logo, greeting, notification bell/badge | Identity and notifications | High | Title2 greeting; 44-point bell; 16-point page insets | Notifications | No | Keep safe-area and badge semantics |
| 2. Trust Score + status + View Trust Passport | Current trust state and Passport destination | Primary | 46-point scalable score, 16-point padded white rounded surface, 44-point Passport row | Passport | Already one combined hero, not two | Keep relationship; add restrained branded surface, never equate score with verification |
| 3. Needs Your Attention | Authoritative requests needing Candidate input | Required first | Headline/divided section; up to 3 destination rows; View all when >3 | Only real request IDs; otherwise no-task/refresh copy | No-task state occupies a whole section | Preserve all state/copy, compress quiet state and emphasise actual attention |
| 4. DigiLocker | Connection summary and Hub entry | Secondary | Full-width icon/title/metadata row, 24-point icon, >=44-point target | Existing Hub only | Interrupts tasks before Career | Regroup below progress with existing document/identity entries |
| 5. Permanent address (conditional) | Canonical enabled address status | Secondary | Compact destination row, conditional on enabled source | Existing status sheet | Interrupts tasks; no independent error banner | Regroup with identity, preserve read/enable conditions |
| 6. In progress (conditional) | Non-attention active verification | Middle | Headline/divided section, up to 3 rows, View all when >3 | Existing request routes | Distinct from attention; no duplicate request | Move directly after attention, before optional integrations |
| 7. Build Your Trust | Career counts, profile %, progress, recommendation, compact task statuses | Middle / next step | Headline, progress line, recommendation row; up to 3 sorted tasks; possible Continue profile | Existing Career/Verify routes | Recommendation title deduplicated from task list; secondary Continue profile remains distinct | Group related progress, retain upstream priority and route semantics |
| 8. Recent trust changes | Historical activity only | Lower | Divided headline + all supplied title/time rows or one empty line | No | Never an active-request substitute | Keep lower, compact spacing; do not remove history |
| 9. Documents | Career attachments/private documents entry | Secondary | Compact full-width row | Canonical Documents Hub | Same general category as identity entries | Regroup without losing route |
| 10. Recent Passport views | Latest supplied activity and full history destination | Lower | Headline + compact title/time destination or empty/history copy | Views & Share Activity | Distinct from score/Passport owner route | Group with recent trust changes, retain destination |

There is no independent AI/intelligence card in this Home implementation.
No separate document-upload prompt exists beyond Career recommendations and the
Documents destination. Trust consent/manual-review status appears in the score
summary; notification unread badge and unavailable verification copy are the
other status treatments. Shared invitation/tour overlays belong to the app shell
and must remain unchanged.

Loading/error replace the dashboard below the retained header. Loading uses the
existing accessible progress state; transport failure says offline and offers
the existing Retry; unknown aggregate errors fail closed. Empty Candidate still
renders trust-unavailable, truthful no-task state, profile and existing entries.
Passport is a destination, not a Home-fetched availability Boolean: never infer
Passport readiness from score. Its own loading/error/retry behavior is preserved.

### Source priority / semantic constraints

`HomeOverviewMapper` already takes nextRecommendedStep/missingRequirements from
the dashboard; task priority follows that supplied order. Verification requests
come from the authoritative Verify overview, exclude completed/draft/unknown
rows without routes, and retain status-rank/update ordering. Batch 4 will group
attention before in-progress and profile work, without changing that mapper,
creating a new priority algorithm or turning optional integration into a blocker.

### Light Mode token audit and intended treatment

Current page `#FCFDFE` and surface `#FFFFFF` are almost indistinguishable.
Muted surface is `#F1F4F6`, border `#DFE4E8`; navy `#07122B`, teal `#007F82`,
accent `#12D6C5`, primary text navy and secondary text `#536173` are established.
Dark background/surface/muted/border are `#0B1220/#141F32/#202D42/#39465A`.

Plan: slightly tint shared light canvas/muted/border tokens within the existing
navy-neutral family; leave dark, semantic status and action colours unchanged.
Introduce a reusable opt-in tonal surface for Home's primary trust and grouped
secondary content, not a new card inventory. Preserve font scale, radii, 44-point
targets, existing motion/Reduce Motion, and score/tour anchors. Audit contrast
and cross-screen regression for the shared token changes.

## Implemented presentation

- Header → one tonal Trust/Passport hero → attention → grouped in-progress and
  profile work → Documents & identity → recent changes → Passport view history.
- No-task attention becomes a quiet inline summary; real request actions retain
  a distinct surface. Upstream request order and task priority are unchanged.
- Progress shares one white surface, optional existing identity/document rows
  share a muted group, history stays flat. Page spacing uses the existing 12-point
  token instead of 16; fonts, radii and scalable content are preserved.
- Light canvas/muted/border become `#F3F6F9/#EAF0F4/#D4DEE7`. Opt-in brand surface
  and border use `#E8F5F3/#B4D8D4`. All dark token values and semantic status/action
  colours remain unchanged. Score uses existing teal; it remains explicitly
  labelled Trust Score with its independent status, never a verification badge.
- The Passport action's minimum 44-point size is now inside its actual button
  label with a rectangular content shape. A new UI assertion exposed the old
  external frame's 18-point tappable/accessibility label; routing is unchanged.
- Existing error/loading/offline handling, notifications, tour anchors, motion,
  bottom tabs, provider state reads and navigation remain intact.
- XXXL screenshot review exposed decorative destination icons overflowing their
  fixed columns. Symbols now scale to fit their existing 24-point column; text
  keeps unrestricted Dynamic Type. Home's bell and redundant visual unread
  badge use bounded symbol/text sizes inside the existing 44-point target;
  VoiceOver still announces the full unread count. No route or status changes.
- Visual fixtures are in memory behind the validated UI-test gate. Production
  physical QA additionally requires the existing opt-in development-profile
  gate. No real records are edited to manufacture states.

## Validation history

The first focused state/contrast run passed 8/8. Its UI run identified the small
Passport target above and a new test's incorrect Retry label (the canonical label
is Try Again). These diagnostic runs are not final certification. The final-source
regression and physical results below supersede those diagnostic runs.

### Final-source automated validation

- Full unit/integration: 1,026/1,026 passed, including 8 Batch 4 state/contrast tests.
- Batch 4 Home UI: 12/12 passed on each of iPhone 17e and iPhone 18 Pro Max
  simulators; the physical-only VoiceOver test is explicitly skipped there.
- Production device and arm64 Simulator builds plus static analysis passed with
  strict concurrency set to complete. Existing test-target actor-isolation
  warnings are not represented as a warning-free or Swift 6 migration result.
- Privacy/provenance: 102/102 passed, including six Batch 4 boundary guards.
- Relevant Simulator UI: 96 applicable checks passed across the runs below,
  with two expected physical-only VoiceOver skips. This is the affected UI
  matrix, not a claim that the entire repository UI catalogue was run.
- Small iPhone: 42 applicable UI passes (12 Home, 7 Google handoff, 12 Guided Tour,
  11 visual parity). The combined result also contains two configuration errors:
  Staging-only session tests were mistakenly selected in Development and their
  existing gate correctly prevented fixture entry. No auth source was changed.
- Staging rerun: those 2 session tests both passed in their required configuration,
  covering transient refresh preservation/retry and confirmed rejection.
- Large iPhone: 52 UI passes (12 Home, 11 Career, 8 password/auth/appearance/Home
  routes, 6 parity/navigation, 7 Passport, 8 Verify), zero failures.
- Development-signed physical QA build prepared under `MVT4T97ZGC` with
  `get-task-allow=true`; physical certification is recorded separately below.
- Original checkout still has the same 19 dirty files, HEAD, index digest,
  unstaged diff digest and empty staged diff as the preflight snapshot.

Evidence is stored under `/private/tmp/kairoid-batch4-*`. The `focused`,
`regression-r2` and initial `large` runs are diagnostic/superseded, not closure
evidence. Final source results use `final-small.xcresult`, `final-large.xcresult`,
`device-final.log`, `simulator-final.log` and `privacy-final.log`.
The required session-fixture correction is evidenced by the separate successful
`staging-session.xcresult`; the Development result's nonzero exit is retained,
not hidden or represented as a completely green single invocation.

Final screenshots were reviewed on both simulator sizes. XXXL icons no longer
overlap labels; full text remains scrollable. Light/dark hierarchy, score versus
verification wording, safe-area scrolling and canonical bottom navigation are
preserved. This is a scoped accessibility/contrast audit, not an app-wide WCAG
certification or a change to the existing semantic colour palette.

### Physical certification and normal restoration

- iPhone 11: 13/13 synthetic UI checks passed, zero failures or skips, including
  the physical VoiceOver reading-order test. Result: `physical.xcresult`; log:
  `physical.log` under the same evidence prefix.
- Covered hierarchy, attention/no-task and progress states, scrolling, header
  targets, Passport and notification navigation, loading/error/offline retry,
  light/dark, Accessibility XXXL, Reduce Motion and background/reopen.
- Reviewed physical light/dark and XXXL screenshots. The existing local QA
  banner occupies part of the header at XXXL; unobscured simulator captures
  supplement that header review. This banner is not normal shipping UI.
- VoiceOver was restored to its original off state. The app was relaunched
  without fixture arguments; the founder confirmed normal signed-in Home is
  visible. Background/reopen is covered by the automated physical fixture;
  the founder's reply specifically confirms normal Home restoration.
- No login, logout, provider/GPS flow, upload, verification submission or real
  account-data mutation was performed for this batch.

## Closure and source handoff

Tester issues #7 (Home clutter) and #14 (flat Light Mode) are closed in this
source candidate. No remaining Batch 4 implementation or physical QA blocker
was found. This does not recertify unrelated tester reports or authorize release.

Only the scoped Home/design-system presentation, isolated fixtures, regression
tests and this report are included. Backend, Android, Production configuration,
auth architecture, verification semantics and the historical dirty checkout are
unchanged. No main merge or TestFlight upload is part of this batch; distributed
TestFlight remains 1.0 (6).

The final commit SHA, clean-source signed artifact identity and normal-push
local/remote parity are recorded in the delivery receipt after this report is
committed. The next program step is final iOS release certification, not an
automatic TestFlight upload.
