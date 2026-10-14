# iOS Permanent Address V1 — certified Staging scope

Starting iOS SHA: `142e28bdac6d2f0aa98c2cb5c6ab9be7a0af7035`.
Android reference: `49130a95582e977e568b191bc55c9956f809887e`.
Branch: `codex/ios-current-android-parity`.

Final result: address UI, foreground Core Location collector and private document flow implemented; synthetic physical certification PASS. Full unit 813/813, provenance/privacy 46/46, all four build configurations and Staging analysis PASS. Complete UI coverage is 266 uniquely passing methods after scoped test corrections plus one physical-only VoiceOver skip; physical suite 22/22 PASS. Backend authority, version invalidation, document/location separation, dark XXXL and actual VoiceOver speech are covered. No real GPS batch or real document upload was performed; those remain separately authorized live gates. See `ios-current-android-parity.md` for final evidence, test exceptions and retained failures; progress notes below are historical.

## Candidate surfaces and authority

Home, Verify and Profile link to one native Permanent Address sheet; Passport shows a summary only for backend `PERMANENT_ADDRESS_VERIFIED`, without private address detail. A secondary address read failure cannot fail the Home aggregate. Structured address PUT uses the exact `address_line_1`/`address_line_2` keys (explicit encoder, round-trip tested).

Document, 0–3 location progress, and overall verification are separate. Neither Approved document nor 3/3 alone computes Verified locally. All three remain backend-authoritative. Address version change immediately drops prior document state; no Approved UserDefaults/cache. Source has no score calculation, Admin endpoints/diagnostics, reviewer identity, target coordinates or storage paths in UI.

## Foreground collector

Core Location requests When In Use plus existing precise-location permission. No Always request, background location mode or significant-change monitoring. Explicit requestLocation priming is excluded, along with the rest of that callback. Only subsequent streamed measurements are considered.

- Fresh measurement: on/after request and stream start, not future, at most 3 seconds old.
- Finite positive accuracy, evidence <=50m; simulated source flag preserved for the entire batch.
- Distinct samples spaced >=6 seconds; >=5 samples spanning >=30 seconds; <=10 samples.
- Monotonic total acquisition limit 60 seconds, including priming; wall/uptime discrepancy >2 seconds is rejected conservatively.
- These are capture-quality guards, not local radius/match/target/verification decisions.
- Native stream stops before returning samples, including success/needs review/failure/timeout/cancel/inactive or locked screen. Permission failure also releases the manager. Challenge cancellation is best-effort once and does not inherit a cancelled collection task; ambiguous complete is not replayed.
- Callback manager identity and operation/store generations discard late results. No coordinates/challenges are logged, cached or persisted.

Intentional native difference: Android has measurement elapsedRealtime; CLLocation provides measurement Date. iOS combines measurement time with monotonic acquisition time and conservative clock-jump checks rather than pretending identical APIs. Native API references: [CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager), [accuracyAuthorization](https://developer.apple.com/documentation/corelocation/cllocationmanager/accuracyauthorization).

## Document lifecycle

GET policy and exact-version document → native Files selection → private upload-intent → credential-free ephemeral HTTPS storage PUT → checksum-bound complete-upload → Uploaded → explicit current-address confirmation → submit → authoritative review refresh.

Supported policy MIME subset is PDF/JPEG/PNG/WebP with server maximum size/type/issue-date requirements. No autosubmit on file selection/upload. Auth/cookie/proxy-authorization intent headers are rejected; signed URL stays transient. Existing secure transfer is reused, not a new storage contract. Selection is released after completion/disappearance/version change. Upload failure is retryable but never optimistic approval.

Required, upload incomplete, Uploaded, Under review, Approved, correction, Rejected and replaced states map from backend values. No document attachment is added to Passport or Document Packs. Approved remains visually separate from GPS progress and overall status. No Aadhaar integration is added (Android's “Aadhaar is not required” privacy copy is retained).

## Validation / physical boundaries

- Final-source full unit: 813/813 PASS, including sampling/priming/clock/freshness/spacing, denial/disabled/timeout/cleanup, in-flight cancellation, server Needs review, exact structured keys, document consent, upload failure, invalidation, mocked secure-upload tests and unchanged-address save completion without approval invalidation. Final full UI gate is running; Cancel location is tied only to an actual location operation, never document upload.
- Offline provenance/privacy: 46/46 PASS; only When In Use plist key, no background mode, no private source logging/persistence, no Candidate invite/Admin routes, explicit Staging fixture gate.
- All 11 new parity UI tests passed. Full UI regression remains running with one existing Help Center keyboard-interaction failure under investigation.
- Founder-observed iPhone 11 fixture checks passed: Required/0 of 3; 1 of 3; Approved document with 0 of 3 still not verified; backend Verified/3 of 3; Under review, Needs correction, Rejected and explicit Uploaded consent → review; offline/denied/disabled/timeout safe errors and usable Done; unchanged-address save preserving approval; material synthetic address edit clearing approval/progress; native picker open/cancel; dark-mode readability. No real file was selected. XXXL/VoiceOver checks are moving to automated physical XCTest at the founder's request.
- Fixture harness never opens selected file bytes or calls network/Keychain/Core Location. Real upload transport is tested separately with a locally generated synthetic PDF and intercepted URLSession. Physical fixture actions are not claimed as live backend validation.
- No real GPS batch, address edit or founder document upload. User-reported real state (document Required, GPS0/3, needs review, no targets, Trust82) is preserved; it has not been independently re-queried to manufacture a validation claim.
- No backend/Android/Admin/HR/Production modification. No commit/push while certification remains incomplete.

Final corrected-source physical suite: 22/22 PASS. Address/document status separation, explicit consent disabled/enabled state, safe failure/timeout UI, unchanged-address preservation, dark XXXL controls and real VoiceOver speech passed. The new address surface uses the existing adaptive brand tint. The normal installed app was relaunched without fixture arguments afterward, and VoiceOver was restored to disabled. No real GPS collection, address write, file upload or verification occurred. Complete Simulator regression is still pending; one speech check is explicitly physical-only because Simulator speech service is intermittent, not represented as a Simulator pass.
