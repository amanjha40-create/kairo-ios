# iOS Android post-parity Batch 2 mirror

Status: full updated-build automated regression and guided physical iPhone 11
certification PASS. Final normal signed-in Home and background/reopen preservation
were confirmed by the founder. The original session-loss incident remains
unattributed; it was not reinvestigated without a new reproduction.
The original task authorizes feature-branch commit and normal push after these
gates. Exact commit/remote parity are recorded in the final closure response.

## Provenance and boundaries

- Branch: `codex/ios-android-batch-2-mirror`.
- Starting SHA: `c7943eee2a95c680917fc29370bab6683151e5a4`.
- Final SHA: the certification commit containing this report (full SHA returned
  in the closure response; use `git log -1 --format=%H -- reports/ios-android-post-parity-batch-2-mirror.md`).
- Read-only Android reference: `899c625463e23be0904b239f5330413dd3c6825b`.
- Read-only backend reference: `36a1aea486a92d339e0d58678bd83455b522e3ab`.
- User-supplied Staging contract reference: API235 / DB084.
- Android, backend, Production, signing settings and original dirty checkout are unchanged.
- Batch 1 Guided Tour, Welcome, Login and DigiLocker return lineage is preserved.

## Product changes

1. Owner Passport retains its hero, backend Trust Score, identity, disclosure/trust
   summaries, completeness, timeline, sharing and export controls. Expanded Career
   lists are replaced with the Android reference's Career details copy and View
   Career tab navigation. Underlying Passport records, sharing policy, recipient
   routing and PDF service are unchanged.
2. Withdrawn status is neutral in Career and remains Withdrawn in Verify history.
   Backend record mutability and active-request eligibility remain authoritative.
3. Employment uploads encode an explicit primary/supporting role. Eligibility is
   read from the authenticated evidence-eligibility endpoint, not upload progress
   or category diversity. The initiation form requires server eligibility and two
   distinct selected completed primary attachments. The service checks server
   eligibility again before submission; backend still validates exact attachments.
4. Legacy NULL-role documents remain visible with a not-counted explanation.
   Classification uses PATCH on the exact parent/document evidence-role route,
   then reloads metadata and eligibility. No owner ID is asserted by the client.
   Ownership/workflow denials propagate as safe failures. No re-upload is required.
5. Employment location renders stored city plus stored country, or city alone.
   No locale/region supplies a missing country; Remote remains Remote.
6. Detail Edit has a neutral outline and pencil; Delete retains destructive
   treatment with a trash icon. Adaptive layout and existing owner confirmation
   callbacks are preserved.
7. Existing CandidateDataRefreshStore invalidation already reaches Career, Verify,
   Home and Passport after successful verification. Profile and open Trust Score
   detail now also observe it and read authoritative services. No local scoring.
8. Existing DigiLocker verification completion/failure cleanup and safe result
   presentation are retained and regression-tested. OAuth architecture, callback
   parser, completion contract and provider behavior are unchanged.

## Changed areas

- Career document service/view, evidence model, mapper/status and detail actions.
- Owner Passport screen/section hierarchy; shared/public/PDF implementations untouched.
- Verification initiation domain/service/form and isolated navigation fixture.
- Profile and Trust Score refresh observers; neutral outlined action style.
- Staging-only Batch 2 fixture host and focused unit/UI regression coverage.
- Prior Career/Passport/verification tests updated to the newly approved contract.

### File inventory

Product and isolated fixture files:

- `Kairo/App/AppSessionStore.swift`
- `Kairo/App/KairoApp.swift`
- `Kairo/App/SessionRecoveryQA.swift`
- `Kairo/Core/Auth/SessionService.swift`
- `Kairo/DesignSystem/Components/KairoButtons.swift`
- `Kairo/Features/Career/Batch2EvidenceFixtureView.swift`
- `Kairo/Features/Career/CareerDocumentService.swift`
- `Kairo/Features/Career/CareerDocumentsView.swift`
- `Kairo/Features/Career/CareerMapper.swift`
- `Kairo/Features/Career/CareerOverviewState.swift`
- `Kairo/Features/Career/CareerRecordDetailView.swift`
- `Kairo/Features/Career/EmploymentEvidence.swift`
- `Kairo/Features/MainTabs/CandidateTabShellView.swift`
- `Kairo/Features/Passport/PassportOverviewScreenView.swift`
- `Kairo/Features/Passport/PassportOverviewState.swift`
- `Kairo/Features/Profile/ProfileOverviewView.swift`
- `Kairo/Features/TrustScore/TrustScoreDetailView.swift`
- `Kairo/Features/Verify/VerificationInitiationDomain.swift`
- `Kairo/Features/Verify/VerificationInitiationService.swift`
- `Kairo/Features/Verify/VerificationInitiationSheet.swift`
- `Kairo/Features/Verify/VerifyNavigationFixtureHostView.swift`

