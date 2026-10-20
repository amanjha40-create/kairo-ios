# Production Bug War Room — Batch 1

## Status

Source, build, automated and signed synthetic physical gates passed. Normal Production-configured app restored in place, launched without fixture arguments, and founder confirmed normal signed-in Home visible. Qualified for the authorized scoped commit and normal branch push; final SHA/remote parity are reported after those operations. No upload, deployment, account mutation or provider flow performed in this closure. Production incident attribution is separate from synthetic contract reproduction.

## API43 closure checkpoint — 21 October 2026

This section supersedes the historical API42 checkpoint below; that history is retained for traceability, not as the current backend status.

- Exact current backend source inspected: `badb8318c0733a82c11117174c093e4ca25ac77f`, supplied API43 / Worker13 / DB093 deployment, image `sha256:3c4b7fa04a5d3d9a94fb49a5a955c8b8cf6483b2ec8be457e98556310b891636`. Public live/ready returned 200/200 and version `git-badb8318c073`. No new ECS/DB audit was performed by this iOS closure.
- Backend-lane provenance correction: API42 actually ran `12ffa525af33f154f22fc7f0519acd7d55578907`; its older `APP_VERSION` string was stale. The historical `ee9220...` source is an ancestor, not the exact API42 runtime identity. Relevant Resume modules were unchanged; API43 comparison uses the actual baseline and exact new source. The separate backend report records 2,931 passing packaged tests and rollback-isolated Staging persistence/idempotency checks; this iOS closure did not repeat those live checks.
- The failed Education item's backend cause was subsequently proven and fixed in the separate backend lane: current-study/date normalization conflict. API43 validates after normalization and reports `current_claim_has_end_date` before import. Historical contradictory claims remain available for explicit correction.
- Exact-source comparison found no drift in Passport, Career PATCH or onboarding contracts. Seven offline backend normalization cases passed (four valid current/no-end variants, three explicit conflicting-date variants); no database or network involved.
- Removed the previously uncommitted iOS mapper's silent `is_current=false` assignment when editing an end date. Regression verifies contradictory dates/current flags survive unrelated edits; only explicit date clearing removes date/display/precision. No client compensation for the backend normalization bug is retained.
- Production-configured real Resume service with URL-protocol mocks now covers retained intake → review → explicit edit → save → validation-version update → import → same-key retry → canonical Career service reload. Valid current Education remains current with no end date. A contradictory Education fixture blocks before import. This is synthetic client wire/state evidence, not a new live upload/parser/database run. Backend idempotency/rollback evidence belongs to the separately certified backend lane.
- Historical existing-user onboarding attribution remains unproven. Canonical-state and no-Career-write regressions pass; no speculative route bypass was added.
- Final unit run after the harness isolation and appearance safeguards: 983/983 PASS, zero failed/skipped, `/private/tmp/kairoid-batch1-final-unit-closure.xcresult`.
- Privacy/provenance: 87/87 PASS, zero skipped/failed, including the signed built-app icon check, `/private/tmp/kairoid-batch1-final-privacy-built-app.log`.
- Production-configured isolated Simulator QA: 5/5 PASS, `/private/tmp/kairoid-batch1-qa-appearance.xcresult`. Exported screenshots confirm actual light and dark rendering of the real restoring root and synthetic Passport. An earlier run used an ineffective system-appearance argument; that earlier run is not counted as dark-mode evidence. The corrected harness changes only its separate QA appearance preference.
- Broad relevant UI: 56 PASS / 1 FAIL / 0 skipped, `/private/tmp/kairoid-batch1-closure-ui.xcresult`. The failure is the unchanged missing-phone test's Save-enabled assertion. Its retained screen recording at 25 seconds shows only the first digit of the ten-digit synthetic input; Save is correctly disabled for that incomplete entry. The activity tree records the requested full string, not successful text-field contents. Unchanged isolated reruns passed both on the large Simulator and on the original Simulator/artifact (`kairoid-batch1-phone-original-repeat.xcresult`). The exact mechanism of the incomplete XCTest entry is not established; no auth/product code or assertion was changed. Full contact-suite repeat remains pending. The original failed run is retained and is not relabeled green.
- Final normal Production signed-device build and analysis passed (`kairoid-batch1-final-normal-production-2.log`); final Production Simulator build and analysis passed (`kairoid-batch1-final-production-simulator.log`). Neither ordinary build includes the local QA compile condition. Complete concurrency checking remains enabled; iOS 17 deployment compilation is preserved. Existing Swift-6-mode warnings remain; this is not a warning-free Swift 6 claim.
- Founder explicitly approved a local-development-only Production QA harness and the official team's UI-runner development profile. The harness requires a manually supplied compile condition, two explicit launch arguments, Production/Demo=false, and on-device an unexpired development profile for the exact official identity. Distribution profiles and ordinary release builds fail closed. Tests use mocked services, disposable in-memory tokens and separate preferences; no real Keychain/network access, draft deletion or preview-cache clearing.
- Physical certification, final source SHA and Git push remain pending. No TestFlight upload is authorized in this closure.
- First physical attempt ran no tests: iOS rejected upgrading the pre-existing UI-test runner from `XN5Y3V3CSV.com.kairoid.KairoUITests.xctrunner` to `MVT4T97ZGC.com.kairoid.KairoUITests.xctrunner`. The newly approved development profile and local signature are valid; the installed runner's application-identifier differs. Founder approval requested to remove only that obsolete test runner, never the KairoID app or its data. Result: `/private/tmp/kairoid-batch1-physical-qa.xcresult` (installation failure, not a product test result).
- Founder then explicitly approved obsolete-runner removal. Only `com.kairoid.KairoUITests.xctrunner` was removed; KairoID was not uninstalled. The official runner installed and launched on iPhone 11, but timed out enabling UI Automation before any test ran (`kairoid-batch1-physical-qa-official-runner.xcresult`). Awaiting private on-device authorization; no physical PASS claimed.
- The complete unchanged contact-recovery suite subsequently passed 8/8 on the original Simulator (`kairoid-batch1-contact-suite-repeat.xcresult`), in addition to the isolated retries. All 57 relevant cases now have passing evidence on the unchanged product/test snapshot, but the first broad run remains explicitly 56/57 rather than being rewritten as a clean run. No test assertion was removed, weakened or skipped.
- Final public Production health recheck: live/ready 200/200. No authenticated request, OTP, provider call or new audit task used for this check.
- After founder enabled UI Automation, final physical run passed **5/5**, zero failures/skips/runtime warnings, on iPhone 11 / iOS 27.0.1 (`kairoid-batch1-physical-qa-enabled.xcresult`). Screenshots were exported and inspected: real full-screen restoring root in light/dark, synthetic Home/Passport, zero-Career onboarding completion, Resume completion, and unknown-date editor. The same five Production-configured cases also passed on the large Simulator. Actual dark appearance was verified, not inferred from launch arguments.
- Physical QA used the approved local development build, official Team `MVT4T97ZGC`, app identifier `MVT4T97ZGC.com.kairoid.Kairo`, development entitlement `get-task-allow=true`, existing Associated Domains preserved. Runner profile includes the approved iPhone and expires 20 October 2027. No distribution profile or signing identity was changed. The local QA artifact was built from the uncommitted tested tree with developer-unattested provenance; it is not a clean-SHA-attested release or a new TestFlight build. Its local version/build is 1.0 (4); distributed TestFlight remains 1.0 (6).
- Physical testing used mock services and disposable credentials. It proves presentation, transitions and request construction, not live parser/import persistence or genuine credential refresh. Existing-user canonical routing and no-duplicate-write behavior are covered by unit/wire regressions; normal real-session restoration is confirmed separately after fixture removal.
- Normal signed Production artifact (local QA compile condition absent, Production/production, Demo NO) was installed in place and launched without fixture arguments. Founder confirmed normal signed-in Home. No KairoID uninstall, logout, data clearing, real login or provider action was performed. TestFlight remains unchanged.

