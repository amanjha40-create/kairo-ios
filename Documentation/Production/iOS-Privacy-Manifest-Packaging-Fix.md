# RC-PRIVACY-001 — app privacy manifest packaging

Classification: release infrastructure / packaging only. No Swift, UI, auth,
API contract, signing configuration, backend, Android or deployed Production
behavior changes. No TestFlight upload or main merge is authorized by this fix.

## Source boundary

- Base: `2417ab4bea023a970f90ce950e029a2a393f157a` (final Batch 4).
- Branch: `codex/ios-privacy-manifest-packaging-fix`, isolated clean worktree.
- The final source identity is the commit containing this report, not the base.
  A report cannot embed its own Git SHA. The clean-source provenance wrapper
  records the exact final SHA in the signed app and external JSON attestation.
- Historical dirty checkout, prior certification report and Batch 1–4 refs are
  protected. No reconciliation, reset, clean, stash or editing of those trees.
- Source version defaults remain untouched. Candidate archive overrides are
  version `1.0`, build `7`; no upload or build-number reservation is performed.

## Apple source of truth (reviewed 2026-10-21)

The current Apple DocC JSON for these pages was inspected, including its
`possibleValues` tables; the Markdown rendering omits those tables.

- [Required-reason categories, APIs and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Collected-data type definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype)
- [TN3183: adding required-reason entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [FileManager attributes](https://developer.apple.com/documentation/foundation/filemanager/attributesofitem(atpath:))

## Shipping required-reason inventory

Paths below are relative to `Kairo/`. The scan includes all app-owned Swift/C/
Objective-C source, including compiled fixture declarations, so a filename alone
cannot exempt new API use. No third-party package, embedded framework or app-owned
binary module is linked by this target. Apple system frameworks are not treated
as third-party SDKs whose internal implementation requires blanket declarations.

| File / use | Production | Purpose | Declaration |
| --- | --- | --- | --- |
| `App/AppAppearanceStore.swift`, UserDefaults | Yes | App-local appearance preference | UserDefaults `CA92.1` |
| `Features/GuidedTour/GuidedTourPreferences.swift`, UserDefaults | Yes | App-local per-account pending/completed tour state | UserDefaults `CA92.1` |
| `Features/Onboarding/ManualProfileDraftStore.swift`, UserDefaults | Yes | Local editable onboarding draft | UserDefaults `CA92.1` |
| `App/LocalBatch1QA.swift`, UserDefaults suite | Compiled; normal Production entry disabled | Lazy disposable preferences only behind local QA gate | Same app-only reason; no extra category |
| `Features/PermanentAddress/AddressLocationCollector.swift`, two `systemUptime` reads | Yes, explicit location-check action only | Measure elapsed collection window and reject clock discontinuities | SystemBootTime `35F9.1` |
| `Features/Onboarding/ResumeImportState.swift`, `.fileSizeKey`, `attributesOfItem` → `.size` only | Yes | Validate size of explicitly selected PDF/DOCX before copy/upload | No listed timestamp API accessed; no FileTimestamp declaration |
| `Core/Documents/SecureDocumentTransferClient.swift`, `.contentTypeKey` | Yes | MIME type of selected document | Not a required-reason API |
| `Features/Passport/PassportPDFExportService.swift`, `isExcludedFromBackup` | Yes | Exclude generated temporary PDF from backup | Not a required-reason API |
| File creation/modification dates, stat/fstat/lstat/getattrlist families | No app-owned occurrence | None | Not declared |
| Disk-space API family | No app-owned occurrence | None | Not declared |
| Active keyboard list API | No app-owned occurrence | None | Not declared |

`CA92.1` is limited to this app's own preferences, not MDM, shared app groups,
system settings, advertising or fingerprinting. The tour's account-derived key
stays local; it is not a cross-app identifier.

`35F9.1` covers elapsed timing inside this app. The collector's uptime values
remain in its local `AddressSampleWindow`; they are not fields of the Encodable
`AddressLocationSample` or upload request. Location evidence contains the chosen
CLLocation sample timestamp, coordinates and accuracy, not boot time. No claim
is made that the separately authorized location evidence stays on-device.

File-metadata determination: Apple's current table names specific timestamp
keys/properties and POSIX APIs; it does not list `.fileSizeKey`, `.size`, or the
general `attributesOfItem` method. This code only extracts size and never reads
the returned timestamp keys. No app-owned stat-family symbol was found in the
baseline executable. Do not add `3B52.1` merely because the method returns a
dictionary that could contain timestamps. If timestamp access or direct stat
use is introduced later, re-audit; user-granted picker access would then make
`3B52.1` a candidate, not a blanket authorization today.

## Collection and tracking audit

`NSPrivacyTracking=false`; tracking domains are empty. No advertising SDK,
IDFA, cross-company tracking, device fingerprinting or tracking-consent code was
found. SwiftUI `.tracking` is typography, not telemetry. This is NOT a claim
of zero collection. Authentication and authorized product workflows send and
retain account-linked information at KairoID services.

Each declared type is linked to the user, not used for tracking, and used for
App Functionality. The declaration covers optional workflows too; it does not
assert every user supplies every type. Evidence is shipping DTO/service behavior
and the existing website privacy policy (`src/routes/privacy.tsx`, sections
2–7). That cross-product policy mentions website GA4; it is not evidence of a
native GA SDK and no native advertising/analytics purpose is invented here.

| Collected type (Apple suffix) | Evidence / product purpose |
| --- | --- |
| Name, EmailAddress, PhoneNumber | Auth DTOs, Profile update and contact verification; account and identity functionality |
| PhysicalAddress | PermanentAddressService address submission and selected address evidence |
| OtherUserContactInfo | Profile professional/social links in ProfileDomain/ProfileService |
| PaymentInfo | Explicit Bank statement evidence supported by CareerDocumentService can contain bank-account information; Apple includes this type even without payment processing |
| OtherFinancialInfo | Explicit employment Payslip evidence supported by CareerDocumentService; salary-bearing documents, not payment processing |
| PreciseLocation | Explicit foreground PermanentAddressService location evidence; no automatic/background collection |
| CoarseLocation | User-entered profile city/region/country and professional location fields |
| PhotosorVideos | User-selected profile avatar and image evidence; no blanket photo-library access |
| CustomerSupport | Explicit Support/Report an issue mail composer handoff and messages voluntarily sent to support; no automatic diagnostic attachment |
| OtherUserContent | Resume, Career/Education/Certification/Project records, uploaded evidence, review answers, share purpose |
| UserID | Canonical Candidate/account identity and authenticated account-linked operations |
| ProductInteraction | Persisted consent, verification/import/share actions and notification-read state; functional audit/state, not advertising profiling |
| OtherDataTypes | Date of birth, identity-document attributes and verification outcomes not covered by the more specific types above |

Not declared without a shipping collection path: health/fitness, credit score
(Trust Score is not credit), purchases, audio, games, address
book/social-graph import, browsing/search history, advertising/device IDs,
biometric/sensitive-category inference, environment scanning, hands/head.
Documents are not assumed to collect every imaginable sensitive category simply
because arbitrary file bytes could contain it.

NetworkDiagnostics is DEBUG-only. GoogleReturnDiagnostics writes sanitized local
OSLog events; there is no native remote crash/performance telemetry SDK or upload
path. Local logs alone are not a remote diagnostic-data collection declaration.
This manifest is not an edit to App Store Connect privacy labels or legal policy.
Read-only App Store Connect inspection on 2026-10-21 showed App Privacy still
at **Get Started**, with no Privacy Policy URL configured. No established App
Store disclosure answers exist to copy. Completing those labels and the policy
URL is a separate pre-public-release task, not performed here. TestFlight still
lists builds 1–6 only; build 7 remains unused at this checkpoint.

## Packaging and regression contract

Manifest: `Kairo/PrivacyInfo.xcprivacy`. The app target already owns the
`Kairo` PBXFileSystemSynchronizedRootGroup, with no membership exceptions.
No `.pbxproj` edit is necessary. Actual bundle checks, not this source claim,
are the packaging gate.

`BuildTools/privacy_manifest.py` verifies the source inventory, exact reviewed
schema/reasons/data policy, synchronized membership, lack of new dependencies,
and recursively scans a supplied `.app`/`.xcarchive`. It requires one app-root
manifest, rejects unaudited nested manifests/frameworks, and compares parsed
plist content (Xcode may change XML/binary serialization). With `--require-signed`
it verifies the strict signature, official team and manifest resource-seal entry.
This lexical tripwire supplements human audit; it is not a complete static
analyzer or proof of future backend retention practices.

Negative tests cover missing source/target/artifact, nested-only manifests,
malformed plist, unknown/blanket/misassigned reasons, new API use, unused
categories, every omitted collected type, false tracking/linkage/purposes,
unreviewed types, private fields/comments, unsigned artifacts and source drift.

## Validation ledger

Pre-commit results on the unchanged product source plus this manifest:

- Focused manifest checks: **27/27 PASS**.
- Full privacy/provenance/icon suite: **129/129 PASS**, no skips when run with
  `KAIRO_ICON_APP_PATH` pointing at the new device bundle.
- Full unit/integration suite: **1,026/1,026 PASS**.
- Affected UI sanity: **4/4 PASS**: appearance persistence, tour completion
  persistence, scrolled light and dark safe-area screens.
- Combined xcresult: **1,030 passed, zero failed/skipped/runtime warnings**,
  iPhone 17e iOS 27.0 Simulator, Staging test configuration.
- Production device build: **PASS** (pre-commit unsigned packaging check).
- Production Simulator build + static analysis: **PASS**, strict concurrency
  complete. Existing actor-isolation/compiler warnings remain; this is not a
  warning-free or Swift 6 migration claim. No product correction was made.
- Both actual built apps contain one valid app-root manifest equal to the
  certified source. Xcode's `CpResource` confirms automatic resource membership.
- `git diff --check`: **PASS**.
- Protected original: same 19 modified files, HEAD, index and binary diff hashes;
  original staged diff still empty. Prior certification report remains untouched.

Evidence: `/private/tmp/kairoid-privacy-tests.xcresult`,
`kairoid-privacy-tests.log`, `kairoid-privacy-production-device-final.log`,
`kairoid-privacy-production-sim-final.log`, and `kairoid-privacy-python-final.log`.
The final collection cross-check also identified explicit Bank statement uploads;
PaymentInfo is therefore included for bank-account details, without claiming
payment processing. The earlier archive attempt was stopped before completion
and has no successful provenance sidecar. It is superseded, not a release artifact.

Post-commit signed-artifact proof and the completed A–V handoff are retained
beside the exact-SHA archive, outside source: changing this report after signing
would change the attested SHA. The final handoff must independently confirm
the following gates before declaring READY; pre-commit PASS is not substituted
for signed-artifact or remote-parity proof.

Exact-source archive gate (after commit):

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 BuildTools/provenance.py build \
  --configuration Production --sdk iphoneos --team MVT4T97ZGC \
  --action archive --version 1.0 --build-number 7 \
  --output /private/tmp/kairoid-privacy-final-certified-1.0-7
/usr/bin/python3 BuildTools/privacy_manifest.py \
  --artifact /private/tmp/kairoid-privacy-final-certified-1.0-7/KairoID.xcarchive \
  --require-signed
```

Required final artifact facts: exact clean HEAD; official Team MVT4T97ZGC;
bundle com.kairoid.Kairo; Production / Demo OFF; associated domain unchanged;
encryption-exemption declaration false; manifest valid and sealed; icons,
provisioning and version/build metadata valid. Local Apple validation is a
precheck, not App Review acceptance. No candidate may be uploaded from this task.

Remaining program gate after this fix: resume consolidated release certification
on the NEW SHA. Prior Batch 4 physical evidence is preserved, not relabeled as
fresh physical certification of a new source commit.
