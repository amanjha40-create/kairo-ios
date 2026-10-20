# Production Bug War Room — Batch 2

## Pre-implementation contract inventory

Recorded before any UI/source edits. Isolated branch `codex/ios-production-bugfix-batch2`, exact base `acbe63ed508a17159014e17352e2c203f3b9cb69`. TestFlight remains 1.0 (6). Backend source inspected read-only: API43 `badb8318c0733a82c11117174c093e4ca25ac77f`; no live account query or mutation.

Sources: `app/schemas/employment/requests.py`, `app/employment/enums.py`, `app/employment/validation.py`, `app/schemas/education.py`, `app/education/enums.py`, `app/services/education_service.py`, `app/schemas/certification.py`, `app/schemas/project.py`, `app/schemas/internship.py`, `app/schemas/freelance_contract.py`, `app/schemas/user.py` at that exact commit. PATCH requirements mean “if changed/supplied”; omitted fields preserve persisted values. Required-on-create must not force filling absent legacy fields on unrelated edits.

| Field | Current iOS control | Backend type / enum | Nullable | Required create / edit | Proposed control | Wire |
|---|---|---|---|---|---|---|
| Employment company/legal name | Text | string 2–512 | No create; PATCH optional | Yes / nonempty if changed | Text, inline limits | employer_legal_name |
| Employment trade name | Text | string ≤512 | Yes | No / No | Optional text | employer_trade_name |
| Employment title | Text | string 1–255 | No create; PATCH optional | Yes / nonempty if changed | Required text | job_title |
| Employment type | Career menu; manual text | full_time, part_time, contract, intern, gig, freelance, other | PATCH accepts null/omission; create default full_time | Default / No | Exact existing enum picker; unknown legacy shown, omitted until explicitly replaced | employment_type |
| Employment country | Career ISO search; manual text | 2-letter uppercase ISO-shaped string | Yes | No / No | Existing native ISO search; unknown retained, never auto-normalized | work_location_country |
| Employment city/region | Career searchable/freeform; manual no city | free strings ≤128 | Yes | No / No | Reuse existing freeform/search, no city provider or tiny list | work_location_city / work_location_region |
| Employment arrangement | Career menu | onsite, hybrid, remote | Yes | No / No | Preserve existing menu; unknown omitted on unrelated edit | work_arrangement |
| Employment start | Compact date; manual day/month/year text | date | No create; PATCH nullable | Yes / No | One confirmed date field; absent edit stays absent | start_date YYYY-MM-DD |
| Employment end | Compact date; manual day/month/year text | date | Yes | No / No | Optional confirmed date; explicit removal only | end_date YYYY-MM-DD or null |
| Employment current | Toggle | No current boolean in employment request; represented by absent end | N/A | No / No | Warn/require explicit end removal before current transition | end_date null |
| Education institution | Text | string 1–512 | No create; PATCH optional | Yes / nonempty if changed | Text with requirement label | institution_name |
| Education degree | Text | string 1–255; NO canonical degree enum/catalogue found | No create; PATCH optional | Yes / nonempty if changed | Searchable freeform selector; existing/uncommon degree retained; no invented finite list | degree exact user selection |
| Education level | Career menu; manual text | high_school, diploma, bachelors, masters, doctorate, certification, other | PATCH optional | Yes / No | Exact canonical picker separate from degree; unknown retained/omitted unless changed | education_level |
| Education field of study | Text, manual erroneously requires | string ≤255 | Yes | No / No | Optional text | field_of_study |
| Education grade | Text | string ≤64 | Yes | No / No | Optional text | grade |
| Education city/country | No control | NOT supported by create/update schemas | N/A | N/A | Do not add unsupported fields | None |
| Education start | Compact date; manual year text | date + day/month/year precision | No create; PATCH nullable | Yes / No | Confirmed date/period field | start_date + start_date_precision |
| Education end | Compact date; manual required year | date + day/month/year precision | Yes | No / No | Optional date/period field | end_date + end_date_precision |
| Education current | Career toggle; manual inferred false | boolean default false | PATCH optional | No / No | Current toggle; conflicting end visible and actionable, no silent clearing | is_currently_studying |
| Education precision | Separate menu not reflected by date picker | day, month, year; nullable | Yes | No / No | Exact date / Month & year / Year only; display updates immediately without rewriting untouched dates | Existing YYYY-MM-DD anchor + exact precision value |
| Certification title/issuer | Text | strings 1–512 | No create; PATCH optional | Yes / nonempty if changed | Required text on create | title / issuing_organization |
| Certification issued date | Compact date | date (upload-intent separate path accepts null) | No metadata-create; PATCH nullable | Yes metadata-create / No edit | Confirmed date; missing legacy edit remains missing | issued_date |
| Certification expiry | Compact date + toggle | date | Yes | No / No | Optional confirmed date | expiry_date |
| Certification never expires | Toggle | boolean | No create; PATCH optional | Default false / No | Explicit conflict resolution, no silent data loss | does_not_expire |
| Certification credential ID/URL | Text | string / validated HTTP(S) URL | Yes | No / No | Optional text, retain safe validation | credential_id / credential_url |
| Project title | Text | string 1–255 | No create; PATCH optional | Yes / nonempty if changed | Requirement label | title |
| Project role/organization/description/URLs | Text | strings ≤255/255/5000, HTTP URLs | Yes | No / No | Optional labels, unchanged URL validation | Existing keys |
| Project dates/current | Date toggles | nullable dates, is_ongoing false default | Yes | No / No | Shared confirmed date field; actionable ongoing/end conflict | start_date/end_date/is_ongoing |
| Internship dates/location | No native editor in current app | start required create, end nullable; is_ongoing; no location fields | PATCH nullable | Start yes / No | Audit only; no new editor/capability | Existing API date keys |
| Freelance dates/location | No native editor in current app | start required create, end nullable; is_ongoing; no location fields | PATCH nullable | Start yes / No | Audit only; no new editor/capability | Existing API date keys |
| Manual basic profile city/country | Text | user PATCH optional city≤128 / country2 | Yes | No at schema level; canonical onboarding completion separate | Existing country search and freeform city; retain canonical onboarding flow, distinguish completion requirements | location_city / location_country |

