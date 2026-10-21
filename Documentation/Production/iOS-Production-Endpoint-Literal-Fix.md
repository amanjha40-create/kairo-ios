# Production endpoint literal exclusion

Release-configuration/packaging-only change. Starting source:
`4ac1c57e40f0bc82d8da6e0620c2ae71bb0575e0`.
Branch: `codex/ios-production-endpoint-literal-removal`.
New isolated worktree: `/private/tmp/kairoid-ios-production-endpoint-literal-removal`.
Starting state was clean; the exact Batch 1–4/privacy ancestry is retained.
No original checkout, previous certification worktree or other branch is edited.

## Endpoint inventory and original inclusion path

The app target synchronizes `Kairo/`; unit/UI test directories have separate targets.
BuildTools and release documentation are not app resources. Info.plist substitutes
environment/configuration/Demo fields, not an API URL. Provenance contains only
allowlisted source/build fields. No separate xcconfig endpoint registry exists.

| Literal/material | Original source | Original compilation / D,S,P inclusion | Reachable in normal Production? | Action |
|---|---|---|---|---|
| `https://api.kairoid.com/api/v1` | APIConfiguration.swift | Unconditional / yes,yes,yes | Yes, canonical API | Retain |
| `http://localhost:8000/api/v1` | APIConfiguration.swift | Unconditional / yes,yes,yes | No; Production forces its environment | Compile out of Production |
| `https://staging-api.kairoid.com/api/v1` | APIConfiguration.swift, DigiLockerReadQA.swift | Unconditional definition / yes,yes,yes | No; read QA activation additionally gated | Compile out; shared endpoint policy |
| Staging `/integrations/digilocker/complete` safe-result URL | DigiLockerAuthentication.swift fixture | Definition unconditional / yes,yes,yes; invocation gated to Staging QA | No | Move endpoint construction into compile-time policy |
| `staging-api.kairoid.com` | GoogleReturnDiagnostics.swift | Unconditional diagnostic allowlist / yes,yes,yes | Only a sanitized host label, not a request target | Production allowlist contains Production host only |
| `localhost`, `127.0.0.1` | PassportShareService.swift | Unconditional local-host allowlist / yes,yes,yes | No; requires development environment and HTTP | Compile out host set, keep validation flow |
| `d3kpvsn9kfajzc.cloudfront.net` | AppConfiguration.swift public/Document Pack hosts | Unconditional Staging set / yes,yes,yes | No; selected only for Staging | Compile out Staging set |
| Development default environment | AppEnvironmentValues.swift SwiftUI fallback | Unconditional / yes,yes,yes | SwiftUI can evaluate default before injection | Select compile-time default to avoid selecting an excluded endpoint |
| `app.kairoid.com`, `kairoid.com` legal/help URLs | AppConfiguration, MoreOverviewState, entitlements | Shared / yes,yes,yes | Yes, intended public destinations | Preserve |
| Google/DigiLocker provider URLs in demo services | AuthService mock, DigiLockerService demo | Existing fixture definitions | Not normal Production; Demo is forced off | Preserve existing mocks; no provider/auth redesign |
| `*.invalid`, example.com/github example prompts, fixture LinkedIn URL | Demo/fixture services and editor prompts | Existing presentation/synthetic definitions | Not configured backend origins; placeholders/fixtures | No product-copy/mock redesign |
| `com.kairoid.staging.digilocker` | Return parser and configuration settings | Shared parser, configuration-specific registration | Production selects its own scheme | Preserve cross-environment parser contract; not an API endpoint |

Original cause: runtime selection prevented wrong-environment activation but did
not prevent shared string definitions from being linked into shipping bytes.
The old signed archive is a red witness: the scanner rejects all four prohibited
host fragments in its executable.

## Implementation and safety

Only the Production project configuration defines `KAIRO_PRODUCTION`.
`BuildEndpointPolicy` owns endpoint/host definitions. Its Production compilation
contains the canonical Production API and no local, Staging API or Staging CDN
hosts. Requests to select a non-Production API in that compilation fail closed
with a precondition instead of silently falling back to another origin.

Non-Production compilation preserves the existing environment switch and QA
workflows. Development resolves `http://localhost:8000/api/v1`; Staging resolves
`https://staging-api.kairoid.com/api/v1`. Production resolves
`https://api.kairoid.com/api/v1`, and existing AppConfiguration override rejection
and Demo=false behavior are unchanged.

The consuming files replace endpoint constants/sets and the SwiftUI configuration
default only. Production's default selects Production; other configurations keep
the existing Development preview default. Missing-service sentinels and real
dependency injection are unchanged. No authentication,
Google parser/exchange, session, onboarding, Resume, Career, Passport mutation,
DigiLocker authentication, verification, document, Home, appearance or navigation
logic is changed. Production diagnostics label a rejected non-Production host as
`other`; they never need to retain that host literal. No strings are obfuscated.

## Artifact regression

