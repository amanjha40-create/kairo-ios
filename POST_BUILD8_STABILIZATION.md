# Post-Build-8 stabilization — implementation checkpoint

## Physical closure — 22 October 2026 (current disposition)

This section supersedes the historical pending/blocked physical status below.
The founder authorized only test-harness additions during this closure: isolated
persistent synthetic records, long Passport identity values, and the existing
development-only gate for physical Passport/Career tests. **No product defect was
reproduced and no further normal product behavior was changed in this pass.**

Physical device: **iPhone 11, iOS 27.0.1**, 414-point portrait width. The actual
development signature has `get-task-allow=true`, team MVT4T97ZGC, application ID
MVT4T97ZGC.com.kairoid.Kairo, and the existing Associated Domain entitlement.
The isolated build blocks network and uses in-memory credentials, not Keychain.

### Remaining physical gates

| Gate | Result |
|---|---|
| Native Passport Identity, long email/mobile, normal and XXXL | PASS; full-width wrapping, complete accessibility strings, horizontal bounds and captured screenshots inspected |
| Employer Trade Name clear → save → refetch → terminate/relaunch | PASS — isolated persistent synthetic store |
| Certification Credential ID, same sequence | PASS — isolated persistent synthetic store |
| Education Field of Study, same sequence | PASS — isolated persistent synthetic store |
| Project Role, same sequence | PASS — isolated persistent synthetic store |
| Degree selector, existing custom value, known degree → Other | PASS |
| Country → State/Province → City; parent change resets child; no free City | PASS |
| Employment evidence: no default, filtered Primary/Supporting, role change resets type | PASS; Other/Government ID excluded from Primary/new unsupported choices |
| Employment Details expanded by default; collapse/reopen/navigation retained | PASS |
| Passport Purpose neutral placeholder, empty initial value and validation | PASS |
| Shared date/location/degree controls, light/dark XXXL reachability | PASS |

Persistence evidence uses real editor drafts and `APIJSONCoder.makeEncoder()`.
It asserts explicit JSON null, refetches a UUID-scoped disposable local canonical
store, terminates the process and reconstructs a fresh editor from disk. It is
**not live backend/database persistence certification**. No real records were
created, changed or cleared. The prior deployed-null contract review remains the
separate backend evidence; Vault is expressly excluded.

Final physical results: **13/13 PASS, 0 failures, 0 skips**, finalized normally:

- `/private/tmp/kairoid-postbuild8-physical-persistence-probe-3.xcresult`: 1/1.
- `/private/tmp/kairoid-postbuild8-physical-gates.xcresult`: 12/12.
- Synthetic screenshots: `/private/tmp/kairoid-postbuild8-physical-evidence/` and
  `/private/tmp/kairoid-postbuild8-persistence-pass-evidence/`.

Earlier attempts are not counted as passes: the first timed out enabling UI
Automation before tests; the second exposed a new **harness-only** mistake using
the default JSON encoder rather than the real snake-case API encoder. Correcting
that fixture produced the passing probe above. No assertions were weakened.

Privacy/provenance/integrity rerun: **155/155 PASS**, no skips,
`/private/tmp/kairoid-postbuild8-physical-privacy-final.log`. A sandboxed attempt
could not run two Swift compiler checks; the compiler-access rerun passed. Full
unit evidence remains the previously completed **1046/1046 PASS** for the product
implementation; it was not relabelled as a fresh full-suite run in this closure.
Normal optimized Production device build: PASS,
`/private/tmp/kairoid-postbuild8-normal-device-final.log`. The normal build was
installed in place and launched without fixture arguments; the founder confirmed
“Home visible.” Background/reopen was requested but was not separately described
in that reply; no stronger manual-session claim is made. Temporary sleep prevention
was stopped after tests.
This local development build uses the repository's unchanged Production metadata,
version 1.0 (4); it is not the distributed TestFlight Build 8 artifact and no release
version setting was edited. Build 9 has not been created.

### Dependencies explicitly OPEN