Regression files:

- `KairoTests/App/AppSessionStoreTests.swift`
- `KairoTests/Core/SessionServiceTests.swift`
- `KairoUITests/SessionRecoveryQAUITests.swift`
- `KairoTests/Features/Batch2EvidenceTests.swift`
- `KairoTests/Features/CareerDocumentServiceTests.swift`
- `KairoTests/Features/CareerOverviewMapperTests.swift`
- `KairoTests/Features/DigiLockerTests.swift`
- `KairoTests/Features/Parity3AContractTests.swift`
- `KairoTests/Features/PassportHierarchyTests.swift`
- `KairoTests/Features/PassportOverviewStateTests.swift`
- `KairoTests/Features/VerificationInitiationTests.swift`
- `KairoUITests/Batch2MirrorUITests.swift`
- `KairoUITests/DigiLockerWave1UITests.swift`
- `KairoUITests/KairoUITests.swift`
- `KairoUITests/PassportHierarchyUITests.swift`
- `KairoUITests/VerifyFocusedNavigationUITests.swift`
- This report.

## Fixture safety

Batch 2 physical/UI fixtures require exact Staging configuration and environment,
validated explicit UI-test launch mode and the Batch 2 flag. Production cannot
activate them. Existing UI-test dependencies use in-memory tokens and blocked
networking. Classification modifies only a disposable in-memory fixture service;
upload, delete and download are blocked. No live account/document mutation is
needed for these checks. Normal relaunch omits all fixture flags.

## Initial Batch 2 validation and physical evidence (before auth follow-up)

- Full unit suite: 768/768 PASS.
- Full UI suite: 251/251 PASS (zero failures, fresh complete action).
- Combined default Staging test action: 1,019 tests PASS.
- Provenance: 38/38 PASS after final regression.
- Initial focused UI exposed an obsolete completeness selector and a new parent
  accessibility identifier overriding the Career CTA. The selector was corrected
  and the card identifier moved to its heading, preserving the button identifier.
- Corrected focused gate: 768 unit tests and 6 focused UI tests PASS.
- Full regression: PASS. Older owner hierarchy assertions now enforce the
  approved compact Career card, with sharing/export coverage retained.
- The first full run was stopped after a new safe-failure UI test used visible
  text instead of the existing prefixed VoiceOver label. Its terminal-state
  assertions had passed; only the error-label lookup failed. The selector was
  corrected without changing DigiLocker product code. Both targeted terminal
  checks and the fresh complete suite subsequently passed.
- Staging Simulator build and analysis: PASS; strict concurrency enabled.
- `git diff --check`: PASS.
- Signed Staging device build: PASS with the existing approved development team.
- Automated physical UI runner: BLOCKED before execution because no development
  profile is installed for the separate `com.kairoid.KairoUITests.xctrunner`.
  No profile/signing configuration was changed. This is not an app test failure.
- Physical iPhone 11: signed update installed over the existing app; no uninstall,
  logout or data clearing. Write-blocked Batch 2 fixture launched successfully.
  Guided on-device walkthrough is in progress.
- Founder-confirmed physical Passport check (2026-10-10): PASS. Trust/completeness
  retained, expanded Career lists absent, Career details/View Career present,
  and View Career opens the synthetic Batch 2 Career fixture. This confirmation
  does not certify the remaining evidence, action, or restoration checks.
- Founder-confirmed physical evidence counts (2026-10-10): PASS. The 0/1/2
  primary fixtures display the expected counts despite each also containing a
  supporting file and an unclassified legacy file. Classification remains a
  separate pending physical check; no live evidence was changed.
- Founder-confirmed physical legacy classification (2026-10-10): PASS. In the
  one-primary fixture, classifying the legacy attachment as primary changes the
  refreshed count to two without re-upload. Reopening the fixture and classifying
  it as supporting leaves the primary count at one. These were in-memory fixture
  changes, not live backend persistence or ownership tests.