## Directly related findings / planned safeguards

- Career enum initializers currently fall back to Full-time/Other/On-site; unrelated saves must omit unknown legacy values instead of replacing them.
- Education encoding currently re-anchors dates to selected precision on every save; retain original date/precision wire values until the user changes that field.
- Date toggles can include today without selecting a date. Replace this with nullable confirmed selection, while retaining compatible draft storage and explicit include flags.
- Current/never-expires toggles currently hide and discard contradictory end dates in the outgoing payload. Show an inline actionable conflict; only explicit Remove clears it.
- Manual required end year, field of study and work country exceed API43 requirements; optional empty values must be accepted while populated invalid values remain errors.
- Existing local ISO country catalogue/search and freeform city component are reused. No external service added. No authoritative degree catalogue exists; freeform degree search is intentional, not a fabricated enum.

## Implementation

- Employment type and Education level use the exact existing API43 enums, including current-value accessibility and legacy-value display. Degree is separate and searchable/free-form; no invented degree catalogue.
- Country uses the existing local ISO catalogue; city supports unlisted free-form values. Unchanged legacy values are omitted from PATCH; deliberate country/city/region clearing is encoded as null, not confused with preservation.
- `CandidateDateField` owns a private modal draft and commits only on **Use date**. Cancel/open do not mutate the bound value. Optional dates have an explicit Remove action; incomplete saved manual dates remain recognizable/removable rather than silently normalized.
- Education precision displays Exact date / Month & year / Year only immediately. Unchanged legacy date anchors and nullable precision remain byte-equivalent on the wire. Ordering validation compares the dates actually sent, including precision anchors, not hidden time-of-day.
- Current Employment/Education, never-expiring Certification and ongoing Project conflicts remain visible. Saving requires explicit end-date removal or reversing the status; no silent clearing.
- Create-required labels and edit/optional labels follow the matrix. Manual field-of-study, end dates and country are no longer over-required. Manual dates accept backend-valid calendar years rather than an unsupported 1950/current-year cutoff.
- Known server validation is rendered beside affected fields. Editing a Career draft clears stale server feedback so a corrected field is not permanently blocked. Basic-profile first-invalid focus/scroll remains in place; date/picker sheets dismiss their keyboards natively.
- Physical tests reuse the existing opt-in, development-profile-only local QA gate. `LocalBatch2FormQA` has synthetic values and local save callbacks only; no account, network, Keychain, provider or GPS access. Ordinary builds retain a permanently disabled entry gate.

