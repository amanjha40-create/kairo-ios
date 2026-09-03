# Kairo iOS Internal TestFlight Release Plan

## Candidate identity

- Bundle identifier: `com.kairoid.Kairo`
- Marketing version: `1.0`
- First build number: `1`
- Archive configuration: `Production`
- Production API: `https://api.kairoid.com/api/v1`
- Demo mode: disabled

Before a later upload, increase `CURRENT_PROJECT_VERSION` monotonically (`1`, `2`, `3`, ...). Keep `MARKETING_VERSION` at `1.0` until the product version changes. Apple uses the bundle identifier, version, and build string to associate an uploaded build, so every accepted replacement build needs a new build number.

## Founder decisions required before the first upload

1. Select the first internal TestFlight backend:
   - Recommended: a dedicated release-optimized internal-TestFlight configuration that points to Staging. Staging has the validated 6A–7A coverage and limits tester risk.
   - Production-backed TestFlight should wait for Production parity validation and an approved stable Public Passport host.
   - Do not reuse the current `Staging` configuration for distribution unchanged because it inherits debug-style project settings. Do not point a `Production` archive at Staging through a launch environment override.
2. Approve a practical minimum iOS target. The project currently declares iOS 26.5. Source compatibility must be verified before lowering it; a lower target increases tester coverage.
3. Confirm whether V1 intentionally supports both iPhone and iPad, and portrait plus landscape. The project currently advertises all of those modes.
4. Configure the Apple Developer Team and Xcode-managed signing for `com.kairoid.Kairo`. A TestFlight build needs an App Store distribution identity and a provisioning profile containing the application identifier.

## App privacy inventory

The bundled privacy manifest declares data handled by the native app for app functionality as linked to the user and not used for tracking:

- name
- email address
- phone number
- manually supplied coarse location such as city/country
- account/user identifier
- verification-recipient contact information
- other user content, including résumé, Career, education, certification, project, skill, document/evidence, and verification inputs

Backend-derived Trust Passport and verification state are displayed by the app as product functionality. The source contains no advertising or tracking SDK, device-ID collection, native usage analytics, crash-reporting SDK, or protected API access for contacts, Photos, camera, microphone, precise device location, health, or financial information.

Local handling:

- access, refresh, and signup-session credentials are stored in Keychain
- an in-progress manual-profile draft is stored in app-only `UserDefaults`
- imported résumé and exported PDF artifacts use temporary files and are cleaned up
- a Passport capability URL is written to the pasteboard only after the user invokes Copy Link

No data is used for cross-app tracking. The App Store Connect privacy questionnaire must be reconciled with the deployed backend and its service providers before public submission; this file is a source-derived draft, not a submitted legal declaration.

## Export compliance and transport security

The native source uses Apple-provided HTTPS/TLS, Keychain APIs, and CryptoKit SHA-256 hashing for upload integrity. It contains no custom encryption implementation. `ITSAppUsesNonExemptEncryption` is therefore set to `NO` based on the current source audit. Re-audit this value if a cryptographic library or encrypted communication implementation is added.

Production uses HTTPS and the app declares no broad App Transport Security exception.

## Entitlements and capabilities

No entitlement file or optional Apple capability is currently enabled. Associated Domains remains intentionally deferred because there is no approved stable branded domain or deployed AASA file. Universal Link routing code is ready, but OS-level Universal Link activation is not part of this build. Push Notifications, Sign in with Apple, App Groups, iCloud, background modes, and shared Keychain groups remain disabled because the app does not currently require them.

## Internal TestFlight description draft

**Kairo Candidate iOS — internal V1 testing**

This internal build covers candidate authentication and onboarding, résumé import, Career records, verification initiation and status, Trust Passport, Passport share management and activity, Public Passport routing, PDF export, account settings, password recovery, and account deletion.

Production behavior has not yet been declared validated. Use only the backend environment explicitly selected for this build.

## Tester focus draft

- Complete signup, verification steps, sign-out/sign-in, and password recovery.
- Import a supported résumé and confirm review, recovery, and Career results.
- Create, edit, and remove disposable Career records.
- Start verification only with approved disposable data; confirm truthful pending/verified semantics.
- Create exactly one disposable Passport share, verify its permission scope and activity, then revoke it.
- Verify Public Passport privacy boundaries and revoked-link behavior only through the approved test environment.
- Export and preview a Passport PDF, then dismiss/share it without retaining private artifacts unnecessarily.
- Review settings, session management, and account deletion using only disposable accounts.
- Report the build number, device model, iOS version, reproduction steps, and a redacted screenshot. Never include passwords, OTPs, session tokens, or Passport capability URLs.

## Tester account strategy

Do not bundle credentials. For the first internal Staging-backed build, provide dedicated disposable QA actors privately to named internal testers, or allow normal Staging signup only when OTP delivery is proven reliable. Keep Production accounts and real candidate records outside internal destructive testing. Rotate or delete disposable actors after each controlled test cycle.

## Pre-upload checklist

- [ ] Founder approves backend strategy.
- [ ] Founder approves minimum iOS target and device/orientation scope.
- [ ] Apple Developer Team is selected for the app target.
- [ ] `com.kairoid.Kairo` is registered to that team.
- [ ] Apple distribution certificate and App Store provisioning resolve automatically in Xcode.
- [ ] Version/build is unused in App Store Connect.
- [ ] Production or dedicated internal-TestFlight environment is independently validated.
- [ ] Privacy disclosures are reconciled with backend/service-provider behavior.
- [ ] Signed archive passes Xcode validation and local non-uploading export.
- [ ] No App Store Connect upload occurs without explicit founder approval.
