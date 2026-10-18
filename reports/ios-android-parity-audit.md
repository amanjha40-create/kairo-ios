# Android → iOS V1.1 audit (before implementation)

Reference: Android `045ed450c14fe2cd6b84f3fed88220159bf7a2aa` exported read-only. iOS base: `8e5684ec60655d8faed2c9afab775bbc14af0b91`; isolated branch `codex/ios-android-parity-v1-1`. No newer certified iOS branch was found in the local/remote inventory. Previously certified iOS premium surfaces/motion, session recovery, DigiLocker return, e-Aadhaar and Permanent Address work is retained. This is distinct from the rejected Android Candidate Experience V2, which was not used. The original dirty checkout is excluded.

| Area | Before classification | Evidence / implementation direction |
|---|---|---|
| Navigation | IOS_BEHIND | `CandidateTab.allCases` exposes five tabs. Retain legacy Verify route compatibility but present verification activity within Career; preserve request-ID focus and every existing action. |
| Home | IOS_BEHIND | `HomeOverviewScreenView.dashboard` separates score and Passport, places integrations before attention. Compact snapshot → attention, single Passport CTA. |
| Career | IOS_BEHIND | Existing canonical record states/actions are present; add discoverable verification activity entry and keep record-specific flows. |
| Passport | IOS_BEHIND | Header, sharing and score are disconnected. Combine owner/score/share and expose factual Trust Signals. Preserve all information/actions. |
| More | PARITY | Existing native profile, account, settings, help and integration destinations retained. |
| Onboarding | IOS_BEHIND | Existing four-page approved story/native accessibility retained; master branding needs updating. No experimental Android V2 content. |
| Quick Profile | IOS_BEHIND | Inline local/backend errors already exist. First-invalid focus/scroll and summary are missing. Preserve existing native multi-step profile and input. |
| Employer invitations | IOS_BEHIND | Pending-subject-acceptance requests need precise Career routing. Public organization invitation capabilities are distinct from request IDs and must never be synthesized from notification public IDs. Audit native entry separately. |
| In-app notifications | IOS_BEHIND | Verification-completed routing exists; Android also routes review/clarification/evidence, documents, sharing and account events. Retain safe generic fallback and exact request identity. |
| APNs delivery | BACKEND_DEPENDENT | Native APNs registration/device-token handling is absent in the audited client, not merely untested. Push requires both native client work and supported backend/provisioning contracts. In-app notification support is not push certification. No real send in this task. |
| DigiLocker | IOS_BEHIND | Certified session/callback/consent contracts retained. Compact supplied logo missing on integration surfaces; use unchanged pixels with white backplate. |
| Permanent Address | PARITY | Preserve matching approved document + three user-initiated checks on separate server-authoritative days. No GPS/provider QA. |
| Trust Score | PARITY | Backend-authoritative score/consent retained. No Candidate-visible V2 label found; internal score versions must remain unchanged. |
| Trust Signals | IOS_BEHIND | Existing collapsed aggregate is less explicit than approved Android factual evidence/status hierarchy. No new score interpretation. |
| Password | IOS_DIFFERENT_INTENTIONALLY | Android signup/reset uses 12–128 characters and login nonempty only. Preserve canonical iOS/backend policy; do not add strength heuristics. Native field/error behavior retained. |
| Guidance | IOS_BEHIND | Preserve physically corrected tour geometry; update verification orientation for Career. Add concise contextual guidance, not blocking modal proliferation. |
| Empty/loading/error | IOS_DIFFERENT_INTENTIONALLY | Native contextual state components already exist. Update attention and route-specific empty copy without hiding source errors. |
| Branding | IOS_BEHIND | Port exact approved Trust Passport SVG geometry to native SwiftUI (primary, mono dark/light, small). Preserve master KairoID™ artwork proportions/TM. Never ship the brand board. |
| Granular per-employment sharing | BACKEND_DEPENDENT | Do not fake record-level sharing where contract is category-level. |
| Stronger unified password policy | BACKEND_DEPENDENT | Requires unified backend contract; no client-only policy. |
| Admin-created Candidate claim | BACKEND_DEPENDENT | No unsupported claim flow exposed. |
| Reference-comment report redaction | BACKEND_DEPENDENT | Preserve current client privacy; no claim that backend/report handling changed. |
| Android inset implementation | NOT_APPLICABLE | Native safe areas, keyboard avoidance and tab bar used instead of WebView CSS. |

## Asset provenance

Founder ZIP inspected directly: compact PNG `DigiLocker/DigiLocker_idUoQlVran_0.png`, wide JPEG `DigiLocker_idkuLTr2I4_1.jpeg`, stacked JPEG `DigiLocker_iddmjo5XdQ_2.jpeg`. Use compact asset unchanged, no tint/redraw/co-branding. Release dependency: **OFFICIAL_DIGILOCKER_ASSET_PROVENANCE_REVIEW_REQUIRED_BEFORE_APP_STORE_RELEASE**. This is not a source/Staging blocker.

## Safety and verification

Implementation and synthetic tests only in the isolated iOS worktree. No backend/AWS/Android/Production mutations, real verification, provider calls, GPS, uploads or account actions. Regression and physical results are pending, not certified by this audit. Preserve the original checkout's 19 tracked changes, HEAD and index. Commit/push only after full validation and physical checks.
