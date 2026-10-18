# Android V1.1 → native iOS parity matrix

Android reference: `045ed450c14fe2cd6b84f3fed88220159bf7a2aa` (read-only exact snapshot). iOS starting point: `8e5684ec60655d8faed2c9afab775bbc14af0b91`. Implementation branch: `codex/ios-android-parity-v1-1`.

**Status: source/build and selected synthetic iPhone certification passed.** Evidence: 895 unit passes, 298 unique Simulator UI passes after focused test repairs (four physical-only skips), 63 privacy/provenance passes, four configuration builds, Staging analysis and 18/18 selected physical checks. See the certification report for original failed-run history, intentional limits and final artifact/push handoff.

| Android approved behavior | iOS before | iOS after | Status | Intentional native difference |
|---|---|---|---|---|
| Home / Career / Passport / More | Five tabs including Verify | Four tabs; legacy Verify routes push Career verification activity | PARITY | Native NavigationStack/back and tab bar; legacy route enum retained but excluded from visible tabs |
| Precise verification-request entry | Top-level Verify | Home/notification/record focus retained under Career | PARITY | Existing native sheets and canonical action handlers retained |
| Compact Trust Snapshot → Needs Your Attention | Large score; Passport/integrations before attention | Compact score/mark and one View Trust Passport CTA, then attention | PARITY | Score details/consent remain accessible from Passport, no duplicated Home action |
| Empty attention context | No active requests copy | Explains invitations/requests and no action required; unavailable source stays explicit | PARITY | Native state components |
| Career states/actions | Canonical records and actions | Preserved; discoverable activity + concise guidance | PARITY | No backend status reinterpretation |
| Coherent Passport owner/score/share | Three disconnected objects | One native card, full-color light mark, adaptive dark mark | PARITY | Native typography, Dynamic Type and sharing sheets |
| Factual Trust Signals | Collapsed broad summary | Contact/email, canonical career status counts, optional certifications/projects, self-declared Skills | PARITY | Native rows reflow; no contact-to-identity proof inference or new scoring |
| More account/settings/help/integrations | Already native | Preserved; notifications can target Settings | PARITY | Native destinations rather than web routes |
| KairoID™ master | Prior Welcome wordmark | Founder master intact, including TM and spacing, on existing brand surfaces | PARITY | White backplate preserves original colors in both themes; no recoloring |
| Trust Passport product mark | Generic signature | Exact approved 64×88 geometry in SwiftUI Canvas; primary/mono dark/mono light/small | PARITY | Native vector, no board raster |
| DigiLocker compact asset | Generic symbol | Original PNG in Hub header and contextual explainer, both connection states | PARITY | White backplate, `.original` rendering; no tint, trace or co-branding |
| Four-page Welcome | Previously certified native four-page story | Story/routes/artwork concepts retained; master logo updated | PARITY | Reflowable native text instead of Android baked raster text |
| Quick Profile validation | Inline local/backend errors | Adds ordered first-error focus/scroll, summary and input preservation | PARITY | Existing native multi-step profile and required fields retained |
| Request invitation | Canonical pending-subject-acceptance state | Home says Review invitation and opens exact request under Career | PARITY | No capability synthesized from request/public IDs |
| Organization invitation capability | No native route | Strict Staging HTTPS host/path parser, redacted memory-only presentation, private public-read/explicit authenticated-accept transport | PARITY (synthetic Staging) | Existing Login path; link retained only in memory. Production/universal-link hosting access is not asserted by synthetic source tests |
| Notification route model | Completed verification + generic detail | Exact request aliases; account/settings, document hub, sharing activity, Passport and score/Home routes | PARITY | Unknown events retain readable generic detail instead of silently discarding content |
| Push delivery | In-app only evidence | No delivery claim | BACKEND_DEPENDENT | No APNs/provider send performed |
| Permanent Address | Certified document + three server-day checks | Unchanged contract; concise optional guidance | Preserved | No GPS or real upload in QA |
| Password contract | Existing canonical length policy | Unchanged 12–128, no invented character-class rule | Preserved | Native secure fields and errors |
| Guidance | Five-step native tour | Measured spotlights retained; verification step points to Career; contextual disclosures | PARITY | No new blocking modal or new persistent preference store |
| Error/loading/privacy | Native states | Preserved; invitation failures sanitize details and require explicit retry | PARITY | Capability traffic bypasses logs/cookies/cache/redirects via existing private transport |

## Dependencies not simulated as finished product work

- Granular per-employment Passport sharing remains backend-dependent; guidance states category-level sharing.
- Push-delivery E2E requires native APNs registration/device-token work, backend/APNs contracts and separate safe delivery approval. The audited client has no APNs registration path; this is not represented as backend-only work or as a passing push gate.
- A stronger unified password policy is backend-dependent; no client-only strengthening.
- Admin-created Candidate claim is not exposed without its supported contract.
- Reference-comment backend/report redaction is not modified or represented as fixed here.
- **OFFICIAL_DIGILOCKER_ASSET_PROVENANCE_REVIEW_REQUIRED_BEFORE_APP_STORE_RELEASE**. Founder asset is suitable for this source/Staging exercise; release provenance approval is separate.

No Android implementation was copied mechanically. No backend/AWS/Production/Admin/HR source or data, signing configuration, App Store or TestFlight action is part of this change.