## Current Batch 1 A–X closure evidence

| Item | Result |
| --- | --- |
| A. Distributed build | TestFlight 1.0 (6), unchanged |
| B. Starting SHA | `57cc9522e76c25bd189fd553c71f4eb250d2d11f` |
| C. Final Batch 1 SHA | The scoped commit containing this report; exact SHA returned after commit, not hard-coded into its own contents |
| D. Branch | `codex/ios-production-bugfix-batch1` |
| E. API43 compatibility | PASS against exact `badb8318c0733a82c11117174c093e4ca25ac77f` contracts |
| F. Resume synthetic E2E | PASS: client wire/state tests, physical mocked review-to-completion, terminal-partial recovery and idempotent retry; no real tester import replay |
| G. Current Education | PASS: valid current/no-end preserved; no iOS date/current-flag compensation |
| H. Contradictory Education | PASS: `current_claim_has_end_date` blocks review before import; explicit correction required |
| I. Existing-user routing | PASS canonical-state regressions; historical tester incident attribution remains unproven |
| J. Duplicate writes | PASS: no Career writes from bootstrap/skip, uncertain retry retains key, confirmed terminal recovery is explicitly gated |
| K. Passport | PASS distinct Internship/Freelance/Gig DTOs, null/optional sections and fail-closed malformed payloads |
| L. Date integrity | PASS null preservation, unrelated-edit stability and explicit supported null clearing |
| M. Zero experience | PASS unit and physical synthetic flow; no blank Employment/Education writes |
| N. Session restore UI | PASS small physical iPhone and large Simulator, light/dark, edge-to-edge root |
| O. Focused tests | 188/188 within the full unit run |
| P. Full unit/integration | 983/983, zero skipped/failed |
| Q. UI | 57 relevant cases have passing evidence; first broad run 56/57 due incomplete synthetic text input, unchanged isolated retries and full contact suite 8/8 PASS; additional Production Simulator QA 5/5 and physical QA 5/5 |
| R. Production build | Signed device build + static analysis PASS; complete concurrency retained, existing Swift 6 warnings documented |
| S. Simulator build | Production build + static analysis PASS, iOS 17 deployment target retained |
| T. Signed physical QA | 5/5 PASS, official development signing, no live provider/account operations |
| U. Privacy/provenance | 87/87, zero skipped/failed |
| V. Git diff | PASS; original checkout's 19 modified files, HEAD, staged diff and index hash preserved |
| W. Local/remote parity | Verify after scoped commit and normal push; no force push or main merge authorized |
| X. Deferred | Dropdown/picker redesign, broad date precision UX, DigiLocker CTA placement, Home/Light Mode redesign, document dropdowns, Education Verification UX, global required/optional labels, evidence hierarchy and used-document filtering; no Batch 2 work started |

