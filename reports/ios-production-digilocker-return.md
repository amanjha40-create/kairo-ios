# iOS Production DigiLocker return

Date: 2026-10-14; regression completed 2026-10-15 (Asia/Kolkata).
Worktree: isolated `codex/ios-production-digilocker-return`.
Starting source: `92e59118b6445e147ffdadf88015ebb6ddb2b2d9`.
Final source: the scoped commit containing this report; its full SHA is supplied
in the final handoff rather than embedded recursively in this file. Feature push
and local/remote parity are verified after the final gates. No main merge.

Backend handoff supplied for this task:
`c84a74a7e4790157ace70f01b53680b05b351206`, ARM64 manifest
`sha256:355d238b9e3dd8e3d6ebc64572501407ae88665dec58e020e93fab6c4e1a51de`,
schema `090`. This iOS task neither changes nor deploys the backend.

## Audit and implementation

The baseline parser and ASWebAuthenticationSession callback were hardcoded to
`com.kairoid.staging.digilocker`. A separate Hub gate also selected the native
authentication session only in Staging, leaving Production on an external browser.
Both now use the same fixed environment mapping; no global substitution was made.

| Configuration | API origin | Registered scheme | Native return |
| --- | --- | --- | --- |
| Staging | `https://staging-api.kairoid.com` | `com.kairoid.staging.digilocker` | Supported |
| Production | `https://api.kairoid.com` | `com.kairoid.digilocker` | Supported |
| Development | Existing development origin | `com.kairoid.development.digilocker` | Disabled |
| Demo | Existing development origin | `com.kairoid.demo.digilocker` | Disabled |

URL registration is build-configuration-specific through one Info.plist build
setting. Neutral Development/Demo schemes do not enter the native return flow.
The existing bundle ID is `com.kairoid.Kairo` in every configuration; no signing,
bundle ID, version, team, or provisioning setting was changed in source.

Production configuration already pins Production environment/API and disables
test/demo overrides. The callback uses that resolved environment. It cannot accept
the Staging scheme; Staging cannot accept the Production scheme. Both constants may
exist in the executable, but only the environment-selected one is accepted.

## Native behavior, lifecycle and privacy

ASWebAuthenticationSession is preserved, including the iOS 17 legacy initializer
and iOS 17.4+ custom-scheme initializer. The current default browser-session policy
is unchanged. Provider authorization, PKCE, state validation and code exchange
remain backend-owned. The completion page requires an explicit user tap.

Only exactly `SCHEME://complete?result=connected` or `...result=failed` is accepted.
Wrong schemes, extra fields, encoded keys/values, fragments, userinfo, ports,
arbitrary results, and credential-bearing URLs are rejected. No callback URLs or
credentials are logged. No client secret or token exchange is added.

The existing attempt UUID and consumed continuation prevent duplicate/stale
completion. Cancellation stays safe. Returned hints invoke the same store refresh:
only authenticated server truth determines Connected. Existing saved verification
history and a previously known connected state survive a transient refresh error
with an error/retry state; no optimistic Connected state is fabricated.

**COLD_START_NOT_SUPPORTED_BY_DESIGN.** Registration lets iOS recognize the scheme,
but there is no global DigiLocker action router. A URL delivered without its active
ASWebAuthenticationSession is rejected by the existing app router and cannot change
verification state. Registration is not a cold-start OAuth recovery implementation.

No Universal Links, Associated Domains, or AASA were added. This active-session
mechanism requires no Apple Organization Team ID. Organization signing/distribution
readiness remains an independent release gate; the Personal Team is used only for
the existing Staging physical-development workflow.

## Evidence and certification status

- Full unit suite: 821/821 passed, including the final regression run.
- Offline provenance/privacy: 51/51 passed.
- Focused additions: environment isolation, Production override protection,
  malformed/credential-bearing rejection, Production session configuration,
  duplicates, stale attempts, unsupported environments, cold-start rejection,
  and preservation of previously connected truth after refresh failure.
- New UI coverage uses only the credential-free Staging `/complete` page, with all
  Candidate services mocked. No provider authorization or verification is invoked.
- Initial browser UI attempts stopped at Apple's native Continue prompt. Test-only
  handling now queries the app and known Apple permission/browser hosts, and waits
  for actual UI availability. The corrected real-system-browser cancellation test
  passes on Simulator. Initial partial/failed logs remain retained.
- All three new system-browser tests passed in the final Simulator regression:
  connected return with background/resume, failed return, and cancellation. Each
  checks one Hub, preserved saved results, and no fabricated Connected state.
- Focused callback unit tests: 16/16 PASS.
- Development, Staging, Demo, Production structural builds: PASS, with per-build
  registered schemes verified in generated Info.plists. Staging static analysis PASS.
