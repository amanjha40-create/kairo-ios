# iOS Android post-parity Batch 1 certification

Certified source is frozen on `codex/ios-android-batch-1-mirror`, descending
from `f4f100b5180fde098882a57bc09b6c7189704a30` and preserving the prior
Guided Tour, Welcome, accessibility and device-fix lineage.

## Scope

- DigiLocker ASWebAuthenticationSession completion return and same-Hub refresh.
- Backend-authoritative connection state and preserved verification history.
- Explicit consent, selection reset and accessible consent presentation.
- Neutral Skills, Certifications and Projects presentation.
- Login single-Back correction and certified UI-test fixture corrections.

## Completed gates

- Unit: 756/756 PASS.
- UI: 245/245 PASS; zero skipped.
- Provenance: 38/38 PASS.
- Xcode Staging analysis: PASS with strict concurrency set to complete.
- Git diff whitespace check: PASS.
- Physical iPhone return, same-Hub navigation and authenticated post-return
  reads: PASS; relevant reads returned HTTP 200.
- Server truth, consent normal/XXXL/VoiceOver, optional-record presentation,
  Android compatibility and Admin Company 360 smoke: PASS.
- Normal signed-in Home restored; remaining Batch 1 blocker: none.

The freeze operation does not change certified application/test source. Detailed
local evidence and generated artifacts are deliberately excluded from Git.
This commit records tested source; it does not claim a newly rebuilt or installed
binary bearing this commit's embedded SHA.

## Diagnostic safety

Authenticated-read QA requires the explicit DEBUG diagnostic compiler flag,
Staging configuration/environment, the exact Staging API, Demo disabled and
explicit diagnostic launch settings. Normal project/scheme settings do not
enable that compiler flag. Production cannot activate it. The adapter permits
only the three approved authenticated GET routes and blocks credential writes.
Synthetic return fixtures require Staging and validated UI-test activation;
Production rejects UI-test activation. No fixture is enabled on normal launch.

No credentials, private account data, device identifiers, local filesystem paths,
private logs or result bundles are included in this note.

## Backend support and next-phase references

Batch 1 historical Staging support: API234, backend
`aa402fd2d0395d47a9c2a1c174d66f2c250810a6`.
No backend inspection, change or deployment is part of this freeze operation.

User-supplied read-only Batch 2 inputs:

- Android: `899c625463e23be0904b239f5330413dd3c6825b`.
- Backend: `36a1aea486a92d339e0d58678bd83455b522e3ab`.
- Staging reference: API235; database reference: 084.

Create `codex/ios-android-batch-2-mirror` from the exact resulting Batch 1
certification commit. No Batch 2 implementation or push is part of this operation.