The chronological checkpoints below are historical evidence only. Their earlier BLOCKED statuses, counts and unresolved backend attribution do not replace the current API43 closure evidence above.

## Historical API42 investigation (superseded where noted above)

## Verified baseline — 21 October 2026

- ASC latest distributed build **1.0 (6)**, Validated / Testing, KairoID Internal. Older builds remain available. Founder confirmed the onboarding report concerns build 6.
- ASC build ID `b753d7d3-6e25-4d0e-b624-043a22528ad1`, uploaded October 20 at 2:15 PM as displayed by ASC.
- Retained signed archive `KairoID-PhoneRecovery-1.0-6.xcarchive`: clean embedded source **57cc9522e76c25bd189fd553c71f4eb250d2d11f**, Production / production, Demo NO, 1.0 (6).
- Bundle `com.kairoid.Kairo`; official team `MVT4T97ZGC`; application identifier `MVT4T97ZGC.com.kairoid.Kairo`. ASC processed entitlements independently confirm `applinks:api.kairoid.com`, get-task-allow=false and beta-reports-active=true. Apple Distribution: Aletheon Innovations Private limited.
- Exact source uses `https://api.kairoid.com/api/v1`.
- New isolated branch `codex/ios-production-bugfix-batch1` starts at that SHA. Original checkout HEAD `22d8c5988f7cd5ac4b0e9548216249a92bba674d` and 19 dirty files untouched.
- Read-only ECS: API42 and Worker13 each desired/running/pending **1/1/0**. API digest `sha256:4adb25f13a1522f6bd2d04affc1d003201d85d8d4aadb3599298b40628c9ee91`; APP_VERSION `git-ee9220e7367d`.
- Backend contracts read with `git show ee9220e7367d994c9d4e1597f1ae00c14355f859:...`, not from the current backend working tree. Live/ready **200/200**. DB093 is supplied context, not independently queried here.

