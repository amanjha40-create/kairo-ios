# iOS Parity 3A — implementation and validation checkpoint

Scope: native feature/behavior closure only. No broad visual redesign, backend edits, deployments, Production changes, or push. Work is isolated in `/private/tmp/kairoid-ios-visual-parity-v1` on `codex/ios-parity-3a`; the dirty original checkout is not used for implementation.

Android reference: `b53b8dcff5056021706c03804b0d4ac926cab409` (Staging reference, not Production-readiness evidence).
Backend contract reference: `063c9a656fde94f6db665c01d7ef6df5ab8a811f`. Live owner-side sharing capability negotiation was exercised from the Staging iPhone app; no ECS audit task or deployment was performed.

## Evidence boundaries

“Contract PASS” means production service/DTO/state code exercised through deterministic mocked HTTP tests; it does not claim a live database/storage mutation was performed. “Physical read-only PASS” means the signed Staging app on iPhone 11, Demo=false, with the existing authenticated session. Certification attachment mutation, verification withdrawal/re-initiation, and live share creation/narrowing/revocation require exact disposable-fixture approval and were not performed.

## Requested 55-item report

| # | Item | Result |
|---|---|---|
| 1 | Starting SHA | `9cac9a6f94eb0abdaca0241ed9587f0d01d3c536` |
| 2 | Final SHA | The local checkpoint containing this report; exact hash supplied in the final handoff. |
| 3 | Files changed | 47 files, including tests and this report; see grouped inventory below and `git show --stat`. |
| 4 | Certification Add | Contract PASS, post-create intent/PUT/complete/reload on the same record; live lifecycle pending approval. |
| 5 | Certification View | Canonical owner download contract PASS; native protected temporary-file Quick Look implemented. Live file-preview QA pending. |
| 6 | Certification Replace | Contract PASS; complete-upload swaps the attachment, with no subsequent detach. |
| 7 | Certification Remove | Contract PASS; exact document-detach endpoint, not record deletion. |
| 8 | Certification Re-add | Contract PASS; same certification identity after remove/reopen. |
| 9 | Metadata preservation | PASS; metadata update excludes attachment-mutation fields. |
| 10 | Withdrawal endpoint | `POST /api/v1/verification-requests/{public_id}/withdraw`, tested. |
| 11 | Eligible states | Only `pending_admin_review` and `pending_admin_re_review`. Confirmation, cancellation, and in-flight guards implemented. |
| 12 | Withdrawn mapping | `withdrawn_by_candidate` → Withdrawn; completed/history grouping. |
| 13 | Cancelled mapping | `cancelled` → Cancelled, distinct from Withdrawn. |
| 14 | Record editability | Backend-refreshed Draft permits editing and new verification. iOS does not PATCH a record to fake release. Contract PASS; live pending. |
| 15 | New-request semantics | Contract PASS: withdrawn history does not count as active; new create/submit/read uses the new public ID. A 409 cannot turn terminal history into retry success. |
| 16 | Canonical status mapper | PASS for precise known states across Career, Verify, Passport and Documents. |
| 17 | Unknown fallback | Status unavailable; unknown record state does not enable verification initiation. |
| 18 | Capabilities endpoint | Authenticated `GET /api/v1/passport-shares/capabilities`; physical read-only PASS. |
| 19 | Fail closed | PASS: capability failure prevents POST; unsupported policy/modes cannot enable creation/editing; V2 missing explicit profile/photo scope cannot inherit legacy defaults. |
| 20 | Verified-only default | PASS, contract and physical read-only UI. |
| 21 | Mixed opt-in | PASS, explicit local choice; optional disclosure starts off. No live share created. |
| 22 | Purpose | Required, trimmed 1–120 Unicode scalars, inline validation; blank creation disabled on device. Existing unlabeled legacy rows may preserve their absent label while narrowing. |
| 23 | Section controls | Server-advertised verified/mixed sections and supported disclosure fields only; profile/photo and user-document dependencies enforced. |
| 24 | Narrow-only edit | PASS, existing mode immutable; changed false→true permissions rejected; PATCH contains only deliberate differences and authoritative result is refreshed. |
| 25 | Legacy policy | Legacy sharing policy, never auto-converted; original history, analytics, expiry and revocation retained. Fixture UI PASS; live legacy fixture not certified. |
| 26 | URL equality | Copy, QR, native Share and web Preview all consume the same create-response `publicURL`; no reconstruction or native recipient renderer. No live capability transmitted. |
| 27 | Documents hub | Implemented; aggregated-source contract PASS and physical authoritative-source load PASS. Partial failures are not presented as a complete list. |
| 28 | Categories | All plus populated Employment, Education, Certifications, Projects, Verification and Other filters. |
| 29 | Employment docs | Owner-authorized current attachments; mutation flags respected. |
| 30 | Education docs | Current owner attachments; no invented historical-evidence download. |
| 31 | Certification docs | Same-record add/view/replace/detach/re-add integrated with hub. |
| 32 | Project/legacy Portfolio docs | Legacy origin remains visible under Projects compatibility; no new Portfolio tab or backend migration. |
| 33 | Verification evidence | Immutable historical rows; supported owner download only, no replace/remove. Education historical gap remains explicit. |
| 34 | Vault docs | Canonical Vault sources included, with current/historical mutability and existing management flow. |
| 35 | Raw storage URL exposed | NO in the implemented document UI: owner authorization yields an ephemeral download used inside native preview, not a browser address bar. Live file lifecycle pending. |
| 36 | Focused tests | 23/23 focused contract tests (16 Parity3A + 7 Career document tests), 4/4 Parity3A UI tests PASS. |
| 37 | KairoTests | 467/467 PASS. |
| 38 | KairoUITests | 127/127 unique checks PASS across full run and isolated reruns; see execution qualifications below. |
| 39 | Development build | PASS. |
| 40 | Staging build | PASS; signed Personal-Team device build also PASS. |
| 41 | Production build | PASS, compile only; not installed or deployed. |
| 42 | Demo build | PASS, compile only. |
| 43 | Strict concurrency | PASS, complete checking with Swift warnings treated as errors. |
| 44 | iOS 17 compatibility | Compile/deployment-target PASS against current SDK; no iOS 17 runtime device test is claimed. |
| 45 | Physical iPhone QA | Read-only navigation, Documents, live capabilities, modes, Purpose, supported controls and session restoration PASS. Live mutation lifecycle remains approval-gated. |
| 46 | Crashes | 0 observed application crashes. Intentional test termination and the runner interruption are not counted as application crashes. |
| 47 | Runtime exceptions | 0 observed application runtime exceptions; test-harness failures are reported separately. |
| 48 | Backend changed | NO. |
| 49 | Production changed | NO. |
| 50 | Local commit SHA | Exact checkpoint hash supplied in the final handoff. |
| 51 | Push performed | NO. |
| 52 | Remaining iOS P0 | None identified within this scope; this is not broad release certification. |
| 53 | Remaining iOS P1 | No known unimplemented requested contract; live certification/withdrawal/share lifecycle proof remains open, so 3A is not fully certified closed. |
| 54 | Shared P1 | Education historical-evidence download; canonical Projects/Portfolio migration. Neither is replaced locally. |
| 55 | Visual Parity 3B | Finish exact-fixture live behavior gates first; then a separate visual-only branch from approved 3A, using Android Staging only as the design reference. No automatic 3B start or main integration. |

