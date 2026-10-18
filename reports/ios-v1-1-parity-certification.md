# iOS Android V1.1 parity certification

**Source, build and synthetic physical gates passed.** Final commit identity and clean-source signed-artifact attestation are recorded in the closing handoff; no App Store/Production certification is implied.

## Source and boundaries

- Starting iOS: `8e5684ec60655d8faed2c9afab775bbc14af0b91`.
- Branch: `codex/ios-android-parity-v1-1`.
- Android reference: `045ed450c14fe2cd6b84f3fed88220159bf7a2aa`, exact read-only export.
- Final source identity: the scoped commit containing this report on `codex/ios-android-parity-v1-1`. The full SHA is supplied in the final handoff and generated signed-build attestation (a commit cannot embed its own hash). No application source changed after physical qualification; final test-only selector/keyboard repairs are recorded below.
- Original checkout: 19 modified tracked files preserved; HEAD/index/diff fingerprints match the preflight snapshot.
- iOS-only work. No backend, AWS, Android, Production, Admin or HR changes; no real provider, GPS, verification, upload, App Store or TestFlight action.

## Changes

See `ios-android-parity-audit.md` and `ios-android-parity-v1-1.md` for before/after evidence. The implementation uses native four-tab navigation, Career verification activity, a compact Home snapshot directly followed by attention, an integrated Passport hero and factual Trust Signals. It preserves canonical score, consent, Permanent Address and session behavior.

KairoID™ uses the supplied original master artwork, SHA-256 `5edc1f81163eece67e93a0f65484b5791bea556d88e1e83b4466f63ad2a64138`. Trust Passport uses native vector geometry from the approved Android asset, not the brand-board raster. DigiLocker uses the supplied original compact PNG, SHA-256 `f772ef83dabc983cb023dbcdc4b1b85f9c6b86ff43150d6cc9513a429aa23145`, without tint or modification.

## Regression record

| Gate | Current evidence |
|---|---|
| Unit suite | 895/895 PASS, zero skips/failures/runtime warnings in the final standalone `kairoid-v11-unit-clean.xcresult`. Earlier interrupted/failed combined bundles are not represented as successful runs |
| Privacy/provenance | 63 passed |
| Staging strict-concurrency build | Frozen-source build passed; iOS 17 deployment target |
| Focused UI | Five new Simulator parity cases and both verification-navigation recovery cases passed in `kairoid-v11-focused4.xcresult`. Guided Tour step 2 exposed nested anchor replacement after integrating the Passport CTA into the snapshot; changed anchor collection to preserve descendant targets and passed fresh Simulator and physical geometry regressions. Screenshot review also removed generic provenance wording from optional Certification signals and added assertions. Interrupted runs and the accessibility-session error (`kAXErrorServerNotFound`) are not counted as passes |
| Focused tour correction | Three fresh checks passed in `kairoid-v11-anchor-quiet.xcresult`: all five measured spotlights, XXXL + Reduce Motion + Back navigation, and complete five-step sequence. No concurrent build; no test assertions relaxed |
| Complete UI / navigation / auth | Aggregate coverage: 298 unique Simulator cases PASS, four physical-only skips. Full 302-case sweep in `kairoid-v11-full-ui-quiet.xcresult` originally had 294 passes and four legacy-brand-selector failures. All four repaired cases passed in final `kairoid-v11-final-test-repair.xcresult` (5/5 PASS including Quick Profile). This is full-sweep plus focused-repair evidence, not one all-green 302-case invocation |
| Configuration build matrix / analysis | Frozen-source Development, Staging, Demo and Production unsigned builds passed, strict concurrency complete and iOS 17 deployment target. Final Staging analysis passed |
| Physical iPhone 11 | 18/18 selected synthetic tests PASS, zero skips/failures/runtime warnings in `kairoid-v11-physical2.xcresult`, iPhone 11 / iOS 27.0.1. Includes all six new parity checks, five Welcome/Login checks, three Guided Tour geometry checks, two DigiLocker checks and two Permanent Address accessibility checks. Existing development profiles only, no provisioning update. Initial `physical1` runner initialization timeout ran zero checks and is not counted as a pass |
| Final clean-source provenance | Post-commit gate: generated full SHA, sourceClean=true, Staging/staging, 1.0 (1), Demo=false, existing Personal Team signature; exact artifact/attestation identified in closing handoff |
| Remote equality / 0/0 | Post-commit normal feature-branch push only; exact local/remote SHA and parity verified in closing handoff |

Test-only repair details: two Welcome/sign-out tests now assert accessible headline/actions and decorative-logo AX absence; sign-out also checks Home is inaccessible. Two Home tests use the accessible greeting while retaining the banner-overlap geometry assertion. The expanded repair rerun passed all four and all other selected VisualParity/Welcome cases, but Quick Profile hit an intermittent system-keyboard `kAXScrollToVisibleAction` failure on Done. The test now sends Return through the focused text field; final 5/5 includes that case. The intermediate runner stalled while collecting Simulator diagnostics after its tests completed and was stopped; its log is retained, not counted as an all-green bundle. App/auth source was unchanged by these repairs. The standalone unit and final focused bundles both completed successfully.

Four Simulator skips are physical speech tests. The new parity speech test and Permanent Address speech test passed in this task's 18-case physical run; two pre-existing unrelated physical speech tests were not rerun in this task. No claim of 302 Simulator passes or of rerunning all historic physical tests is made.