## Compatibility and root-cause matrix

| Flow | Build 6 iOS vs exact API42 | Finding / action |
| --- | --- | --- |
| Existing-user boot | session → users/me → onboarding/status; complete checked before local drafts | Canonical state already wins. Tester-specific failure not attributed; no speculative bypass. |
| Contact recovery | authenticated mobile path, distinct from signup-session path | Preserve build 5/6 and Google behavior. Missing-email recovery retains support path. |
| Resume edit | Certification editor sends issue_date; strict API42 accepts issued_date | Proven invalid_review_item rejection path; corrected key. Profile editor also offered forbidden email/headline/string location; replaced with supported fields. |
| Resume dates | changed/cleared dates retained old display/precision aliases | API normalization can restore old dates. Clear aliases on an actual date edit; preserve exact values on unrelated edits. |
| Resume import | validate increments version; iOS applies returned version before confirmed idempotent import | Version propagation is correct. Account audit proves HTTP201 partial completion: 13/14 claims imported, one Education failed. Underlying backend exception was not logged. |
| Partial-import recovery | Retry only reconciles the same immutable failed batch; old key survives changed decisions | Return to affected-item review; rotate key only after a newer saved reviewing version of a known terminal partial batch. Uncertain/nonterminal retries retain the original key. |
| Passport | Internship/Freelance/Gig decoded as Employment | API42 supplies distinct fields, not job_title/verification_method/documents. Separate strict DTOs added. Valid nonempty sections otherwise fail the whole decoder. |
| Career dates | unknown dates replaced with Date(); nil PATCH omitted | Presence flags preserve unknowns; explicit date null removes fields under API42 exclude_unset semantics. |
| Manual onboarding | blank Employment/Education auto-inserted; nonempty collections required | Explicit skip discards unsaved drafts, retains persisted entries, emits no blank records. API42 completion requires neither collection. |
| Session loading | root VStack hugs card content | Infinite root frame, edge-to-edge background, safe-area content preserved. |

## Source changes

- Passport retains strict required identifiers/status; no broad try? decoding.
- Employment start/end, Education start/end/precision, Certification issued/expiry edit presence and null-update semantics corrected. Create-contract required dates unchanged.
- Project already had presence flags; explicit-null PATCH added. Portfolio has no dates. Separate legacy Internship/Freelance/Gig records have no iOS editor; Employment-type variants use the shared Employment editor.
- Manual skip is explicit; persisted rows are never recreated by the mapper. Empty restored collections remain empty.
- Founder separately approved two Xcode 27.1 build corrections: instantiate default DigiLocker browser and Permanent Address collector inside their actor-isolated initializers. No OAuth/GPS triggered.

## Approved read-only Production audit

