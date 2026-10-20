# Local Education Audit Harness Diagnosis

Historical checkpoint: the subsequent backend audit and API43 fix supersede the import-unknown status below. See `iOS-Production-Bugfix-Batch1.md` for current closure evidence. This document retains the earlier local harness diagnosis and does not authorize any new Production task.

Status: **HARNESS_FIXED_AND_LOCALLY_CERTIFIED**

Date: 2026-10-21 (Asia/Kolkata). Scope: offline harness diagnosis only.

The Production Education import remains **UNKNOWN_WITH_CURRENT_EVIDENCE**. This report certifies the local harness, not the failed import, the Production account, or a new application release.

## A–O checkpoint

| Item | Result |
| --- | --- |
| A. Failed audit task | `1f85f5a2a8d64640a98ccff67b6abe36`; prior task stopped exit 1 |
| B. Proven local TypeError | `Object of type bytes is not JSON serializable` |
| C. Failing line/module | Unchanged embedded audit `CODE`, line 81; outer `/private/tmp/kairoid-education-forensic-once.py:91`, final `json.dumps(out, ...)` |
| D. Local reproduction | PASS: unchanged audit code against synthetic PostgreSQL rows reproduces exit 1 and the TypeError |
| E. Harness correction | Convert PostgreSQL internal constraint-type bytes to fixed category names; project all output through a closed allowlist; sanitize exception output |
| F. Files changed | New local harness/reproduction/tests listed below; this report only in the iOS worktree |
| G. Privacy allowlist | Fixed field names, present/absent/null, known validation/constraint categories, fixed code paths, booleans and read-only status |
| H. Privacy-negative tests | PASS; institution/degree/date/email/phone/resume/document/token/UUID/DB-URL/password sentinels absent from output |
| I. Local read-only transaction | PASS: default and explicit transaction read-only both on; end-of-inspection still on |
| J. Mutation denial | PASS: INSERT, UPDATE, DELETE each rejected with SQLSTATE 25006; count unchanged |
| K. Synthetic classifications | PASS: required field, date, enum, backend schema, DB constraint, duplicate conflict; valid/insufficient evidence remains unknown |
| L. One-shot rehearsal | PASS: `python -c` packaged entrypoint exits naturally 0, emits one read-only proof and one sanitized report; no external network or application mutation-service calls |
| M. Backend/iOS product source changed | NO |
| N. Production accessed this task | NO: no AWS API, Production DB, provider request, import replay, or login |
| O. Final status | **HARNESS_FIXED_AND_LOCALLY_CERTIFIED** |

## Exact local failure

The original metadata query selects `pg_constraint.contype`, whose PostgreSQL type is internal `"char"` (not ordinary SQL `char(n)`/text). In the local asyncpg runtime, its Python value is `bytes`.

The original code placed that value unchanged in:

`out["education_constraints"][...]["type"]`

The final JSON encoder rejects the bytes object. Local tracing of the unchanged embedded code captured:

- function `main`, embedded line 81;
- exception `TypeError`;
- exact message `Object of type bytes is not JSON serializable`;
- handler output `EDUCATION_AUDIT_FAILURE=TypeError`;
- inspection exit 1.

The source of the raw bytes is outer script line 87; the failing serialization is line 91. This is a JSON-serialization defect involving schema metadata, not SQLAlchemy row mapping, UUID conversion, an async/sync mismatch, or a nullable resume value.

**Historical evidence limitation:** the failed Production task retained only the exception class, not a traceback. The local reproduction proves this deterministic defect in the unchanged harness. It does not retrospectively prove that no other earlier TypeError could have occurred in that task. No claim is made about which private field caused the actual Education import failure.

## Correction and output safety

The narrow TypeError correction maps internal codes such as bytes `p`, `f`, `u`, and `c` to fixed strings `primary_key`, `foreign_key`, `unique`, and `check`. Unknown codes become `unrecognized`.

Additional requested safety hardening:

- No `default=str` fallback: arbitrary objects cannot be stringified into logs.
- No raw catalog constraint/index names in the final output, even though safe schema names were permitted.
- Pydantic input, message, context, and arbitrary location/error strings are not emitted.
- Only known Education field names and validation categories survive projection.
- Exception messages are never printed. Exception class names are allowlisted; unknown classes become `unrecognized_exception`.
- Unknown object/field/type information cannot escape through a generic serializer.
- Read-only proof is emitted immediately after checking both default and transaction settings, before payload analysis.
- A malformed synthetic payload exits 1 with a sanitized category and no private values or stderr traceback.
- The local entrypoint contains no AWS launcher and no Production connector. Its connection adapter accepts only the temporary Unix socket. TCP, DNS, urllib/provider access and subprocess creation inside the inspection process are blocked.

## Local fixture and read-only evidence

A disposable PostgreSQL 16.14 cluster was initialized under:

`/private/tmp/kairoid-education-local.8tNWrs/pgdata`

It listened only on the directory's Unix socket, with `listen_addresses=''`; host authentication was rejected. There was no TCP listener.

