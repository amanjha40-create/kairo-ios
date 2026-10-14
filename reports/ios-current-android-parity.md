# Current Android Candidate parity — certified Staging scope

## Final closure (2026-10-14)

Eight implementation groups found and closed; zero remaining Candidate parity gaps in the authorized Staging scope. All initial PARTIAL/MISSING rows below are resolved. The inventory retains the initial assessment for traceability. Android, backend, Admin, HR, Production and the original dirty iOS checkout were not modified. Real GPS, real address-document upload, manager outreach, release promotion and TestFlight remain excluded.

| Gate | Final result |
|---|---|
| Full unit suite | 813/813 PASS |
| Complete UI coverage | All 267 methods accounted for exactly once in the full shards: 264 PASS, two test-interaction failures, one explicit physical-only speech skip; both failed methods subsequently passed three consecutive corrected confirmations, yielding 266 uniquely passing UI methods and one documented skip |
| Nomination correction | Return dismisses Designation keyboard before scrolling; 3/3 Simulator and 3/3 iPhone confirmations PASS; no app change |
| Existing deletion-fixture correction | Swipe avoids native Passwords accessory above the reported keyboard frame; 3/3 PASS, cancellation remains zero handler calls and confirmed action exactly one; no real account/API |
| Provenance/privacy | 46/46 PASS |
| Physical iPhone 11 | 22/22 PASS, including 14 new parity tests, four Batch 2 and four DigiLocker/navigation tests; iOS 27.0.1 |
| Build matrix | Development/Staging/Demo/Production Simulator builds PASS, strict concurrency complete, iOS 17 deployment target |
| Static analysis / whitespace | Staging analysis PASS; git diff --check PASS; no repository Swift lint/format configuration found |
| Preserved original | HEAD, 19 dirty files, diff hash and index hash unchanged |

The initial full shards are **not** represented as clean one-shot runs: their two failures are retained in the result bundles. Final coverage combines that complete run with scoped, assertion-preserving test-only corrections. Product source remained unchanged after the final tint correction and successful physical/build gates. Simulator speech is not called a pass; the actual iPhone speech check passed repeatedly. The native Done contrast exception is documented below.

Final evidence: `/private/tmp/kairoid-current-parity-shards-a.xcresult`, `…-shards-b.xcresult`, `…-physical-certified.xcresult`, `…-targeted-confirm.xcresult` (three nomination passes plus the retained pre-correction deletion failures), `…-deletion-scroll-confirm.xcresult`, and `…-nomination-physical-confirm.xcresult`. Synthetic physical screenshots and speech are retained in `…-final-xxxl-evidence` and `…-final-voiceover-evidence`. All 21 UI classes and 267 method identifiers were checked against the combined full-run results, with no omitted or unexpected methods.

Normal installed Staging launch was restored without fixture arguments, logout, account switch, reinstall or data clearing; VoiceOver was restored to disabled. Earlier real Home/session preservation was founder-confirmed. Final normal process launch is tool-confirmed; no private Home screenshot was taken to overstate that evidence. The signed development app uses the honest unattested developer provenance sentinel; a clean-source RC attestation is a separate later gate, not claimed by this product certification.

Feature-branch commit/push is authorized after this closure; the exact resulting SHA and remote equality are reported separately rather than placing a stale self-referential SHA in this file. No main merge or deployment is authorized.

Final clean confirmation bundle: `/private/tmp/kairoid-current-parity-final-corrections.xcresult` — both corrected methods repeated three times, **6/6 executions PASS**, no failures. This closes the two retained full-run failures without dropping any test or changing product behavior.

## Baseline audit (2026-10-14)