- Exactly one non-service API42 task: `c01a16804bf34378a946b4b9697501bd`. No task-definition/service/IAM changes, no application service methods, no provider calls.
- PostgreSQL `default_transaction_read_only=on` plus an explicit read-only transaction; `SHOW transaction_read_only` confirmed `on` before and after UUID-scoped SELECTs. Lookup email and credentials were not logged or returned.
- One active Candidate; email and phone currently verified; minimum profile and explicit onboarding completion currently true. Canonical computed state is **complete**.
- Stored timestamps (UTC): account creation August 3; phone verification October 20 09:31:07; explicit onboarding completion October 20 10:32:43. Current state does not reconstruct prior canonical responses or prove when a previously verified flag might have changed.
- Resume: one processing job `needs_review`, no parser failure. Review `partially_imported`; one batch `partially_completed`, 14 selected, 13 imported, one failed Education item with sanitized code `item_import_failed`.
- Imported results: Employment 1, Education 3, Certification 4, Project 4, Internship 1. A live Internship is present, matching the independently reproduced Passport DTO mismatch.
- Career creation timestamps show imported records at 10:20:14 and additional Employment/Education rows at 10:32:44–45. No record contents inspected; this is not proof that those later rows are semantic duplicates.
- Bounded log correlation, October 20 **10:20:13–10:20:19 UTC**: one matching failure event, same request start/failure/partial-completion, **POST /api/v1/resume-reviews/{review_id}/import → HTTP201**. No underlying exception logged. Source catches all item exceptions and records only the generic sanitized code.
- Task naturally **STOPPED / exit 0**. ECS attachment **DELETED**; EC2 confirms its ENI no longer exists. API42 and Worker13 remain **1/1/0**; live/ready **200/200**.
- No Product/DB/session/account mutation. Only the expressly approved temporary audit task was launched; no second task.

## Evidence limitations

- Account metadata was read only under separate approval; no account modified. Exact pre-incident canonical status is unavailable. Local-flag-driven rerouting is not proven; no speculative onboarding bypass was added.
- No new real resume upload/import. Certification save mismatch is proven by API42 schema comparison; its precise earlier tester PATCH response is not retained here. The import-stage HTTP201/partial failure is proven; the underlying Education exception is not recoverable from the generic stored/logged code alone.
- Passport fixtures derive from exact API42 schemas; the scoped audit confirms the triggering nonempty Internship section, but no private Passport response body was captured.
- No new physical Production certification claimed. No commit, push or upload yet.

## Validation

- Baseline initially blocked by pre-existing DigiLocker actor-default-argument compile failure, then the equivalent Permanent Address failure. Both narrow corrections explicitly approved.
- First focused run: **81 PASS, 0 failed/skipped**, iPhone 18 Pro / iOS27 Simulator.
- Expanded full unit/integration: **974 PASS, 0 failed/skipped**, confirmed again in `/private/tmp/kairoid-batch1-unit-confirmation.xcresult` after tightening the exact-schema fixture assertion.
- Production-configured, fully mocked real Resume service: Certification edit PATCH → review GET → validation POST → confirmed import POST passes; no live request. This verifies wire sequencing, not a live upload/parser/import/Career end-to-end result.
- Production-configured real root: delayed session restoration fills 414×896 and 430×932 proposed viewports in light/dark; no network/Keychain use.
- Production device unsigned compilation with complete concurrency checking: PASS, `/private/tmp/kairoid-batch1-production-device-final.log`.
- Production Simulator compilation and static analysis: PASS, `/private/tmp/kairoid-batch1-production-sim.log`.
- Compiler warnings remain in pre-existing DigiLocker fixture isolation and Guided Tour Shape conformance. New date encoder isolation warnings corrected; no concurrency setting weakened. Do not describe this as warning-free Swift 6 certification.
- Privacy/provenance/icon checks: **82 PASS, 1 skipped, 0 failed** (83 discovered); `/private/tmp/kairoid-batch1-final-privacy.log`.
- Relevant UI: **24/24 PASS**, including contact recovery 8, Google handoff 7, manual/resume/Passport/password login 7, Certification metadata/date 2. `/private/tmp/kairoid-batch1-final-regression.xcresult` contains the earlier 972-unit run plus these 24 UI checks (996 total). All use blocked/mock transport, no real OTP or Google flow.
- After the audit proved the terminal-partial retry trap, final regression: **976 unit/integration + 3 affected Resume UI = 979 PASS, 0 failed/skipped**, `/private/tmp/kairoid-batch1-partial-recovery.xcresult`. Earlier 24/24 UI checks also passed; the affected three were repeated after the last correction.
- Final Production device build, Production Simulator build and static analysis all **PASS** after recovery changes: `kairoid-batch1-production-device-recovery.log` / `kairoid-batch1-production-sim-recovery.log` in `/private/tmp`. Complete concurrency checking remains enabled; pre-existing warnings noted above remain.
- `git diff --check`: PASS. Physical/signed Production certification remains pending. No physical app installation or account action performed.

