# Production bugfix Batch 3 — verification and evidence

## Baseline and boundaries

Starting iOS SHA: `234e8d73b3cfc774fbed8473eb1a155a104f4782`.
Branch: `codex/ios-production-bugfix-batch3`, isolated worktree.
API43 source audited read-only: `badb8318c0733a82c11117174c093e4ca25ac77f`.
Distributed TestFlight 1.0 (6) is unchanged. No provider, GPS, live upload,
verification submission, account mutation, backend edit or deployment is authorized.
Home and Light Mode redesign remain Batch 4.

## Phase 0 — contract matrix (recorded before UI implementation)

| Surface | Existing iOS | API43 truth | Mismatch / required correction |
|---|---|---|---|
| DigiLocker Hub | Connect follows saved results, inventory and Aadhaar sections | Explicit POST `/integrations/digilocker/connect`; GET status; pending/active/reconnect_required/disconnected | Move one connection action before secondary sections; never auto-connect |
| DigiLocker return | Environment-checked callback, authenticated refresh | Callback hint is not connection proof; refresh status/history/trust | Preserve coordinator/session/return behavior; show progress and retry truthfully |
| DigiLocker purpose | Separate consent and issued inventory | PANCR/DRVLC explicit identity consent; e-Aadhaar separate availability/consent. Connection alone verifies nothing | Explain distinct sources; never label manual evidence DigiLocker |
| Provider activation | Safe unavailable handling | Read-only API43 task definition confirms `DIGILOCKER_ENABLED=true` on 2026-10-21 | Config enabled is NOT provider availability/entitlement proof; no live provider probe |
| Employment methods | Existing record method controls upload permission | document / employer_confirmation; employer-confirmation records reject document upload; workflow locks apply | Preserve method restrictions, explain record-specific workflow |
| Employment verification | Two-primary gate exists, flat document rows | Draft and submit require >=2 distinct completed primary documents belonging to this record/owner; supporting/legacy excluded | Primary first, Supporting separate, Unclassified explicitly excluded; selected primary count visible |
| Employment roles | Tiny menu | `evidence_role` primary/supporting explicitly persisted; not inferred from document type | Prominent role selection, no fabricated type-to-role mapping |
| Employment types | Eight static choices | pay_stub, offer_letter, appointment_letter, experience_letter, payslip, employment_id_card, contract, bank_statement, form_w2, form_1099, employment_contract, hr_letter, relieving_letter, government_id, other | Expose complete canonical catalogue |
| Employment uniqueness | No per-type filtering | Multiple same-type files allowed. Duplicate active content checksum per employment rejected; duplicate pending type+filename rejected | Do NOT hide used types; explain repeated types; preserve server conflict authority |
| Education verification | HR default/prompt and generic shared contact | Institution + degree/study/dates; institution contact email required, name/role/note optional; shared contact enum; >=1 owned completed Education document; no primary role | Institution-specific copy/default authorised representative; no HR/founder prompts, no employment field leakage |
| Education lifecycle | Shared verification request engine | Same admin-review/clarification/organisation/terminal engine, Education claim snapshot and education_document_ids | Explain shared review process with distinct claim/evidence/contact; preserve payload and consent keys |
| Education upload state | Listed rows assumed complete | Upload intent creates pending row with empty checksum; complete fills checksum. List DTO omits checksum/completion marker and includes unfinished rows | Do not claim list proves completion. Backend submission revalidates; show completion-check caveat and safe incomplete-upload error. Do not invent new endpoint or mark pending as verified |
| Education types | Six choices | degree_certificate, transcript, marksheet, admission_letter, enrollment_proof, other | Full-screen visible selection; multiple same-type documents allowed |
| Vault | Small menu; explicit version replacement | Aadhaar/PAN/driving_license/passport/voter_id/birth_certificate/address_proof/government_id/other; current new-upload product subset preserved. No per-type uniqueness; explicit replaces_document_id supersedes old version only on completion | Prominent selected type; do not invent global uniqueness; preserve Aadhaar privacy and replacement |
| Certification / Project attachment | Add offered alongside existing attachment | One attachment slot per record; completion replaces, detach frees slot | Existing slot shows Already added; replacement via explicit Replace, not misleading second Add |
| Upload pipeline | Selection immediately starts upload; only spinner/error | intent → private storage PUT → complete → canonical list; separate verification submission | Review selected role/type/file before explicit upload; keep context on failure, no false success before completion/refetch; do not log private URLs |
| Evidence display | Flat list, status, role text | Employment canonical role/status/checksum; Education status but no completion flag; no DigiLocker provenance on manual uploads | Group only Employment roles; retain authoritative statuses, no invented dates/provenance |

