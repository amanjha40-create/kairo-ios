# KairoID iOS Visual Parity V1

## Scope and provenance

- Starting iOS commit: `b6b96e7063b3498a4d122cbffbd9ad8914f958ee`.
- Working branch: `codex/ios-visual-parity-v1`.
- Isolated checkout: `/private/tmp/kairoid-ios-visual-parity-v1`. The original dirty checkout and the separate Launch RC checkout were preserved.
- Android reference: current Staging app on the connected Android device, compared with the existing UI V2 worktree `/private/tmp/kairoid-candidate-android-final-fixes` (HEAD `1d0bfccfb250d065392137f0fe618de65552987f`, with pre-existing UI changes). Reference inspection was read-only.
- Android is a visual/product reference, not evidence of Production readiness. No Android source, endpoints, flags, fixtures, or backend behavior was copied into iOS.
- Physical iPhone package: Staging, Demo=false, `com.kairoid.Kairo`, Personal Team `XN5Y3V3CSV`, iOS 17 minimum. No release signing, Associated Domains, Universal Link activation, or Production deployment changes.

## Screen audit and implementation

| Surface | Android UI V2 structure | Previous iOS gap | Visual alignment and retained native behavior |
| --- | --- | --- | --- |
| Home | Greeting, dominant navy Trust Score, attention, progress, Career actions, activity | Decorative background and equal-weight cards | Shared navy/grid/teal Trust surface; flat supporting sections; scaled score; adaptive header; existing authoritative values and actions |
| Career | Counted compact sections, quick add, divided record rows | Larger individual cards and metadata blocks | Compact record headings, counts, 44pt add controls, divided rows, grouped contextual actions |
| Employment | Role/company/status, details, documents, verification | No distinct read-only overview detail | Native detail sheet using loaded dates, type and location; existing document/editor/delete/verification flows reused |
| Education | Degree/institution/status, study details, documents, verification | Detail information dispersed into editor/list | Same record-detail grammar; existing field/level/grade/date precision retained |
| Certification | Title/issuer/status, credential metadata, certificate document | Oversized card and repeated chrome | Shared record/detail/document components; expiry and credential identifier shown only when supplied |
| Projects | Title/role/dates, description and links, self-declared semantics | Larger cards; inconsistent details | Same compact grammar; organization/description from loaded record; absent verification status is not invented |
| Verify | Needs your attention, In progress, Completed | Competing card outlines | Existing groups retained with divided sections and shared status component; existing priority action preserved |
| Verify detail | Current state, next action, claim, evidence, contact, timeline | Next action separated from current state | Existing action brought directly below current-state header; shared immutable-evidence row; timeline and recovery retained |
| Passport | Owner identity, dominant Trust Score, signals, completeness/records, sharing | Identity hero competed with Trust summary | Compact owner identity followed by shared navy Trust surface; flat signals and record groups; existing PDF/share/activity actions |
| Share | Purpose, permissions/expiry, review, result, link/QR/share/history | Disconnected card treatment | Flat purpose/expiry/permissions/review groups; existing native result, QR, Copy, Share and history retained |
| Documents/Vault | Compact document hub with metadata, source and actions | Large document cards | Reusable icon/name/type/size/source/state/action row; existing Vault scope retained; immutable history explicitly marked |
| Notifications | Compact unread/read rows and authoritative actions | Box per notification | Divided rows and subdued unread surface; existing mark-read/navigation behavior unchanged |
| Profile | Grouped identity/contact and editable professional fields | Nested form cards | Flat native form sections; existing verified identity and field validation unchanged |
| More | Account, Activity & documents, Support, Session | Large identity hero and boxed groups | Compact identity, grouped account/activity/document rows, privacy/support and distinct Danger Zone |
| Settings | Account/privacy/consent/sessions and preferences | Many equal-weight sections | Flat grouped settings, native appearance controls, destructive action separation; existing destinations retained |

## Shared visual and accessibility rules