1. Backend DigiLocker completion/return-page simplification.
2. PAN provider/backend failure investigation; separate Driving Licence failure
   remains unproven. No real provider retry was made.
3. Vault `document_number` / `expires_at` explicit-null clearing support.
4. Backend enforcement of allowed Employment Primary document types, including
   safe treatment of legacy replacement/classification contracts.

The pinned ODbL derived-data/source distribution offer also remains a packaging
prerequisite. No backend, provider, Android, Production configuration, real account
data, signing settings or original dirty checkout was changed. No Build 9 version
bump, archive, IPA export or TestFlight upload was performed. This is scoped
stabilization evidence, not full Build 9 release certification.

The requested iOS physical and approved isolated-persistence gates are green.
One scoped stabilization commit and normal branch push are authorized by the
founder's conditional instruction. No main merge or release packaging is authorized.
Final source identity and remote parity are reported in the chat after Git verification.

Staged whitespace audit: all files other than the verbatim upstream ODbL licence
pass `git diff --cached --check`. That licence retains upstream trailing spaces;
its SHA-256 is exactly
`6042621cae96bbce3a10739b480a074e25b0ea23025c00d7874582ad2c47b780`, matching the
pinned downloaded source. This is a disclosed third-party text exception, not
a clean full-diff whitespace result. No whitespace configuration was weakened.

**READY_FOR_BUILD_9_CERTIFICATION** — begin the next certification lane only;
the explicitly open dependencies above are not waived or functionally closed.

## Historical implementation checkpoint (before physical closure)

Baseline: `af3c6a3f5115b612da0dcd0bba34776d9cfd71c9`, version 1.0 (8).
Branch: `codex/ios-post-build8-stabilization`. Changes are uncommitted.
This is not Build 9 certification or permission to package/upload.

## Issue map

| # | Finding / owner | Implemented scope and evidence | Remaining gate |
|---|---|---|---|
| 1 | Backend completion HTML presents Android and iPhone actions together; AASA authorizes Google only | Read-only contract audit; no backend change | BACKEND_BLOCKED: one platform-appropriate fallback and safe automatic return need backend implementation/certification |
| 2 | Verify and connection errors shared one iOS error slot; historical PAN retrieval failed upstream | Separate `verificationErrorMessage` rendered under Verify; unit regression preserves saved results through failure/refresh | UI/physical placement validation; functional PAN remains PROVIDER_BLOCKED, independent DL failure not proven |
| 3 | Purpose prompt used a specific example | Instructional placeholder, no prefill; unchanged 1–120 validation | Small/large and physical verification |
| 4 | Native Identity row divided available width between label/value | Vertical label/value, full-width wrapping, combined accessibility element | Long-value/XXXL and physical verification; no public web changes |
| 5 | Shared headings were inside controls | External Date/Place/Degree captions, value inside, native accessibility labels retained | Shared-consumer regression and physical verification |
| 6 | Degree choices were empty/current-only with free entry | Versioned common local list; Other opens separate field; unknown saved strings preserved | Save/reopen/physical certification |
| 7 | No worldwide dependent city dataset | Approved pinned offline ODbL snapshot, controlled dependent selectors, explicit gaps, legacy preservation | Physical checks and accessible derived-data/source offer before distribution |
| 8 | Other default and unfiltered role lists; server counts role but not allowed type | None initially, exact approved role policy, reset on role change; legacy data not silently reassigned | BACKEND_BLOCKED for authoritative allowed-type eligibility; UI/physical checks |
| 9 | Employment Details initialized collapsed | Expanded initially; explicit collapse/reopen retained | UI/physical verification |
| 10 | Nil metadata conflated omission and clearing | Shared unchanged/set/clear encoder for affected PATCH fields; existing six date encoders unchanged | Full A–F matrix and physical checks; Vault clear remains BACKEND_BLOCKED |

## Backend evidence boundary