- Founder-confirmed physical Employment detail (2026-10-10): PASS. Neutral
  status rather than Withdrawn/In progress, stored Jaipur/India and city-only
  missing-country presentation, neutral outlined pencil Edit and destructive
  outlined trash Delete, with both actions readable/reachable. No action was
  invoked. Accessibility XXXL remains a separate physical check.
- Founder-confirmed physical Employment Accessibility XXXL (2026-10-10): PASS.
  Text/locations remain readable, Edit/Delete are visible and reachable, and
  title/bottom controls do not overlap. Used a launch-only text-size override;
  system accessibility settings and live data were not changed.
- Founder-confirmed physical verification safe-failure fixture (2026-10-10):
  PASS. Loading terminates with the safe failure message, saved results remain,
  consent resets, and no browser/OAuth opens. Verification was handled solely by
  the in-memory fixture service; this was not a live verification request.
- Founder-confirmed physical verification success fixture (2026-10-10): PASS.
  Loading terminates, consent resets, supplied verified/needs-attention results
  remain visible, and no error, duplicate Hub or OAuth appears. This confirms
  fixture-backed terminal presentation, not a live verification or score change.
- Founder-confirmed physical cross-screen/share controls (2026-10-10): PASS.
  Home, Passport and More/Profile open without errors or stuck loading after the
  fixture verification. Share creation still exposes mode, Career section
  choices, purpose/expiry and review. Founder cancelled without creating a share.
  Shared/public/PDF content preservation is additionally covered by unchanged
  implementations and automated contract tests; no live recipient capability was
  opened. Authoritative refresh wiring is covered by service/state tests and the
  six surfaces' refresh observers, not a live verification mutation in this QA.
- Initial normal post-fixture launch showed Welcome instead of restoring the
  previous signed-in Home. The cause is unproven. Fixture walkthroughs used an
  isolated in-memory session and therefore did not establish that the real
  Keychain-backed session was valid immediately before normal restoration.
- Approved diagnostic launch attempts produced no confirmed application launch
  or usable request-status evidence; the corrected console attempt exited 64.
  This is a diagnostic-tooling gap, not proof of a backend/authentication error.
  No raw console content, tokens or credentials were persisted by the capture.
- Founder privately signed in again, then confirmed "Home restored" after
  manually closing KairoID through the app switcher and reopening its icon.
  Normal signed-in Home and persistence of that NEW sign-in: PASS, founder
  observed. This does not retroactively prove preservation of the original
  session or explain its loss. No manual logout, uninstall or app-data clearing
  was performed by the agent during diagnosis.

## Historical gate before the approved session follow-up

The Batch 2 feature regression and fixture-backed physical checklist passed on
the pre-follow-up build. Normal Home and a close/reopen pass are confirmed after
private re-authentication. The user subsequently approved the narrow source fix
below. A complete UI rerun and physical qualification of the updated binary are
still required before unqualified final certification/commit/push. The earlier
251/251 full UI and physical passes must not be represented as runs of the new
auth code. Do not attribute the historical incident to this defect or token
expiry without runtime evidence. Do not promote a launch candidate or initiate
live OAuth, real verification, deletion or unapproved persistence mutations.

## Approved session-recovery follow-up

- Read-only investigation found that both bootstrap refresh and refresh after a
  protected-request 401 deleted all local tokens on any refresh failure. The
  source predates Batch 2; auth, Keychain and session routing were unchanged by
  the Batch 2 feature work. This is a proven source defect, not proof of the
  original physical incident's cause.
- The user separately approved its narrow correction and regression coverage.
  Only `Kairo/Core/Auth/SessionService.swift` changes product behavior: refresh
  errors preserve credentials unless refresh is authoritatively rejected with
  HTTP 401/unauthorized or the required refresh credential is missing. The
  existing single-replay limit and expiry after a rejected replay remain intact.
  The existing native Session unavailable/Retry surface is reused without UI,
  authentication-route, signing, backend or Production changes.
- Added coverage in `KairoTests/Core/SessionServiceTests.swift` and
  `KairoTests/App/AppSessionStoreTests.swift`. Both paths cover offline, timeout,
  cancellation, 400/403/422/429/500/502/503 and malformed success responses,
  credential preservation, later recovery, genuine rejection, missing refresh,
  replay bounds, retryable routing and retained Candidate identity.
- Red gate: the new transient-failure regressions reproduced token erasure on
  the previous implementation. Green focused gate: 32/32 session/routing tests.