- Adaptive navy, teal, background/surface/border/text roles; status roles include success, pending, attention, rejected, withdrawn, draft and candidate-provided.
- Spacing: 4/8/12/16/24/32; corner roles: 12/16/24/28.
- SF typography keeps native Dynamic Type while separating page, section, record, metadata and action hierarchy.
- `KairoSection` replaces repeated card shells; `KairoDocumentRow` is shared by Career documents, Vault and verification evidence.
- `KairoStatusChip` provides canonical labels/icons/colors. A domain-specific authoritative title can override the default; a pending state is not relabeled Verified and cancelled/withdrawn meanings are not conflated.
- Primary/secondary/tertiary/destructive/icon treatments retain native controls and minimum 44pt action targets.
- Common loading skeleton, empty and safe-error views; no new networking or optimistic business state.
- Home and Career record headers stack at accessibility text sizes, preventing status chips from squeezing long record titles into narrow columns. Demo banner occupies a separate layout row instead of an overlay. UI position assertions check banner/header separation and the large-text Career status position. Demo indication remains explicit; physical QA is not Demo.
- Contrast unit checks cover main text/background and primary button contrast in light/dark. Document/status tests cover long content at narrow widths and accessibility sizes.

## Deliberate contract boundaries

- No endpoint, DTO, authentication/session/onboarding service, mutation service, refresh policy or backend change.
- Career metadata mapping is display-only and uses fields already loaded by the existing service.
- New record details invoke existing owner actions after dismissal; they do not implement parallel CRUD/document/verification flows.
- History is not fabricated where the existing Career response supplies no history.
- iOS keeps its working share permission controls and optional label contract; Android's current form is not used to redefine them.
- iOS Vault remains the existing private identity-document surface. Android's broader aggregated hub is not copied through unapproved endpoints.
- Personal Team install is device QA only, not App Store signing or Universal Link release validation.
- The requested baseline's AppIcon catalogue contains unassigned entries. This milestone does not import the separate, uncommitted Launch RC icon/signing work or claim release-package completeness.

## Evidence and validation

Paired local screenshot review covers Home, Career, Employment detail, Education detail, Verify, Verify detail, Passport, Share, Documents, More and Settings. Android reference images remain local and are not committed. Automated iOS screenshots use the existing synthetic UI-test fixtures; they are not evidence of new Staging data mutations.

- Initial focused tests: 5 unit + 7 UI, all passed.
- Review found and corrected Home accessibility-header compression, Demo banner overlap, and a dark-mode test that had not actually selected the app's Dark setting.
- Complete regression: 442/442 KairoTests and 120/120 KairoUITests passed (`/private/tmp/kairoid-visual-parity-full-3.xcresult`).
- An earlier full run caught a case-sensitive Passport heading accessibility-label mismatch. The implementation restored `Trust Score`; the existing test was not weakened. Screenshot inspection also caught a Demo banner overlap, fixed by giving the banner a separate layout row.
- The final Career accessibility-only layout adjustment was made after the complete regression had compiled. Current-source confirmation reran all 442 unit tests and 16 affected/parity UI tests: 458/458 passed (`/private/tmp/kairoid-visual-parity-final-confirmation.xcresult`). This distinction is retained rather than claiming the entire 120-test UI suite was rerun after that last adjustment.
- Final screenshots are exported to `/private/tmp/kairoid-visual-parity-final-screenshots`; the eleven paired reference links and review notes are in `/private/tmp/kairoid-visual-parity-screenshot-review.md`. Normal Home/Career/details/Verify/Passport/Share/Vault/More/Settings and Dark/large-text evidence were rechecked.
- Development / Staging / Production / Demo unsigned device builds: passed.
- Strict concurrency (complete, Swift warnings as errors) and iOS 17 compile gates: passed. An iOS 17 runtime was not available; this is compile/deployment-target validation, not a physical iOS 17 run.
- Signed Personal Team Staging build: passed. The latest package was installed on iPhone 11; its immediate launch was blocked by the device lock screen. Earlier iterations launched successfully, but that is not substituted for final-build physical approval.
- Physical screen/dark/large-text walkthrough: awaiting founder unlock and confirmation on the latest package.
- No crashes or runtime exceptions observed in the completed automated runs. Final physical-run crash status is not yet established.
- No push, main integration, deployment or live QA data mutation performed.

## Handoff status

All fifteen screen surfaces and shared status/button/state components are implemented and simulator-validated, with deliberate contract boundaries listed above. Development, Staging, Production and Demo builds, strict concurrency, iOS 17 compilation, signed Staging build, and `git diff --check` passed on the latest source.

Backend changed: NO. Business/API behavior changed: NO; only presentation and wiring to existing native actions changed. Push performed: NO. Production changed: NO. No original dirty-worktree edits were overwritten.

The milestone is **not complete** until the founder unlocks the iPhone 11, opens the installed KairoID app and confirms Home, Career, Verify, Passport, Documents, More, Settings, Dark mode and large-text behavior. Manual physical VoiceOver operation is not claimed. No Universal Link or App Store release validation is claimed.