Synthetic fixture setup and isolated persistence probes used only this local database. The audit itself used `default_transaction_read_only=on`, an explicit `transaction(readonly=True)`, and SELECT/SHOW statements. Nested savepoints permitted testing all three denied DML statements without losing the read-only outer transaction. Successful synthetic construction and deliberate constraint probes were rolled back.

Final read-only inspection proof:

- default_transaction_read_only: on;
- transaction_read_only at start: on;
- transaction_read_only at end: on;
- INSERT/UPDATE/DELETE: each denied, SQLSTATE 25006;
- no data-count change from denied mutations.

The temporary PostgreSQL instance was stopped after testing. Its disposable local files remain for reproducibility; no service or schedule was created.

## Exact API42 path rehearsal

Read-only Git snapshot: `ee9220e7367d994c9d4e1597f1ae00c14355f859`.

Inspected/exercised rules:

1. `ResumeReviewService._import_item` validates the stored edited payload through `review_claim_adapter` before record creation.
2. `EducationReviewClaim` enforces enum, string-length and date rules. Some fields are optional at schema level; `required_claim_blockers` independently requires an institution identity for creation.
3. The exact Education constructor expression from `_create_record` was evaluated as a pure in-memory mapping, with a recording constructor. No application mutation method was invoked.
4. The mapped synthetic structure was exercised against local Education-shaped columns. Intentional local duplicate-key, not-null, length and malformed-date errors were categorized using observed SQLSTATEs.
5. The original import catch-all stores only `item_import_failed`; neither that code nor duplicate-like identifiers alone prove a constraint failure.

Synthetic coverage includes present/absent/null, valid and invalid enum, omitted/nullable/malformed dates, reversed date ranges, current-with-end-date, missing required identity, oversized/string-type payload, extra fields, duplicate-like IDs, actual local duplicate constraint failure, and malformed top-level payload.

Classification is evidence-based: a valid structure without an observed failure remains `UNKNOWN_WITH_CURRENT_EVIDENCE`. No import replay was used to obtain a classification.

## Validation results and limitations

- **40/40 tests PASS**, final run 2.74 seconds.
- Unchanged-harness regression reproduction PASS.
- Corrected one-shot process PASS, exit 0.
- Exactly two normal stdout lines: read-only proof and sanitized structure/category report.
- External-network negative tests PASS: TCP, DNS and urllib/provider paths blocked before access.
- Mutation-service guard negative test PASS; static audit confirms inspection DB statements are SELECT/SHOW only.
- Five audited API42 source files byte-match the exact Git revision.
- Compressed Python command: 6,982 characters; tested command-only ECS-compatible override envelope: 7,066 characters, below 8,192. This is a packaging rehearsal, **not** an ECS invocation or approval for one.
- Local runtime: Python 3.14.6, asyncpg 0.31.0, Pydantic 2.13.4, PostgreSQL 16.14.
- Deployed Dockerfile uses Python 3.12. Docker daemon was unavailable; no daemon start, pull, registry access, or exact-image rehearsal occurred. Exact deployed dependency versions were not freshly inspected.
- Existing product-source diff unchanged: `17c60b23022b59eab24e7d074746e4cabb29ad5b` (local SHA-1 checksum of `git diff --binary`).
- Original dirty checkout unchanged: same 19 modified files; diff checksum `08b16ec73d2f8d88a2f577d07665d815dadd51ea`.
- No commit, push, TestFlight upload, backend change, iOS product change, or Production access.

## Local files and reproducibility

All harness tooling is local-only under `/private/tmp/kairoid-education-local.8tNWrs/`:

| File | Purpose |
| --- | --- |
| `reproduce.py` | Unchanged-code reproduction; synthetic UUID substitutions and local-only DB adapter |
| `certified_audit.py` | Corrected inspection core; no ECS launcher |
| `safe_output.py` | Closed output schema, category mapping and exception sanitizer |
| `local_entry.py` | One-shot compressed command, synthetic target binding, external-network/service-call guards |
| `test_harness.py` | 40 synthetic regression/privacy/read-only/category/packaging tests |
| `source/` | Extracted exact API42 app source, used read-only |

The original `/private/tmp/kairoid-education-forensic-once.py` was preserved unchanged as evidence. **Do not execute that original launcher.**

To repeat these local tests, start only this already-created temporary PostgreSQL cluster with its Unix socket and empty listen_addresses, run `test_harness.py` with the backend virtualenv's pytest, then stop that same cluster. The fixture is already populated; do not repeat its CREATE-table setup blindly. No Production credentials or connection are necessary.

## Decision

**HARNESS_FIXED_AND_LOCALLY_CERTIFIED.**

Stop here. No Production audit is authorized by this local certification. Any further Production run requires a fresh founder approval, separately reviewed target/runtime binding, and the same one-task/read-only/cleanup boundaries. The Education import root cause remains **UNKNOWN_WITH_CURRENT_EVIDENCE**; no additional iOS or backend fix is justified by this local result alone.