Run the read-only gate on the actual built app or archive:

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 BuildTools/endpoint_scan.py /path/to/KairoID.xcarchive
```

The scanner walks every regular file in the shipping `.app`, including resources
and nested frameworks; it does not scan source documentation or non-shipping dSYMs.
It rejects symlinks, ambiguous archives, incorrect Production metadata, Demo mode,
missing executable, and case-insensitive UTF-8/UTF-16 occurrences of `localhost`,
`127.0.0.1`, `staging-api.kairoid.com`, or the Staging CDN host. Chunk overlap
prevents boundary misses. It requires the exact Production API in the executable,
not merely a metadata claim. No file contents, credentials or tokens are printed.
The clean-source provenance build wrapper automatically invokes this gate for
every Production candidate before emitting its success attestation.

Offline mutation tests cover both original full endpoints, generic hosts, UTF-16,
nested framework/resource leaks, chunk boundaries, missing positive endpoint,
incorrect environment metadata, symlinks and non-shipping documentation exclusion.
Separate Swift compilation tests execute the actual endpoint policy with/without
the Production flag and prove invalid Production environment requests fail closed.

## Validated source-freeze checkpoint (2026-10-21)

| Check | Result |
|---|---|
| Full unit/integration, final configuration source | 1,026/1,026 PASS; 0 failures, 0 skips |
| Targeted UI, final configuration source | 6/6 PASS; 0 failures, 0 skips |
| Privacy/provenance/endpoint regression | 145/145 PASS; 0 skips (129 prior + 16 endpoint checks) |
| Development Simulator build | PASS; development metadata, Demo NO, expected local endpoint |
| Staging build-for-testing and final test rebuild | PASS; staging metadata, Demo NO, expected Staging endpoint |
| Production Simulator build, arm64/x86_64 | PASS; final incremental build after configuration-default adjustment |
| Production static analysis | PASS; complete concurrency checking, no weakened settings |
| Final Production Simulator byte scan | PASS; localhost, loopback, Staging API and Staging CDN absent; exact Production API present |
| Privacy manifest in fresh Simulator app | PASS; exactly one, equals certified source |
| Existing signed archive red witness | FAIL as intended; all four prohibited host fragments found |
| Product logic change | NO; endpoint definitions and configuration default only |
| Diff check | PASS |

UI coverage: cold Google fragment handoff, warm/duplicate handoff, unrelated URL
rejection, Demo Home, normal password-login routing and Passport. All use synthetic
test dependencies; no real Google/provider login or Production mutation.

The first restricted build attempts failed because the sandbox denied Xcode
compiler-plugin/CoreSimulator access. They are not passing evidence. Approved
access reruns passed. Existing Swift 5-mode actor-isolation warnings remain in
DigiLocker fixture activation, Guided Tour Shape conformance and test helpers;
no new endpoint-policy warnings were observed. This is not a Swift 6 language-mode
or warning-free claim.

Evidence retained outside source:

- `/private/tmp/kairoid-endpoints-final-regression.xcresult` and corresponding `.log`.
- `/private/tmp/kairoid-endpoints-privacy.log`.
- `/private/tmp/kairoid-endpoints-development-final.log`.
- `/private/tmp/kairoid-endpoints-staging-build-access.log`.
- `/private/tmp/kairoid-endpoints-production-sim-access.log` (build and analysis).
- `/private/tmp/kairoid-endpoints-production-final.log` (final packaged product).

## Exact-SHA signing and completion record

The final SHA is the commit containing this source-freeze report, not the starting
SHA. It cannot be embedded in its own commit without a circular identity. After
this commit, the clean-source wrapper must build a fresh signed Production
1.0 (7) app using existing Team MVT4T97ZGC. No source edits may occur during that
build. Its sidecar and embedded provenance must name the exact full commit SHA.

Post-commit signing, scan and normal-push results are recorded separately in
`/private/tmp/kairoid-endpoints-final-attestation.json` and the final task handoff.
That record provides the full final SHA, artifact path/hash, actual signed
entitlements, privacy-manifest result and remote parity without modifying the
attested source after building. Do not infer those gates passed from this
pre-signing document alone.

The required completion checks are:

- Team `MVT4T97ZGC`, bundle `com.kairoid.Kairo`, appID `MVT4T97ZGC.com.kairoid.Kairo`.
- Associated domains exactly `["applinks:api.kairoid.com"]`; existing signing preserved.
- Production environment/configuration, Demo OFF, encryption declaration NO.
- Exact full source SHA, sourceClean=true; signature/resource seal valid.
- PrivacyInfo.xcprivacy exactly once and equal to certified source.
- Endpoint scan PASS on all actual signed app bytes, not just source/Simulator.
- Normal push to this branch only; local=remote, ahead/behind 0/0 and clean.

The task's A–T result is completed by the attestation: A starting SHA above; B final
SHA there; C branch above; D inventory above; E unconditional definitions despite
runtime gating; F/G/H preserved local/Staging/Production resolution; I/J byte
absence in the final signed app; K exact Production API; L scanner; M signed
artifact; N 145 checks; O 1,026 units; P/Q builds and analysis above; R no product
logic change; S final remote parity; T any remaining blocker in the attestation.

Original checkout preserved at `22d8c5988f7cd5ac4b0e9548216249a92bba674d` with the
same 19 modifications and unchanged index/diff fingerprints. Previous certification
worktree/report and Batch 1–4 branches are untouched. No backend, Android, deployed
Production, device installation, signing identity/provisioning change, main merge
or TestFlight upload is part of this task.

Once all post-commit checks pass, the narrow fix is ready to resume final release
certification. Full consolidated UI, physical, accessibility, archive/export and
Apple validation gates remain separate; this is not permission to upload.