Screenshots are synthetic only. Early failed screenshots remain diagnostic evidence, not a pass.

Compiler qualification: the build matrix uses the repository's Swift 5 language mode with `SWIFT_STRICT_CONCURRENCY=complete`; it is not a Swift 6 migration certification. The compiler reports a conformance-isolation warning for the existing `GuidedTourSpotlightScrim: Shape` in the unmodified `GuidedTourOverlayView.swift:292`. That source is identical to the certified starting commit and is not changed in this task. Build/analysis success is not represented as a warning-free compiler result.

## Physical evidence (2026-10-18)

Evidence bundle: `/private/tmp/kairoid-v11-physical2.xcresult`. Export manifest: `/private/tmp/kairoid-v11-physical2-evidence/manifest.json`.

Reviewed synthetic captures:

Persistent, unedited copies of the selected captures are included in `evidence/ios-android-parity-v1-1/`: [Home](evidence/ios-android-parity-v1-1/home-light.png), [Passport light](evidence/ios-android-parity-v1-1/passport-light.png), [Trust Signals](evidence/ios-android-parity-v1-1/trust-signals-light.png), [Passport dark XXXL](evidence/ios-android-parity-v1-1/passport-dark-xxxl.png), [DigiLocker light](evidence/ios-android-parity-v1-1/digilocker-light.png), [DigiLocker dark XXXL](evidence/ios-android-parity-v1-1/digilocker-dark-xxxl.png), [Welcome](evidence/ios-android-parity-v1-1/welcome-light.png), [Login XXXL](evidence/ios-android-parity-v1-1/login-xxxl.png), [Quick Profile keyboard](evidence/ios-android-parity-v1-1/quick-profile-keyboard.png), [invitation](evidence/ios-android-parity-v1-1/invitation.png), [Permanent Address XXXL](evidence/ios-android-parity-v1-1/permanent-address-xxxl.png). All contain public/synthetic data only; no capability URLs, real account records, credentials or tokens.

- Home hierarchy/master TM/four tabs: `7115FC32-8267-4436-BECE-3D261F1D9EBA.png`.
- Passport primary full-color mark and integrated hero: `CF228EE3-F588-435D-BEE0-E43A0C114CD5.png`.
- Factual Trust Signals and neutral optional Certification: `C0F2B4F4-4733-4A61-9653-DF27DBC67677.png`.
- Dark XXXL Passport Share reachability: `FB235D7C-0F08-4C26-ACD4-9DCE69014D3B.png`.
- DigiLocker original-color artwork/connected synthetic state: `53C721D2-5684-4C0E-9FA7-A200153AB05C.png`.
- DigiLocker dark XXXL refresh control: `6C5DFDB0-6ACA-475C-838E-07E56AF7A61D.png`.
- Welcome light master: `EF00A5B0-2CF1-42EA-B420-90B65718C7FF.png`.
- Welcome XXXL page 4 reachable actions: `BF9C64C5-990D-4134-A817-A39E7084DF97.png`.
- Login XXXL single Back: `5DEA00BB-531D-4B3C-9D43-DE5D54A2DCBB.png`.
- Quick Profile synthetic input preserved, headline inline error/focus above keyboard: `530F0AC9-738D-4AFC-A225-23856CC5802E.png`.
- Dark monochrome-light mark and measured Trust Snapshot spotlight: [persistent capture](evidence/ios-android-parity-v1-1/tour-dark-mark.png), original `D3911AFA-E5AB-402A-93B0-9247FE54FCA8.png`.

Physical VoiceOver speech assertions passed for new Home/four-tab/Passport action semantics and Permanent Address review/progress. Speech was not logged. Prior VoiceOver state (off) was restored and checked with device tooling. Dark/XXXL/Reduce Motion overrides were process-only; normal relaunch used no fixture arguments. The founder confirmed normal signed-in Home is visible after restoration. No real login, provider, verification, document or GPS actions occurred.

## Intentional differences and dependencies

- SwiftUI NavigationStack, sheets, native keyboard/focus, safe areas and accessibility replace Android WebView layout mechanics.
- Unknown notification events retain native readable detail; request IDs never become invitation capabilities.
- Public organization invitation handling is Staging-only source/client coverage. Production link hosting, association and provider delivery are not certified by synthetic tests.
- No APNs registration or delivery implementation was found in the current iOS app. In-app routing is not push E2E.
- Granular per-employment sharing, stronger unified password policy, Admin-created claim and reference-comment backend/report handling remain explicitly backend-dependent. Push delivery additionally requires native APNs registration/device-token implementation and provisioning, not only backend work.
- **OFFICIAL_DIGILOCKER_ASSET_PROVENANCE_REVIEW_REQUIRED_BEFORE_APP_STORE_RELEASE**. This does not block source/Staging QA.

## Closure and scope

Source/regression and the selected physical light/dark/XXXL/VoiceOver/keyboard gates are complete. Normal signed-in Home and VoiceOver-off restoration were confirmed. Original checkout HEAD, index and all 19 tracked modifications were preserved. Commit, clean-source signed build, in-place normal Staging launch and normal feature push are the final mechanical gates, with exact SHA/remote parity in the closing handoff. No main merge, signing-configuration change, backend/Android/AWS/Production action or TestFlight/App Store upload is authorized by this report.