- Updated full unit suite: 776/776 PASS. Provenance: 38/38 PASS.
- Targeted auth/session UI: 7/7 PASS (Login success/rejection, native password
  reset, logout, normal/XXXL Back controls and session-preserving navigation).
  Updated Staging build/static analysis with strict concurrency: PASS.
  `git diff --check`: PASS. Test artifacts are
  `/private/tmp/kairoid-session-recovery-red.xcresult`,
  `/private/tmp/kairoid-session-recovery-green.xcresult`, and
  `/private/tmp/kairoid-session-recovery-regression.xcresult`.
  Provenance/analysis logs use the `kairoid-session-recovery-` prefix in
  `/private/tmp`. No commit or push was made for this follow-up.
- The physical iPhone's newly working session has not been relaunched, logged
  out, cleared, reinstalled or instrumented during this implementation. The
  corrected source is not yet installed on that phone.

### Approved physical-session fixture and updated gate

- User approved complete regression and physical auth/session validation, then
  explicitly approved the missing Staging-only session fixture. Existing
  DigiLocker read-failure fixtures intentionally block session rotation and
  cannot prove refresh-token recovery/rejection.
- Added `Kairo/App/SessionRecoveryQA.swift` and
  `KairoUITests/SessionRecoveryQAUITests.swift`, with an explicit gated root in
  `Kairo/App/KairoApp.swift`. Activation requires Staging build AND environment,
  Demo=false, the UI-test argument AND a dedicated session-fixture flag.
  The fixture creates its own InMemoryTokenStore, real SessionService and
  mock-only NetworkClient. It has no Keychain/URLSession or network forwarding;
  non-allowlisted routes/methods fail closed. Normal launch is unchanged.
- The fixture reproduced an additional narrow signed-out state-cleanup issue:
  empty tokens routed to Welcome while leaving the prior AppUser in memory.
  `AppSessionStore.applyLaunchRoute(.signedOut)` now clears currentUser. This
  is covered both directly and through real SessionService rejection in the
  fixture; it is not evidence of the historical incident's cause.
- Focused fixture gate: 35 unit/state tests and 2 UI tests PASS. Transient
  failure preserves synthetic credentials/identity, Retry recovers, confirmed
  rejection removes synthetic credentials/identity and reaches canonical Login
  without authenticated tabs. No real credential corruption is involved.
- Fresh complete unit result including the fixture: 779/779 PASS. The earlier
  full UI attempt was deliberately interrupted when fixture scope was approved;
  it is superseded by `/private/tmp/kairoid-session-fixture-full.xcresult`.
  Updated complete gate PASS: 779/779 unit tests, 253/253 UI tests (zero
  failures), 38/38 provenance tests, Staging static analysis, signed Staging
  device build and git diff --check. Full UI duration: 4101.486 seconds.
  Both new session-fixture UI cases passed in the complete run.
  Strict-concurrency checking was enabled. Analysis/build retained warnings in
  unchanged GuidedTourOverlayView.swift and DigiLockerAuthentication.swift;
  success is not a claim of a warning-free repository. No scope expansion was
  made to alter those files.
- Qualified uncommitted source fingerprint (tracked binary diff plus untracked
  source/test/build-tool file hashes):
  `fe39754f0c92d86052207b1304a70957f7a6e79e5f8886b7a631cab69406fcd7`.
  This is a developer QA build, not a new clean-commit release attestation.
  Signed app is `/private/tmp/kairoid-session-fixture-device/Build/Products/Staging-iphoneos/Kairo.app`:
  bundle com.kairoid.Kairo, version 1.0 (1), Staging, staging, Demo=NO,
  Team XN5Y3V3CSV. Signature verification passed with normal Keychain access.
  Original checkout HEAD, tracked diff hash, index hash and 19 dirty tracked
  files were rechecked unchanged. After founder confirmed phone unlocked,
  devicectl installed this app over the existing iPhone 11 installation and
  launched com.kairoid.Kairo normally with no fixture arguments/environment.
  Installation and launch succeeded. No uninstall, data clearing or logout was
  performed. Normal Home/session and background/foreground checks were
  confirmed PASS by founder ("Normal session passed"): existing signed-in Home
  loads and remains signed in after background/foreground. This is physical
  founder-observed evidence, not a captured HTTP/session trace.
