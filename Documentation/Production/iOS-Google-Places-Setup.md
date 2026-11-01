# iOS Places Configuration

## Scope

Based on `acd722dc248e5c358746ec5e1eecb002a1cecfe2` on
`codex/ios-v1-0-1-feature-parity`. That source had manual Permanent Address
entry, but no Places SDK or place-ID submission. This integration adds only
the missing native address search and request configuration.

Google's official `ios-places-sdk` is pinned to 11.2.0 through Swift Package
Manager. The app uses GooglePlacesSwift and its native autocomplete widget,
which supplies attribution, session handling, and search/no-results UI.
No Maps SDK or phone-side Geocoding API is used.

## Credential

- Project: `kairoid-production`
- Key display name: `KairoID iOS Places Production`
- Application restriction: iOS; only `com.kairoid.Kairo`
- API restriction: only Places API (New)

Production's base configuration is `Configuration/Production.xcconfig`.
It optionally includes ignored `Configuration/ProductionSecrets.xcconfig`.
Use `Configuration/ProductionSecrets.example.xcconfig` as the placeholder.
The only credential setting is `GOOGLE_PLACES_API_KEY`. CI must materialize
the ignored file from its secret store, with owner-only access, before a
device build or archive. Never supply the key as a visible command argument,
commit it, or publish raw build logs/build-setting dumps. Xcode may expand
build settings into logs. Restrict build artifacts/logs accordingly.

Only `Kairo-Production-Info.plist` substitutes `$(GOOGLE_PLACES_API_KEY)`.
Bootstrap validates configuration and initializes the SDK once. Missing or
invalid configuration disables search with an explicit message; manual
entry remains available. Development/Staging do not include this file and
cannot silently borrow Production. A future Staging key needs its own
explicit configuration, not reuse of Production.

A mobile key is extractable from a distributed app. Bundle/API restrictions
are the security boundary; an ignored file prevents accidental source leaks
but does not make a shipped mobile credential confidential.

## Address Flow

The candidate explicitly opens Google's widget, optionally seeded from the
existing Driving Licence draft. Selection fetches only place ID and address
components, not coordinates. Fields populate the existing editor. A transient,
non-Codable selection binds the ID to that exact draft. Editing any mapped
field makes the draft use the manual path without a place ID. The candidate
must explicitly Save in either case. Neither DigiLocker prefill nor Google
selection saves automatically.

`PermanentAddressSaveRequest` sends the existing flat claimed-address fields
and optional `google_place_id` to the existing authenticated PUT endpoint.
No client coordinates are included. Server resolution, target encryption,
document checks, and GPS capture remain unchanged. Place IDs are not added
to response models, local persistence, analytics, or logs. Closing the editor
cancels pending detail loading and discards its selection.

## Privacy And Release Gates

The app-owned privacy declaration is unchanged. Places 11.2.0 includes two
SDK-owned manifests. GooglePlaces declares FileTimestamp (C617.1), UserDefaults
(1C8F.1/CA92.1), and unlinked, nontracking DeviceID collection for analytics
and app functionality. GooglePlacesSwift's manifest has empty declarations.
The privacy gate checks these exact declarations and packaged paths; new
SDK versions, declarations, missing manifests, or other SDKs fail closed.
Before a future App Store upload, reconcile these vendor disclosures with
App Store privacy answers. This task does not edit the submitted Build 16
or upload a new build.

Run the full unit/networking suite, simulator UI checks, the BuildTools
privacy/provenance suite, strict-concurrency Production device build, and
`git diff --check`. A local build alone is not physical certification.

Physical certification requires the controlled candidate to search/select,
review and explicitly save a safe address, exercise the DRVLC Use/Edit path
if available, and confirm manual fallback. Do not record addresses, place IDs,
credentials, coordinates, or invitation tokens in test reports. GPS can only
be certified while the tester is physically at the saved address.

## Universal Links

Production already includes `applinks:kairoid.com`; its existing API domain
is retained. Website AASA authorizes only `/invite/*` for
`MVT4T97ZGC.com.kairoid.Kairo`. A physical check must open a controlled real
link from a suitable external context and confirm the native authoritative
invitation screen. A successful HTTP AASA check alone is not that proof.

## Validation On 2026-11-02

- Full iOS unit/networking suite: 1,150 tests, zero failures; includes seven new
  Places tests and existing invitation parsing/routing tests.
- Offline BuildTools suite: 161 tests, zero failures, one existing skip.
- Permanent Address simulator UI suite: seven tests, zero failures, one
  physical VoiceOver test skipped. Missing search configuration keeps manual
  fields usable, with Save disabled until the address is valid.
- Production simulator and signed device builds: pass with complete strict
  concurrency checking. Existing test-target concurrency warnings remain;
  this is not a Swift 6 language-mode migration.
- Production artifact embeds the configured key; Development omits it.
- Signed device privacy verification: pass, with all three exact manifests.
- Live AASA: HTTP 200, application/json, no redirect, exact invite-only scope.
  Apple's association CDN also returns the same correct configuration.
- The signed local QA build was installed on the paired founder iPhone 11.
  This is a developer build, not a release-attested archive or upload.
- Physical search/save, DRVLC, Universal Link, and GPS outcomes must be
  recorded separately from these automated results.

**Unresolved release gate:** the unchanged `endpoint_scan.py` flags
`localhost` and `127.0.0.1` in both Production executables. These exact strings
also occur in the pinned upstream GooglePlaces static library. The app's
Production API policy still compiles only the canonical Production backend.
No scanner bypass/allowlist was added. A dependency-aware review of this
release gate is needed before any future release certification/upload.

Official references:
- https://developers.google.com/maps/documentation/places/ios-sdk/config
- https://developers.google.com/maps/documentation/places/ios-sdk/place-autocomplete
- https://github.com/googlemaps/ios-places-sdk