- iOS starting/local/remote feature SHA: `142e28bdac6d2f0aa98c2cb5c6ab9be7a0af7035`, branch `codex/ios-android-batch-2-mirror`, clean, 0/0 after fresh fetch.
- No newer remote-certified Candidate lineage was found. Main is not silently substituted for the newer certified feature lineage.
- New isolated worktree `/private/tmp/kairoid-ios-current-android-parity`, branch `codex/ios-current-android-parity`.
- Exact clean Android reference: `49130a95582e977e568b191bc55c9956f809887e`, `/private/tmp/kairoid-android-founder-build-20261014`.
- Staging OpenAPI read reports source `1daff01dd030775c5d70d12caae0e9b8b0ce056a`; all required Candidate reference/address/document routes exist. API251/DB090 is user-supplied runtime context, not independently asserted from OpenAPI.
- Xcode 27.0 (27A266a). Prior certified tests: 779 unit / 253 UI / 38 provenance. Fresh baseline: 779/779 unit PASS. Final closure results are above.
- Original dirty checkout remains untouched: HEAD `22d8c5988f7cd5ac4b0e9548216249a92bba674d`, 19 modified tracked files; diff SHA256 `90efbc36419a4aa56383862d784feb77c5402958e7007f55f53f2bee3d30bba8`, index SHA256 `c0b77eda8113698294dd433cdd2836717495cfd9a880185591f96a89c16e8497`.

## Exact source inventory

Compared Android changed production sources from certified Batch 2 reference `899c625463e23be0904b239f5330413dd3c6825b` to `49130a95`, plus current iOS areas. MATCH here means source/product audit; fresh physical certification remains pending.

| Area | Initial assessment | Evidence / work |
|---|---|---|
| Auth | MATCH | Android auth unchanged; iOS transient-refresh preservation retained |
| Onboarding | MATCH | No Android post-Batch2 delta; existing native routes retained |
| Home | PARTIAL | Missing PermanentAddressEntry |
| Career | MATCH | Existing record lists and evidence role semantics |
| Employment | PARTIAL | Missing embedded References section |
| Education | MATCH | No Android delta; not subject to Employment two-primary rule |
| Certifications | MATCH | Existing same-record attachment lifecycle |
| Projects / other records | MATCH | Neutral optional-record presentation retained |
| Verify | PARTIAL | Missing Permanent Address entry/navigation |
| DigiLocker | MATCH | Existing ASWebAuthenticationSession; no Aadhaar |
| Employment References | MISSING | Summary, nomination, change/revalidation, privacy and stale-state handling |
| Permanent Address | MISSING | Structured versioned state, foreground collector, server challenge/session |
| Address Document Evidence | MISSING | Policy-driven private upload/complete/explicit submit/review state |
| Passport | PARTIAL | Missing verified-only permanent-address summary; no private address disclosure |
| Passport sharing | MATCH | Android recipient contract unchanged; private address proof must stay excluded |
| Trust Score | MATCH | Backend only; no contributions from new features |
| Notifications | MATCH | No Android delta |
| More | MATCH | Existing frozen tabs and native routes |
| Account / Settings | MATCH | No Android delta |
| Loading/error/empty | PARTIAL | Add isolated errors/retry for new features, not Home-wide failure |
| Privacy | PARTIAL | New DTO allowlists, no contact/ratings/token/Admin diagnostics presentation |
| Accessibility | PARTIAL | New native controls require XXXL/dark/VoiceOver certification |
| Session recovery | MATCH | Preserve certified transient-failure behavior |
| Navigation/back | INTENTIONAL_NATIVE_DIFFERENCE | Native sheet/back patterns; no new bottom tabs |

Eight implementation groups: reference summary; manager nomination/change; versioned address UI; foreground location evidence; private document lifecycle; cross-surface address entries; new-feature errors/privacy; accessibility/fixture certification. Substates are not inflated into independent gap counts. Final count/status requires reconciliation.

## Boundaries and native differences

- Candidate endpoints only. No backend/Android/Admin/HR source edits, live nomination/invitation, real address edits, GPS batch, document upload or Trust mutation during implementation QA.
- Core Location replaces Fused APIs. Permission is When In Use only; priming is excluded, fresh samples <=3s old, accuracy <=50m, spacing >=6s, at least five samples spanning >=30s, at most ten, total acquisition <=60s. These are capture guards, not local address acceptance/target establishment.
- Location evidence is transient; cleanup on cancellation, inactive/background, failure, timeout and completion. No background entitlement, continuous tracking, coordinates in logs/UI/cache or local acceptance score.
- Reference contacts are only transient user input; summaries decode an allowlist and never show backend private contacts/ratings/comments. No Candidate invite API.
- Address proof is version-bound and separate from GPS and overall verification. Native Files picker and existing secure transfer architecture, with explicit review submission.
- No push/commit until full local and guided physical certification. No release promotion/TestFlight.

