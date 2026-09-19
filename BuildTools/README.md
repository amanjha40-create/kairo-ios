# KairoID iOS candidate provenance

Release infrastructure only. No app Swift files, screens, entitlements, API calls or
runtime configuration behavior are changed. No Git ref is embedded: the full SHA is
sufficient and avoids disclosing internal branch names.

## Two build modes

Normal Xcode Build/Test remains a developer workflow. `KAIRO_PROVENANCE_REQUIRED=NO`
uses the committed **unattested sentinel**, never a committed SHA. The packaging
phase removes any previous candidate resource. A normal build is not an attested
release candidate and the candidate verifier rejects it.
Archive (`ACTION=install`) always requires candidate metadata: a normal GUI archive
without the controlled input fails closed rather than producing an unstamped archive.

Candidate builds must use the wrapper from a clean, committed worktree:

```sh
/usr/bin/python3 BuildTools/provenance.py build \
  --configuration Staging --sdk iphoneos \
  --team APPROVED_TEAM_ID --output /private/tmp/NEW_CANDIDATE_DIRECTORY
```

Use an existing approved development signing team only. The wrapper does not pass
`-allowProvisioningUpdates`, obtain credentials, or change signing material. Omit
`--team` for unsigned compilation/packaging validation. Simulator candidates use
`--sdk iphonesimulator` without a team. Use `--action archive --sdk iphoneos` for an
archive; unsigned archives are permitted for metadata tests but are not distributable.
No archive/export/upload is implicitly performed by `build`.

`--version` and `--build-number` are optional numeric Xcode-setting overrides. The
wrapper resolves actual app target settings and validates the final bundle against
the generated manifest, rather than treating source defaults as final values.

The output directory must be new and outside source. It contains derived data,
the generated input plist, private local Xcode build log, and a non-secret JSON
artifact record. Do not publish the raw Xcode log: it is not a sanitized attestation.

## Exactness and sandboxing

The wrapper checks Git HEAD plus staged/unstaged/untracked state, rejects ignored
files inside build-input roots and rejects gitlinks/source symlinks. External Git
directory/index overrides and `XCODE_XCCONFIG_FILE` are rejected. Linked worktrees and detached
HEAD are supported. Candidate construction must not run concurrently with source
editing or checkout changes. HEAD and cleanliness are checked before/after build.
This is an operational clean-source gate, not protection against a malicious builder
that temporarily alters inputs and restores them. Use a trusted isolated CI checkout
and signed external attestations for stronger supply-chain guarantees.

Only six allowlisted scalar fields enter the bundle. SHA is full 40-character hex;
versions are numeric; configuration/environment use finite enums; clean is Boolean
true. No username, paths, remote URLs, credentials, branch, timestamps or signing
identity are embedded. Ordinary compiler debug information is outside this metadata
claim. Toolchain version and a basename-only artifact reference enter the sidecar.

Xcode's script sandbox remains enabled. Declared inputs: generated plist (or developer
sentinel) and this script. Declared output: the bundle's KairoBuildProvenance.plist.
The phase runs every build, before code signing, and does not read Git or the source
tree. Candidate metadata is compared with the expected SHA and current resolved
settings. Missing/malformed/stale data fails. The old output is removed first when
the phase runs; a missing declared input may instead stop Xcode before the phase.
In either case no successful candidate/sidecar is produced. Never distribute a
leftover product from a failed build.

Each wrapper run uses fresh derived data. Unit tests also exercise repeated packaging
into one bundle to cover SHA/configuration/version changes and candidate-to-developer
transitions. No generated build-specific plist is checked into Git.

## Verify .app or .xcarchive

```sh
/usr/bin/python3 BuildTools/provenance.py verify /path/to/Kairo.app \
  --expected-sha FULL_CHECKED_COMMIT_SHA --configuration Staging --require-signed
```

The verifier checks schema, clean status, expected SHA/configuration, final Info.plist
version/build/environment/configuration/Demo values, resource placement and (when
requested) strict code-signature validity with non-ad-hoc team signing and the exact
resource SHA-256 in the signed resource seal. It prints
only allowlisted provenance. It does not install, launch, call APIs or alter artifacts.

The JSON sidecar's `appBundleTreeSHA256` is a deterministic length-prefixed
relative-path/size/content digest of all app files, including signature files. It
is **not** an IPA hash, code-directory hash or a reproducible-build guarantee.
Retain the sidecar beside the actual artifact; do not treat an editable unsigned
JSON record alone as cryptographic source attestation.

## Archive/export/TestFlight

Packaging runs for Build and Archive, before signing. Never modify provenance after
signing. For later IPA export, unpack privately and run the same verifier on its
Payload app. Disable automatic version/build-number management during distribution,
or fail verification and rebuild with the intended values. Never silently patch the
manifest to match an export-time version change. TestFlight processing may change
binary/signature bytes; do not equate its final checksum with the archive checksum.
Retain source SHA, version/build mapping and distribution records. No TestFlight
upload or Production signing is authorized merely by this documentation.

The installed development app's bundle resource can be read through development
debugging tools without adding UI. Release/TestFlight on-device full-SHA visibility
would require a separately approved diagnostic UI; version/build can be correlated
with the retained distribution record in the meantime.

## Validation

```sh
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover -s BuildTools -p 'test_*.py' -v
```

Then run the complete existing Xcode Test action, all four configuration builds,
strict concurrency and iOS 17 compile. Commit the infrastructure change only after
regressions pass; build the final clean candidate from that new committed SHA.
Verify an unsigned archive and signed Staging app separately. Physical Staging
smoke is read-only: no upload/import/delete, logout, account changes or new shares.