## Deferred scope

Employment/degree/education-level dropdowns, city/country pickers, broad date-picker/precision redesign, DigiLocker CTA placement, Home redesign, document dropdowns, Education Verification UX, global required/optional labels, Light Mode redesign, evidence hierarchy and already-used-document filtering remain unchanged.

## Release recommendation

**BLOCKED** until the remaining attribution and validation gates close. No TestFlight upload without fresh founder approval after certification. Backend, Android, Production configuration and original checkout unchanged.

## A–AE checkpoint report

| Item | Result |
| --- | --- |
| A. Distributed version/build | 1.0 (6), independently verified in ASC |
| B. Distributed provenance | `57cc9522e76c25bd189fd553c71f4eb250d2d11f` |
| C. Starting source | Same SHA |
| D. Final source SHA | Not created; scoped fixes remain uncommitted pending certification |
| E. Branch | `codex/ios-production-bugfix-batch1` |
| F. Existing-user root cause | Historical canonical response unavailable; local-marker override not found. Current account is complete. Partial import preceded subsequent manual completion. |
| G. Existing-user fix | No speculative routing change; canonical-state regression and explicit zero-Career skip added |
| H. Duplicate protection | Bootstrap emits no Career writes; skip retains persisted records; uncertain import retries preserve idempotency; backend provenance links previously imported items |
| I–J. Resume root cause/stage | Strict edit-field mismatch; actual import HTTP201 partial result with one Education exception; terminal-partial retry loop in iOS |
| K. Resume fix | Correct field keys, date aliases, visible editor errors, affected-item guidance, review recovery and carefully gated new import key |
| L. Synthetic Resume E2E | Wire/state/recovery checks pass; no live parser/import/Career E2E claimed |
| M. Passport root cause | Nonempty Internship decoded as Employment; audit confirms Internship exists |
| N. Passport fix | Exact distinct API42 DTOs; required fields remain strict |
| O. Production-shaped decode | PASS, synthetic API42 fixture; no private response body capture |
| P–R. Dates | `Date()` fallback plus omitted null PATCH; presence flags and explicit date-null encoders corrected for Employment, Education, Certification, Project. Other legacy types have no iOS editor; Portfolio has no dates. |
| S. Null-date regressions | PASS |
| T–U. Manual onboarding | Blank required collections forced fabricated entries; explicit Employment/Education skips pass without blank writes |
| V. Loading screen | Content-hugging root; infinite root frame fixes proposed small/large viewports, light/dark, with Production-configured mocks |
| W. Focused tests | First focused run 81/81; subsequent added regressions included in full suite |
| X. Full tests | 976 unit/integration PASS after partial recovery correction |
| Y. UI | 24/24 PASS; three affected Resume UI checks repeated after last recovery correction, all PASS |
| Z. Production builds | Final device + Simulator + static analysis PASS; existing warning caveat above |
| AA. Physical/signed QA | Not certified; no device app replaced or real account/provider flow performed |
| AB. Privacy/provenance | 82 PASS, one expected skip; 0 failures |
| AC. Git parity | Not applicable: no commit/push; isolated worktree intentionally contains scoped changes |
| AD. Remaining issues | Underlying Education exception; historical onboarding-state attribution; full signed/controlled Production certification; explicitly deferred non-Batch1 tester issues |
| AE. Recommendation | **BLOCKED** |

Next evidence step requires separate approval: one additional read-only, failed-Education-item-only schema/constraint validation, returning only validation field names/categories—not payload values—and no import replay. The single currently authorized task is already consumed and stopped. No backend edit is proposed as proven until that cause is established.