- Full UI regression: 270 cases executed across disjoint groups: 268 PASS,
  1 FAIL, 1 explicit physical-only VoiceOver skip on Simulator. Group A:
  173 PASS / 1 FAIL; group B: 95 UI PASS / 1 SKIP plus 821 unit PASS.
  The failure was the unchanged
  `ProfileWave3UITests/testProfessionalLinkValidatesAndSavesOnlySafeFixtureURL`:
  XCTest could not snapshot Apple's “English (United States) Keyboard Detected”
  alert during keyboard input. The exact same test passed in an isolated rerun
  without source changes (47.838 seconds). Thus all 269 Simulator-eligible cases
  have passing evidence, but the original full run was NOT uninterrupted green.
  No unrelated Profile correction was made or assertion weakened.
  Result bundles: `kairoid-ios-prod-return-final-shards-a.xcresult`,
  `kairoid-ios-prod-return-final-shards-b.xcresult`, and
  `kairoid-ios-prod-return-profile-rerun.xcresult`, all under `/private/tmp`.
- After physical QA, final full unit rerun: 821/821 PASS. Complete DigiLocker and
  Profile UI classes: 20/20 PASS, including the unchanged professional-link test.
  Result bundle: `/private/tmp/kairoid-ios-prod-return-final-validation.xcresult`.
  Offline provenance/privacy rerun: 51/51 PASS. All four unsigned configuration
  builds and Staging analysis passed again with complete strict concurrency and
  iOS 17 deployment target. Source diff checks passed. No source correction was
  made after the qualified physical build.
- Physical QA: 20/20 PASS on iPhone 11, iOS 27.0.1. Four native UI tests prove
  connected return with background/resume, failed return, browser cancellation,
  and invalid-return safety, each preserving one Hub and saved provenance.
  Sixteen callback/coordinator tests execute on-device, proving duplicate/stale
  protection, strict cross-environment rejection and refresh-failure safety.
  Duplicate/cross-environment evidence is on-device application-code testing,
  not a live Production OAuth or Production-installed browser session.
  Result bundle: `/private/tmp/kairoid-ios-prod-return-physical.xcresult`;
  zero failed/skipped cases and no runtime warnings. No crash observed.
- With explicit approval, Xcode renewed the Staging app development profile and
  resolved the valid existing UI-test runner profile. Both are development-only,
  include the iPhone and retain Team `XN5Y3V3CSV`. App profile creation/expiry:
  2026-10-14 18:42:14 UTC / 2026-10-21 18:42:14 UTC. Runner profile creation/expiry:
  2026-10-14 10:17:34 UTC / 2026-10-21 10:17:34 UTC. Runner regeneration was not
  necessary. App identifiers remain `com.kairoid.Kairo` and
  `com.kairoid.KairoUITests.xctrunner`. No Production signing was performed.
- Relaunched normally without fixture arguments; founder confirmed Home restored.
  No logout, Keychain clearing, account switch, or synthetic backend write.
- Production physical signing: not attempted with Personal Team. Final Organization
  signing remains the separate Apple-account gate; Production is structurally built.

Build/test logs and result bundles use the `/private/tmp/kairoid-ios-prod-return-`
prefix. Builds explicitly use `SWIFT_STRICT_CONCURRENCY=complete` and the iOS 17
deployment target, consistent with the certified baseline. No claim is made that
the pre-existing default-concurrency compiler diagnostic was fixed. Normal Xcode
test builds remain developer artifacts with the provenance sentinel, not release
archive attestations.

## Boundaries

Original dirty checkout and certified parity worktree preserved. No iOS auth/session
architecture change, account switch, logout, data clearing, real OAuth/Aadhaar call,
backend/Android/Admin source edit, Production service change, signing-team change,
TestFlight upload, or App Store submission is part of this task.

Final preservation check: certified parity worktree remains clean at the starting
SHA. Original checkout remains at `22d8c5988f7cd5ac4b0e9548216249a92bba674d` with
the same 19 tracked modifications. Its diff SHA-256 remains
`90efbc36419a4aa56383862d784feb77c5402958e7007f55f53f2bee3d30bba8` and index SHA-256
remains `c0b77eda8113698294dd433cdd2836717495cfd9a880185591f96a89c16e8497`.

Certification: implementation and physical Staging return checks PASS. All 269
Simulator-eligible UI cases have passing evidence; the explicit physical-only
VoiceOver case was skipped in the full Simulator suite. The original full-suite
system-alert failure is retained above and is not relabeled as uninterrupted green.
Production is structurally validated only, with Organization signing/distribution
left to the separate Apple-account gate expressly allowed by this task. No
Production signing change is claimed. This certification does not authorize or
claim a real Production OAuth/provider test, deployment or release.