Read-only deployed API44 source/image comparison confirmed null-preserving
`exclude_unset` updates for the affected Career/Profile/link metadata. Vault's
`document_number` and `expires_at` explicitly ignore null; no iOS empty-string
workaround was added. Employment readiness does not enforce the new allowed-type
policy. Those fixes belong to the backend lane.

The only correlated provider sequence found was approximately 22 October 2026,
10:44:16 IST: issued listing 200 → PAN XML retrieval provider 400 → identity verify
backend 503. It was not independently attributed to the tester. The provider's
exact rejection reason and a separate Driving Licence failure remain unproven.
No verification retry, provider call, account query or mutation was performed.

## Optional-field inventory

52 field slots in current iOS mutation contracts; this is a static inventory,
not 52 successful persistence/relaunch checks. Required fields are not made nullable.

| Entity | Count | Slots / treatment |
|---|---:|---|
| Profile | 11 | phone, current_role, industry, years_of_experience, location, location_city, location_region, location_country, headline, bio, date_of_birth: changed-field encoding |
| Professional link | 1 | label: unchanged omitted, clear null |
| Employment | 8 | employer_trade_name: corrected; start_date/end_date and three location fields retain explicit-null handling; employment_type/work_arrangement preserve existing selection policy |
| Education | 7 | field_of_study/grade: corrected; start/end date and precision retain null behavior; education_level policy unchanged |
| Certification | 4 | credential_id/credential_url: corrected; issued_date/expiry_date unchanged; attachment independent |
| Project | 7 | role/description/project_url/repository_url/organization_name: corrected; start/end date unchanged |
| Portfolio | 3 | description/url already explicit null; tags clear as [] |
| Permanent Address | 2 | address_line_2/locality use full replacement, not exclude-unset PATCH |
| Vault | 2 | document_number/expires_at backend-blocked; no fake blank workaround |
| Verification contact | 3 | contact_name/contact_role/candidate_note use full replacement/versioning |
| Manager nomination | 2 | work_email/phone use full replacement/versioning |
| Passport share | 2 | label/expires_at already use explicit change flags; validation unchanged |

Additional backend-only legacy slots: Internship (description, start_date,
end_date, stipend_amount, stipend_currency); Freelance (description, start_date,
end_date); Gig (started_at, ended_at, partner_id, rating). No dedicated native
edit routes were found; the Employment variants use the contract above.

Legacy More Profile uses the same field-change encoding. Manual onboarding
location comparisons preserve unchanged prefilled legacy strings rather than
rewriting fallback/display values. Resume review already encodes deliberate
nulls and is not blanket-rewritten.

## Evidence policy

Primary: relieving_letter, employment_contract, offer_letter, payslip, pay_stub,
appointment_letter, experience_letter, contract, hr_letter.

Supporting: bank_statement, form_w2, form_1099, employment_id_card, other.

government_id is unavailable for new Employment uploads. Unknown types are not
assigned a role. Existing items remain visible/viewable/removable. Replacement
of unclassified or now-disallowed legacy evidence cannot silently invent a role:
the current upload contract requires one. The app explains that limitation;
explicit classification is offered only for policy-compatible types. Server
eligibility remains authoritative and needs its separate backend correction.

## Geography distribution

Snapshot `7795d77d6a801543b9bb90d97a182c885f44c458`, 250 countries,
149,049 city names within administrative divisions, about 2.8 MB bundled.
97 countries have at least one recorded gap; this is not exhaustive worldwide
coverage. See `Kairo/Resources/Geography/README.md`, licence and manifest.
BuildTools/import_geography.py verifies exact source/licence hashes before import.
New city entry is controlled; existing custom values are not erased on open/cancel.

## Automated evidence so far

- Focused unit suite: **130/130 PASS**, completed
  `/private/tmp/kairoid-postbuild8-unit-2.xcresult`.
- Full unit suite after the shared helper's explicit nonisolated annotations:
  **1,046/1,046 PASS**, completed `/private/tmp/kairoid-postbuild8-full-unit.xcresult`.
