# iOS Employment References V1 — certified Staging scope

Starting iOS SHA: `142e28bdac6d2f0aa98c2cb5c6ab9be7a0af7035`.
Android reference: `49130a95582e977e568b191bc55c9956f809887e`.
Branch: `codex/ios-current-android-parity`.

Final result: implemented and physically certified. Full unit suite 813/813 and provenance/privacy 46/46 PASS. Complete UI coverage is 266 uniquely passing methods after two scoped test-interaction corrections, plus one explicitly physical-only VoiceOver skip. Physical suite 22/22 PASS; nomination additionally passed 3/3 Simulator and 3/3 physical repetitions after a test-only keyboard dismissal correction. No remaining References gap in the authorized Staging scope. No live nomination/outreach or backend mutation occurred. See the final closure and retained intermediate failures in `ios-current-android-parity.md`; older progress entries below are chronological, not the final status.

## Implementation and contract

The existing Employment detail embeds the canonical References section. No bottom tab, new employment verification policy or Trust Score contribution is introduced.

| Operation | Candidate endpoint | Safety |
|---|---|---|
| Read | GET `/employments/{id}/references` | private no-store JSON, canonical session |
| Nominate/edit | PUT `…/reporting-manager` | transient name/designation/email/E.164 phone; no automatic write replay |
| Request change | POST `…/reporting-manager/change` | explicit revalidation acknowledgement; no automatic replay |

No invitation/send API exists in the iOS service. At least one valid contact method is required. Summary contacts are never decoded/prepopulated. Locked, validated, employer-confirmed or post-nomination states use explicit change. A read immediately before mutation detects an HR state transition; the editor must be reviewed again. Ambiguous failure causes read-only reconciliation, not a blind repeat. Disappearance invalidates late UI results and clears contact input.

Backend-only states render: not started, pending, awaiting HR confirmation, ready for invitation, invitation sent, awaiting response, completed, declined, expired, needs review, unable to confirm; unknown states show Status unavailable. Former Reporting Manager and employer-confirmed relationship use explicit exposed fields. Overall count is backend 0/2–2/2, validated against the exact Employment identity. Reference completion does not change employment verification.

HR-corrected confidential contacts/comments/ratings/invitation capabilities are not fields in the Candidate model or UI. The current Candidate contract has no separate correction flag; iOS does not invent one. `identity_withheld` suppresses name/designation. Operational IDs are internal request scope only, never visible.

## Validation chronology

- Focused model and mocked transport tests PASS: nomination validation, normalization, all status mappings, locked/confirmed change, withheld identity, DTO privacy, scope/count checks, canonical routes, no send, private/no-store transport and no 401 mutation replay.
- Final-source full unit suite: 813/813 PASS. Provenance/privacy: 46/46 PASS. Final full UI gate is running.
- New UI tests cover 2/2, nomination, privacy, explicit change, former manager and invitation semantics; run in progress.
- All 11 new parity UI tests passed. Full existing UI regression remains running, with one Help Center keyboard-interaction failure under investigation; certification is not green yet.
- Founder-observed iPhone 11 fixture checks passed: completed 2/2 with separate HR/Manager Completed labels and no Send action; synthetic nomination → awaiting HR confirmation; confirmed/change consent, former-manager heading and withheld identity states; dark-mode readability. XXXL/VoiceOver remain pending, with physical XCTest automation now authorized. No live manager nomination or outreach was performed.
- Synthetic harness uses in-memory services, no network or Keychain, and requires explicit UI-test argument + dedicated flag + Staging build/environment, Demo=false. Normal launch is unchanged.

No backend, Android, Admin, HR or Production changes. No commit/push until all certification gates pass.

Final corrected-source physical suite: 22/22 PASS, including all 14 new parity tests. References nomination, completed/withheld/former/invitation states, dark XXXL reachability, and actual VoiceOver speech passed. The new section uses the existing adaptive brand tint after the physical contrast audit exposed a default-blue action issue. The only audit exception is the documented native glass Done contrast false positive; References content is not exempt. Final complete Simulator regression remains the commit/push gate. Simulator speech alone is explicitly skipped in favor of the successful physical speech check.