## Changed-file inventory

- App wiring: `AppDependencies`, `KairoApp`, `AppEnvironmentValues`.
- Contract/presentation: `PassportDTOs`, `PassportShareDTOs`, `ProductBrand`, new `SecureDocumentPreview`.
- Career: `CareerDocumentService`, `CareerDocumentsView`, `CareerDomain`, `CareerMapper`, `CareerOverviewScreenView`, `CareerOverviewState`, `CareerService`, new `LegacyPortfolioCompatibility`.
- More/Documents: `DocumentVaultService`, `DocumentVaultView`, `MoreOverviewMapper`, `MoreOverviewScreenView`, `MoreOverviewState`, new `DocumentsHubService` and `DocumentsHubView`.
- Passport: `PassportDomain`, `PassportMapper`, `PassportOverviewState`, `PassportShareDomain`, `PassportShareManagementView`, `PassportShareService`.
- Verify: `VerificationInitiationDomain`, `VerificationInitiationService`, `VerifyMapper`, `VerifyOverviewScreenView`, `VerifyOverviewState`, `VerifyService`.
- Tests: new `Parity3AContractTests` and `Parity3AUITests`; updated Career document/mutation/service/state, More state, Passport sharing, Verify mapper/state, main UI and visual-parity UI expectations.
- This report. Xcode's formatting-only project-file changes were removed after semantic comparison.

## Next approval boundary

Do not use the signed-in owner's records as disposable by assumption. Identify the approved disposable Staging Candidate and exact certification/request IDs before authorizing a synthetic document lifecycle or verification withdrawal/new request. For live V2 sharing, approve one exact purpose/mode/permission/expiry configuration and separate capability-transmission/revocation gates. No new actor, outreach, public load, share, document or verification request is authorized by this checkpoint.

## Local validation artifacts

- Final serialized gate: `/private/tmp/kairoid-parity3a-closure.xcresult` — 467 unit tests and 6 selected UI tests, all PASS.
- Full regression result: `/private/tmp/kairoid-parity3a-full-final.xcresult` — all 127 UI checks executed; 125 passed initially, two passed in the final isolated gate.
- Physical result: `/private/tmp/kairoid-parity3a-physical-closure.xcresult` — final signed source, one read-only owner walkthrough, PASS.
- Build logs: `/private/tmp/kairoid-parity3a-build-{Development,Staging,Production,Demo}.log`.
- Strict/iOS17 log: `/private/tmp/kairoid-parity3a-strict-ios17.log`.

Temporary artifacts are local validation evidence, not source or remote backups. No credentials, capability URLs, signed download URLs, phone numbers or real notification bodies are included in this report.

### Execution qualifications

The initial full run was not a single green invocation. It found one stale unit expectation (Document Vault → Documents), one Home UI check interrupted by an accidentally overlapping Simulator unit runner, and one older visual test whose partially visible Project-row tap hit the Verify tab below it. The unit expectation and viewport-bounded test targeting were corrected. All 467 unit tests were then rerun successfully, and the two affected UI tests plus all four new UI tests passed in one serialized invocation. The union of the full-run and retry results contains all 127 UI checks with no unresolved failures. These qualifications must not be omitted when describing the automated result.

The physical run did not certify a live attachment lifecycle, withdrawal/re-initiation, real legacy-share lifecycle, or public-link disclosure. Exact disposable-fixture identification and mutation approvals remain prerequisites to full 3A closure. No push or main integration is performed at this checkpoint.