- Privacy/provenance plus pinned dataset integrity: **154/154 PASS**, zero skips,
  `/private/tmp/kairoid-postbuild8-privacy-2.log`.
- Staging Simulator build-for-testing: PASS, followed by a successful incremental
  build in the unit rerun.
- Profile/link mocked PATCH → canonical refetch → new service instance preserves
  cleared values. Career tests cover wire states and canonical-null new drafts;
  this is not claimed as full app-process relaunch evidence for every field.
- First unit attempt had four obsolete assertions in one Profile test; corrected
  to require untouched fields omitted. Xcode stalled in post-test Simulator
  diagnostics; that run was stopped and is not certification evidence.
- One old privacy assertion required free-form City. Replaced with approved
  controlled-selector/no-free-entry assertions, retaining offline/privacy checks.
- Staging UI pass: Employment Details expansion/collapse, Verify-specific error,
  Purpose placeholder (SE), dark/XXXL Purpose and background restoration (large).
  The remaining 11 initial UI cases were mistakenly launched against Staging;
  the Production-only local harness correctly rejected fixture activation. Those
  are configuration-invalid runs, not product passes or evidence of product failure.
- First Production QA build used normal release testability and could not import
  the app into its unit-test module. Corrected local command-line test overrides
  enable testability/debug optimization for the isolated harness; project release
  settings and signing are not altered.

Physical validation, full release regression/build matrix and packaging have
not been completed. No commit, push, backend/AWS/Production mutation or TestFlight
upload. Original dirty checkout is outside this isolated worktree and preserved.

## Final targeted UI evidence

Latest passing result for each selected case: **SE 9/9; Large 6/6** (15 distinct
device/test cases). This is a targeted selection, not exhaustive UI certification.

- SE Staging cases: Career Details, Verify error ownership, Purpose hierarchy
  passed in `kairoid-postbuild8-ui-se-1.xcresult` (the overall bundle was red due
  to the separately documented invalid harness configuration).
- Large Staging dark/XXXL Passport Purpose/background case passed in
  `kairoid-postbuild8-ui-large-1.xcresult` (same configuration caveat).
- SE evidence role/type/upload retry cases passed in
  `kairoid-postbuild8-ui-se-2.xcresult`.
- Large evidence role and light/dark/XXXL review cases passed in
  `kairoid-postbuild8-ui-large-2.xcresult`.
- Fresh SE City/Degree/Date rerun: **3/3 PASS**, completed
  `/private/tmp/kairoid-postbuild8-ui-se-4.xcresult`.
- Fresh Large City/Degree/light-dark accessibility rerun: **3/3 PASS**, completed
  `/private/tmp/kairoid-postbuild8-ui-large-4.xcresult`.

The real picker hierarchy showed `Choose city` NavigationBar → `Search city`
SearchField → native `Close` Button during active search. Tests now close that
specific search before cancelling the sheet. The Other-degree test explicitly
uses keyboard Done. Captured SE state and alternating scroll trace showed the
old full-screen swipe helper overshooting; bounded gestures within the form now
reach fields without changing assertions, adding sleeps, skips or wider timeouts.
Those corrections are test-only. Normal product behaviour was not altered to
make the tests pass.

All result paths above are under `/private/tmp/`. Final privacy rerun:
`kairoid-postbuild8-privacy-final.log`, **154/154 PASS**, no skips. Final diff check
passes. The original checkout's binary diff SHA-256 remains
`90efbc36419a4aa56383862d784feb77c5402958e7007f55f53f2bee3d30bba8`.

## Final issue disposition

Root causes and owners are detailed in the issue map above. **None is claimed
fully CLOSED**: all physical evidence in this pass is pending. The read-only
device inventory at handoff reports the physical iPhone 11 disconnected.