## Validation / source-control gate

Expanded unit suite: 1,007/1,007 PASS, including 23 new Batch2 contract tests and a new optional-field mapper test. Privacy/provenance: 91/91 PASS, no skips. Existing affected UI: 19/19 PASS (11 Career hierarchy, 6 manual/navigation, 2 Certification). New synthetic Production UI: 8/8 PASS. Signed physical iPhone 11, iOS 27.0.1: 8/8 PASS, zero skips/failures/runtime warnings in the final result. Production device and Simulator builds/static analysis PASS with strict concurrency enabled. Existing Swift 6 isolation warnings remain in unrelated code under the repository's Swift 5 language mode; no concurrency setting was weakened.

Validation findings were not hidden: the initial Production UI build needed a command-line-only ENABLE_TESTABILITY override; three initial UI failures used ambiguous Cancel selectors and were corrected with sheet-specific identifiers. One overlapping Simulator run was interrupted by Simulator shutdown and is not counted as a pass. The first physical run passed 4/8 cases and exposed a real date-control hit-area defect: an enabled, fully visible date field did not open when its transparent middle was tapped. The shared date label now has an explicit rectangular content shape, and regression taps the center deliberately. All eight physical cases passed after correction, including the four formerly failing date-opening cases. The manual required/optional VoiceOver labels were also corrected within this scope.

Final evidence (local, synthetic screenshots only):

| Gate | Result bundle / log |
|---|---|
| Full units + exact Certification regressions | `/private/tmp/kairoid-batch2-final-certification.xcresult` — 1,007 unit + 2 UI PASS |
| Career/manual affected UI | `/private/tmp/kairoid-batch2-final-source.xcresult` — 17 UI PASS; two misnamed selectors selected zero cases and were rerun by their exact names above |
| New forms UI | `/private/tmp/kairoid-batch2-form-ui-r4.xcresult` — 8 PASS |
| Signed physical forms | `/private/tmp/kairoid-batch2-physical-qa-r2.xcresult` — 8 PASS |
| Physical visual evidence | `/private/tmp/kairoid-batch2-physical-certified-attachments/` |
| Ordinary Production device build / analysis | `/private/tmp/kairoid-batch2-production-device-final.log` — PASS |
| Ordinary Production Simulator build / analysis | `/private/tmp/kairoid-batch2-production-sim-hitarea.log` — PASS |
| Privacy/provenance | `/private/tmp/kairoid-batch2-privacy-certified.log` — 91 PASS |

Physical coverage: Employment type/legacy selection, Education level, uncommon degree, ISO country search, unlisted city, exact-date confirm/cancel/remove, immediate month/year/year-only display, current Education and Employment explicit conflict resolution, required/optional labels and accessibility values, search keyboard/sheet dismissal, light/dark Accessibility XXXL and reachable Save/Cancel. Captured synthetic screenshots reviewed. No live record was saved; no login, upload, provider or GPS action occurred. The test-only QA banner is intentionally present in screenshots and absent on ordinary launch. VoiceOver labels/selected-state semantics were checked through accessibility automation; this is not a claim of a separate human spoken-VoiceOver walkthrough.

All implementation and certification gates passed before commit. Commit/push are limited to this branch; final immutable SHA and remote equality/0–0 are verified and reported in the delivery response. No TestFlight upload, main merge, backend/Android change, Production configuration change or tester-record mutation is part of this batch.

Deferred unchanged: DigiLocker CTA redesign, document-evidence redesign, Education Verification redesign, Home redesign and Light Mode redesign (Batch3/4). No new Internship/Freelance editor or external location service was added.

Original checkout preservation verified: HEAD `22d8c5988f7cd5ac4b0e9548216249a92bba674d`; 19 modified files; original index SHA256 `c0b77eda8113698294dd433cdd2836717495cfd9a880185591f96a89c16e8497`; unstaged binary-diff SHA256 `90efbc36419a4aa56383862d784feb77c5402958e7007f55f53f2bee3d30bba8`; staged diff empty. No original checkout edits, stash, clean, reset or reconciliation.

Batch 2 implementation and physical certification: PASS. Source-control delivery is verified separately after the scoped commit.