## Validation chronology (superseded status entries retained)

Implemented the eight groups in the isolated worktree. Final-source unit suite 813/813 PASS, including 34 new tests; offline provenance/privacy suite 46/46 PASS (38 existing + 8 new). Staging Simulator build PASS with strict-concurrency checking. Initial new-screen UI run: 9/10 PASS; one XCTest identifier-length limitation corrected with a predicate (no product failure). Final complete UI/physical certification remain pending. No final parity certification or feature push yet.

The normal test command without the baseline `SWIFT_STRICT_CONCURRENCY=complete` override exposed an unchanged DigiLocker default-argument isolation diagnostic. The established strict-concurrency command passes. This is not recorded as a warning-free/default-settings build. No unrelated DigiLocker/Guided Tour changes were made.

## Reconciliation against exact Android delta

Rechecked the complete production `src` delta from the previous certified Batch 2 Android reference to 49130a95. New production behavior is confined to employment-references, permanent-address/documents, their Home/Verify/Profile/Passport/Employment entries, route/back policy and query keys. Android experiment/diagnostic tests and native debug collectors are not product features and are intentionally not copied. The unchanged 24-area baseline remains preserved rather than redesigned.

Reference actions are nomination/change only; no invite/send route. The Candidate DTO does not expose an HR-corrected private contact or a separate public correction indicator: iOS displays exposed relationship/status truth, never infers a correction or manufactures private contact details. Permanent Address is Staging-gated like Android. References is also restricted to Staging for this workstream; future Production activation is outside this authorization. No Production activation/configuration changed.

Earlier full regression attempts were intentionally stopped to incorporate the final location-only Cancel-control condition, reference heading/locked-state accessibility copy, and same-version address-save editor completion regression. They are superseded by `/private/tmp/kairoid-current-parity-certification.xcresult`; no incomplete run is claimed as a full UI pass.

The final-source signed development Staging build passed and was installed over the existing iPhone 11 app without uninstall or data clearing. Signature verification passed; bundle `com.kairoid.Kairo`, version 1.0 (1), environment staging, configuration Staging, Demo NO. Normal launch succeeded; founder session confirmation is pending. This uncommitted development artifact is not represented as a clean committed SHA attestation. A clean-source provenance artifact remains a post-certification step.

Native differences: Core Location rather than Fused; CLLocation measurement Date plus monotonic acquisition deadline/clock-jump guard rather than Android elapsedRealtime; native Files picker rather than HTML file input; SwiftUI sheets/Done and VoiceOver switches rather than web routes/checkboxes. Policy, status, privacy, consent, backend authority and frozen tab semantics are unchanged.

## Automated physical follow-up (2026-10-14, pending final gate)

At the founder's request the remaining repetitive checks moved to XCTest on the connected iPhone 11 (current device runtime iOS 27.0.1). Explicit approval was obtained to provision only `com.kairoid.KairoUITests.xctrunner` on existing Team XN5Y3V3CSV. Apple UI Automation was enabled privately on-device. Existing app provisioning is unchanged: both pre-run and test-build embedded profiles hash to `978c4c344a07f73e4f7326827c2d485a8441191b0df6655ea42af120a531a25e`. No project/signing configuration changed.

The initial complete Simulator run passed 813 unit tests and 263/264 UI tests. The single existing Help Center failure attempted to tap a keyboard Search element at y1087 outside an 874-point window. Its helper now sends Return to the focused search field instead; no product behavior changed. The initial physical suite passed 12/14, including XXXL, consent gating and programmatic VoiceOver speech. A generic test swipe dismissed the native nomination sheet; that test now also uses Return instead. A failed Simulator speech assertion exposed missing failure-safe test cleanup; XCTest teardown now restores VoiceOver even when an assertion aborts the test. The test includes current focused speech before advancing focus, so it cannot skip the already-focused consent element. Full final regression is rerunning; these intermediate failures are not concealed or called a clean gate.