### Contract evidence

API43: `app/employment/document_catalog.py`, `app/services/employment_evidence_eligibility.py`,
`app/services/document_upload_service.py`, `app/services/verification_request_service.py`,
`app/schemas/verification_request.py`, `app/verification_requests/enums.py`,
`app/services/education_service.py`, `app/schemas/education.py`, `app/repositories/education.py`,
`app/services/user_document_service.py`, `app/models/user_document.py`,
`app/services/certification_service.py`, `app/services/portfolio_service.py`,
`app/api/v1/routes/digilocker.py`, `app/services/digilocker_identity_service.py`.

Task-definition read exposed only image/revision and the enabled flag, not secrets.
API43 image: `sha256:3c4b7fa04a5d3d9a94fb49a5a955c8b8cf6483b2ec8be457e98556310b891636`.

## Validation and closure

### Implemented scope

- One real connection action precedes DigiLocker guidance, saved results and
  inventory. Connected, pending, returning and unavailable states remain based
  on the existing store; no provider/session/return coordinator was changed.
- Career and Vault use the shared searchable document-type sheet. Selection
  stays visible. File selection opens a review rather than immediately uploading.
  Completion/refetch must succeed before Added is shown; failure retains context.
- Employment groups canonical Primary, Supporting and unclassified evidence.
  Verification displays the two-primary requirement and selected count. Document
  types do not infer eligibility or provenance.
- Occupied Certification/Portfolio attachment slots show Already added and keep
  explicit Replace/Remove. Employment/Education/Vault types are not incorrectly
  hidden: the contract permits multiple same-type documents.
- Education uses institution contact copy and canonical authorised-representative
  or other contact values, with no HR/founder defaults. It uses the same backend
  request lifecycle and preserves Education payload/consent fields. Pagination is
  consumed; unknown upload completion is explicit and validated by the backend.
- Local physical QA reuses the existing compile-time and development-profile
  gate. Services are in-memory; no file bytes, credentials, transport or provider
  implementation is available to the new fixture.

### Regression findings during implementation

- A review-container accessibility identifier propagated to its child buttons.
  Moved the identifier to the review heading so Upload/Retry retain unique IDs.
- New contact/unavailable tests initially matched visible copy instead of actual
  accessibility labels. Captured synthetic hierarchies proved the controls and
  state were present; tests now match the complete spoken labels.
- Moving the connection section exposed an existing e-Aadhaar test helper's
  arbitrary 140-point bottom exclusion. Updated the helper to use navigation and
  home-indicator bounds and bounded drags, including Home's absent native bar.
  A captured XXXL consent control spanned y=-219.7…353, placing its centre under
  the navigation bar. The helper now requires button centres inside the visible
  viewport before tapping; no consent/provider code was changed.
- Removed new isolation warnings from pure document-parent helper properties
  without relaxing concurrency checking. Unrelated compiler warnings in unchanged
  source are not claimed as a warning-free baseline.
- Earlier diagnostic/failed/aborted runs are not certification results.

### Completed validation

- Full unit/integration: **1,018/1,018 PASS** (`kairoid-batch3-regression-r2.xcresult`).
  That broader run was stopped after the completed green unit and Career suites
  to correct a UI-test helper; its overall interrupted action is not called PASS.
- Focused contract/service coverage within that total: Batch3EvidenceContractTests
  10, CareerDocumentServiceTests 16, VerificationInitiationTests 10, Vault service
  20, DigiLocker return 16 and canonical authenticated read QA 5, all PASS.
- New Production-configured synthetic UI: **10/10 PASS**
  (`kairoid-batch3-ui-r3.xcresult`). Captures include selected type, Primary/
  Supporting hierarchy, single-slot replacement, failure/retry/refetch, institution
  contact, disconnected/connected/unavailable, light/dark XXXL and reopen.