| Issue | Main changed files | Automated evidence | Physical | Status |
|---|---|---|---|---|
| 1 | None; backend lane | Read-only HTML/AASA/contract evidence only | Not run | BACKEND_BLOCKED |
| 2 | DigiLockerStore.swift, DigiLockerViews.swift | Unit and SE failure/history/error placement pass; no PAN/DL retry | Not run | PROVIDER_BLOCKED (functional); iOS placement awaits device |
| 3 | PassportShareManagementView.swift | SE placeholder and Large dark/XXXL Purpose pass | Not run | DEVICE_VALIDATION_PENDING |
| 4 | PassportOverviewScreenView.swift | Build pass; dedicated long Identity-value/VoiceOver assertions still needed | Not run | BLOCKED (targeted layout validation incomplete) |
| 5 | CandidateDateField.swift, CandidateLocationFields.swift | Date/City/Degree, large light/dark reachability pass | Not run | DEVICE_VALIDATION_PENDING |
| 6 | CandidateDegreeField.swift, CareerMutationSheetView.swift, ManualProfileScreenView.swift | Known/Other/custom/legacy and both-size UI pass; full persisted reopen still pending | Not run | DEVICE_VALIDATION_PENDING |
| 7 | CandidateGeography.swift, CandidateLocationFields.swift, manual/More consumers, resource database | Integrity and IN/US/CA unit checks; dependent City and no new free text on both sizes pass | Not run | DEVICE_VALIDATION_PENDING |
| 8 | EmploymentEvidence.swift, CareerDocumentsView.swift, CareerDocumentService.swift | Exact taxonomy/none/role switch/filtering/upload retry pass | Not run | BACKEND_BLOCKED (eligibility and legacy replacement contract) |
| 9 | CareerRecordDetailView.swift | SE initially expanded → collapse → expand/navigation pass | Not run | DEVICE_VALIDATION_PENDING |
| 10 | OptionalFieldChange.swift, affected Career/Profile/More/onboarding/link DTOs/drafts/services | Three-state wire, canonical-null draft, mocked Profile/link refetch/new-service tests pass; complete cross-app A–F matrix still open | Not run | BACKEND_BLOCKED (Vault), remaining runtime validation open |

## Required handoff fields

- A. Starting SHA: `af3c6a3f5115b612da0dcd0bba34776d9cfd71c9`.
- B. Final candidate SHA: **NONE**; same HEAD plus uncommitted changes.
- C. Files changed/added: **294** (40 source/test/tool/report files; 254 geography resources/notices).
- D. Inventory: **52 current iOS field slots + 12 backend-only legacy slots**; not all runtime-certified.
- E. Contract: unchanged omitted; set encoded; deliberate clear null. Six existing date paths unchanged.
- F. Degree: versioned 22 common choices + Other; custom string preserved, no backend enum invented.
- G. Geography: pinned offline ODbL database and attribution; coverage gaps explicit; public derived-data/source offer required before distribution.
- H. Evidence: approved 9 Primary / 5 Supporting; government_id excluded new; no automatic legacy reassignment. Backend invariant still required.
- I. PAN/DL: one un-attributed PAN provider retrieval 400 → backend 503 sequence; precise provider cause and independent DL incident unproven.
- J. UI: latest selected case results **SE 9/9, Large 6/6**; initial failures and corrected reruns retained above.
- K. Units: **1,046/1,046 PASS**.
- L. Privacy/provenance/integrity: **154/154 PASS**, zero skips.
- M. Physical: **NOT RUN**, iPhone 11 disconnected; no real session/device app modified.
- N. Builds: Staging Simulator test build PASS; isolated Production-configured QA Simulator test build PASS. Normal Production device/release matrix and final strict-concurrency analysis are NOT certified by those QA builds.
- O. Remaining: backend #1, PAN/DL investigation, server evidence invariant/legacy replacement semantics, Vault clearing, complete A–F persistence/relaunch coverage, dedicated Identity layout/VoiceOver checks, physical certification, remaining release gates and data-licence distribution offer.
- P. Next proposed build: **1.0 (9)**, only after closure/explicit dependency disposition and read-only ASC availability check; not created here.

**BLOCKED — no Build 9 packaging, commit, push or upload.**