- Updated-build physical isolated session checks: founder confirmed transient
  failure PASS, synthetic credentials retained and no Login; Retry recovery
  PASS with authenticated fixture data; confirmed rejection PASS with expired
  synthetic session, absent synthetic credentials and canonical signed-out
  Login without authenticated tabs. The fixture uses real SessionService but
  only in-memory synthetic credentials and a mock-only network. These results
  do not claim a real backend refresh/rejection or explain the historical logout.
  After these checks the app was relaunched normally without fixture arguments
  or environment. Founder confirmed "Home restored": the real signed-in Home
  returned and the Session QA banner was absent. Updated-build affected-session
  physical gate is PASS (founder observed). Remaining Batch 2 presentation
  checks are being repeated on this exact build before final certification.
- Updated-build Batch 2 founder-observed confirmations: Passport simplification
  and View Career PASS; 0/1/2 primary counts with supporting exclusion PASS;
  legacy Primary classification increments count and Supporting does not, with
  no reupload, PASS; Employment neutral status, truthful full/missing-country
  locations and Edit/Delete hierarchy PASS. These checks used synthetic
  in-memory fixtures, not live document mutations. Accessibility XXXL PASS,
  founder confirmed on the updated build: Passport/Career CTA, evidence counts
  and classification controls, location and Edit/Delete remain reachable and
  unclipped. XXXL was a launch-only override, not a system-setting change.
  Relaunched at normal text for mock-only terminal-verification checks.
- Updated-build terminal-verification failure fixture: founder confirmed PASS.
  Loading stops, safe failure is shown, saved results remain, consent resets,
  and no browser/OAuth opens. This used the in-memory service, not a real
  verification submission. Updated-build success fixture also founder-confirmed
  PASS: loading terminates, supplied results remain, consent resets and Verify
  is disabled pending renewed consent, with no browser/OAuth.
- Updated-build navigation/share checks: founder confirmed PASS. Home, Passport
  and More/Profile load without errors or stuck loading; Share Passport retains
  mode, Career sections, purpose and expiry controls. Founder cancelled without
  creating a share. Authoritative refresh wiring remains supported by service/
  state regression and refresh observers; fixture observations do not prove a
  live verification mutation or backend score change.
- All updated-build guided physical fixture checks have passed. Relaunched
  normally without fixture flags. Founder confirmed "Final Home restored":
  existing real signed-in Home loads, no fixture banner or synthetic Project,
  and background/reopen keeps the session. Final normal-state gate PASS.
- Physical steps must run normal launch/background preservation BEFORE isolated
  transient/rejection fixtures, then restore normal launch without test flags.
  No commit or push until affected session and remaining Batch 2 physical gates
  are complete. Do not reopen historical incident investigation absent a fresh
  reproduced failure with captured evidence.

## Final certification summary — 2026-10-10

- Updated unit suite: 779/779 PASS; full UI suite: 253/253 PASS; combined test
  action: 1,032/1,032 PASS. Provenance: 38/38 PASS. Staging analysis and signed
  device build: PASS with strict-concurrency checking enabled, with the
  unchanged-source warnings recorded above. Diff check PASS.
- Physical session gates: normal launch, background/foreground, isolated
  transient failure with credentials retained, retry recovery, confirmed
  synthetic rejection to Login, and real session restoration all PASS.
- Physical Batch 2 gates: compact owner Passport and View Career, primary
  evidence counts/supporting exclusion, legacy classification, neutral withdrawn
  status, truthful locations, Edit/Delete hierarchy, XXXL, terminal failure and
  success, navigation/share controls and final normal Home all PASS.
- Physical evidence is founder-observed on the signed iPhone 11 build. Fixtures
  are synthetic and isolated. No live OAuth, real verification, live document
  classification/upload/delete or share creation was performed. Shared/public/
  PDF preservation and authoritative refresh wiring rely on source/contract/
  regression evidence, not a new live recipient or verification transaction.
- No local Trust Score calculation. Android/backend/Production unchanged.
  Original dirty checkout HEAD, 19 tracked modified files, diff and index
  fingerprints remain unchanged. No signing/configuration changes.
- No remaining blocker for this narrowly scoped Batch 2 certification. Broader
  launch-candidate/release gates are not promoted or declared complete.
- The physically tested developer artifact was built before commit from the
  exact source fingerprint recorded above. Do not claim it embeds the upcoming
  clean commit SHA; a future immutable release candidate requires its own clean
  build/installed-provenance qualification.