- Career hierarchy UI: **11/11 PASS** (completed suite in regression-r2).
- Documents/Verify/Parity3A/Parity4A UI: **26/26 PASS**
  (`kairoid-batch3-documents-verify.xcresult`).
- Existing DigiLocker Wave1 UI: **14/14 PASS** (completed suite in
  `kairoid-batch3-digilocker-final.xcresult`; that combined action retains the
  historical XXXL e-Aadhaar test failure and is not called wholly green).
- Final e-Aadhaar rerun: **12/12 PASS** (`kairoid-batch3-aadhaar-r4.xcresult`),
  including the corrected XXXL consent tap. Aggregate affected Simulator UI:
  **73/73 PASS** across the completed suites above, not the entire UI catalogue.
- Ordinary Production device **build + analysis PASS**
  (`/private/tmp/kairoid-batch3-device-final.log`).
- Ordinary Production Simulator **build + analysis PASS**
  (`/private/tmp/kairoid-batch3-simulator-final.log`).
- Strict concurrency checking enabled (`complete`); no new Batch3 isolation
  warnings remain. This does not claim all historical repository warnings are gone.
- Offline privacy/provenance/artifact checks: **96/96 PASS, zero skips**
  (`/private/tmp/kairoid-batch3-privacy-final.log`).
- Local physical test build: signed by existing `MVT4T97ZGC`; actual entitlements
  confirm `MVT4T97ZGC.com.kairoid.Kairo`, development `get-task-allow=true`, and
  unchanged Associated Domains. No certificate/profile/signing-config changes.

### Physical certification

- iPhone 11, existing official-team development signing: **10/10 PASS**
  (`/private/tmp/kairoid-batch3-physical-qa-r2.xcresult`). The first attempt timed
  out enabling XCTest automation before any test ran; the founder enabled it
  privately and the unchanged test build passed on retry.
- Disconnected Connect is visible without scrolling and unique; connected and
  unavailable states are truthful. Background/reopen retains the synthetic Hub.
- Employment Primary/Supporting/unclassified groups, selected type, Education
  document types and institution contact, occupied single-slot replacement,
  retained failure context, Retry and completion/refetch all passed.
- Light and dark Accessibility XXXL selection/review controls were reachable.
  Native accessibility labels, values, selected traits and actions were inspected
  through XCTest hierarchies. This is not a claim of a separate human spoken
  VoiceOver walkthrough. Native progress and error accessibility is retained.
- Synthetic captures exported to
  `/private/tmp/kairoid-batch3-physical-attachments`; Connect, institution contact,
  retry and dark XXXL screenshots were visually inspected. The existing local-QA
  banner overlays navigation in test mode (especially XXXL); it is not normal
  product UI and is disabled on ordinary launch.
- The app was relaunched without test arguments after testing. No live upload,
  provider/OAuth, GPS, verification submission, logout or account change occurred.
- Closure privacy/provenance rerun: **96/96 PASS, zero skips**
  (`/private/tmp/kairoid-batch3-privacy-closure.log`). `git diff --check` PASS.

### Source handoff and remaining boundaries

The commit containing this report is the Batch 3 source checkpoint; its exact SHA
and normal-push parity are recorded in the final handoff rather than a circular
self-referencing source constant. After commit, the clean-source provenance tool
must build and verify the ordinary signed Production device artifact, with no QA
compilation flag, before final in-place installation and normal Home confirmation.
No TestFlight upload or main merge is part of this batch.

Historical checkout preserved: HEAD
`22d8c5988f7cd5ac4b0e9548216249a92bba674d`, same 19 modified files, same index and
staged/unstaged content hashes. No backend, Android, Production service/config,
signing configuration or API contract changes.

Tester issues #6, #9, #10, #15 and #16 are addressed within the API43 contract.
Home redesign and Light Mode redesign remain explicitly deferred to Batch 4.
No live provider availability, real upload, or Production verification outcome is
certified by these isolated tests. API43's missing Education upload-completion
field remains a backend limitation, handled truthfully without backend changes.