Native audit exception: iOS 27's accessibility audit flags the native glass navigation Done button for contrast. The physical element screenshot contains black text and a predominantly RGB249–254 background (black/RGB249 ratio approximately 19.95:1). Only that exact navigation button's contrast finding is allowlisted, with a retained screenshot on every occurrence. Other elements and all other audit categories still fail. No app content color or accessibility check was disabled. Evidence is retained at `/private/tmp/kairoid-parity-contrast-evidence`; this exception is not described as an unconditional system-audit pass.

The final physical suite and complete Simulator rerun are still pending. No source commit or push has occurred.

The expanded physical run subsequently passed 21/22 checks, including existing Home/Career/Verify/DigiLocker/Passport/More fixture navigation and VoiceOver speech. After the native Done exception, the audit exposed a real borderline-contrast default-blue Refresh references action. Both newly introduced References and Permanent Address surfaces now use the existing adaptive `KairoColors.brandPrimary` tint; no global theme or established screen was changed. This finding was not allowlisted. The complete physical suite, focused regression, four-configuration builds and Staging analysis are being rerun against that correction before the final full gate.

## Final physical result and remaining full regression

The corrected-source physical run `/private/tmp/kairoid-current-parity-physical-certified.xcresult` passed **22/22**: all 14 new parity checks, four existing Batch 2 checks, and four DigiLocker entry/provenance checks. It includes real iPhone VoiceOver speech, dark/Accessibility XXXL layouts, explicit document consent, nomination, backend-state presentation, navigation and safe errors. Native Done contrast has only the documented scoped exception; app-content contrast passed. VoiceOver was verified disabled afterward, and the same installed app was relaunched normally without any fixture arguments/environment, logout, reinstall or data clearing. The earlier normal Home/session check was founder-confirmed; the final relaunch is tool-confirmed, not a new claim of inspecting private Home content.

Focused Help Center regression is now 7/7 PASS. Development, Staging, Demo and Production Simulator builds plus Staging analysis PASS with strict-concurrency complete and iOS 17 deployment target. Provenance/privacy remains 46/46 PASS.

Simulator VoiceOver speech proved unstable (`No speech available`) while the physical speech test passed repeatedly. That single speech test is now explicitly physical-only and reports SKIP on Simulator; all existing Simulator accessibility checks remain. This is an explicit platform gate, not a hidden passing Simulator speech claim.

The final complete regression uses one `build-for-testing` output and two disjoint, duration-balanced Simulator shards. All 21 UI classes / 267 methods are assigned exactly once (174 + 93); the complete KairoTests target runs in shard B. Source scheme parallelization is unchanged. Expected accounting is 266 Simulator UI passes + one physical-only skip, with the skipped speech test independently passed on the iPhone. Final results are pending; no commit or push until they are green.

The sharded run re-confirmed 813/813 unit PASS. A nomination test failed before entering Work email: after Designation input, its generic drag repeatedly began in the software-keyboard area instead of scrolling content. The same flow passed repeatedly on the physical iPhone. The test now sends Return to Designation before attempting that scroll, preserving all field validation, save and no-send assertions. No app source changed. The unchanged built products continue the full regression; the corrected test requires separate Simulator and physical confirmation, with this earlier failure retained rather than erased. An extra diagnostic Simulator startup was stopped to avoid delaying the two full-regression runners.

The complete shards finished with 173/174 UI passes in A and 813 unit passes plus 91 UI passes, one UI failure and one physical-only skip in B. The second UI failure was the existing synthetic deletion-handler test. Its isolated unmodified repetitions also failed. Screenshot `/private/tmp/kairoid-synthetic-delete-keyboard.png` shows the native Passwords accessory above XCTest's reported keyboard frame; the old drag started on that accessory, leaving the form stationary. The test now reserves 100 points above that keyboard frame for the accessory and requires the CTA to be above that boundary. It still checks cancellation invokes zero handlers and one explicit confirmed tap invokes exactly one in-memory handler; keyboard submission is not used. The corrected test passed 3/3. No deletion/authentication product source changed and no real deletion request occurred. The nomination correction separately passed 3/3 on both Simulator and physical iPhone. These are the only two test-only corrections after product-source freeze.
