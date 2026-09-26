import Foundation

struct HelpContentSection: Identifiable, Equatable, Sendable {
    let title: String
    let body: String

    var id: String { title }
}

struct HelpGuide: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let sections: [HelpContentSection]

    var searchableParts: [String] {
        [title, subtitle] + sections.flatMap { [$0.title, $0.body] }
    }

    var systemImage: String {
        switch id {
        case "getting-started": "book.closed"
        case "verifying-roles": "checkmark.shield"
        case "trust-score": "sparkles"
        case "sharing-passport": "square.and.arrow.up"
        default: "book.closed"
        }
    }
}

struct HelpFAQ: Identifiable, Equatable, Sendable {
    let id: String
    let question: String
    let answer: String

    var searchableParts: [String] { [question, answer] }
}

nonisolated enum HelpCenterContent {
    static let guides: [HelpGuide] = [
        HelpGuide(
            id: "getting-started",
            title: "Getting started",
            subtitle: "Set up your profile & start verifying",
            sections: [
                HelpContentSection(
                    title: "Complete your profile",
                    body: "Add your personal and professional details in Profile and Career, including relevant employment and education. Use the Skills and Languages selectors to choose standardized values. Information you add is Candidate-provided until a supported verification process confirms it."
                ),
                HelpContentSection(
                    title: "Review imported information",
                    body: "Resume import can help you add career information. Review names, dates and other details before importing, then complete any drafts that need attention in Career. Parsing can miss or misread information; importing a resume does not verify its contents."
                ),
                HelpContentSection(
                    title: "Add supporting Evidence",
                    body: "Open the relevant record and use its Evidence or document controls where available. Choose clear, relevant documents and follow the file requirements shown on that upload screen. Uploading Evidence supports a claim; it does not automatically make the record Verified."
                ),
                HelpContentSection(
                    title: "Request verification",
                    body: "For an eligible employment or education record, review the details, provide the requested Evidence and verification contact information, and follow the submission steps. Check Verify for the request's status and any actions needed from you."
                ),
                HelpContentSection(
                    title: "Build your Trust Passport",
                    body: "Your Trust Passport brings together the professional information and verification signals you choose to maintain in KairoID. Candidate-provided and Verified information are distinguished. It is not a government identity document or legal proof of identity."
                ),
                HelpContentSection(
                    title: "Share when needed",
                    body: "Use Passport Sharing to choose what to include, set link availability and review the recipient view before sending the link. Sharing is under your control and does not give someone access to your entire KairoID account."
                ),
            ]
        ),
        HelpGuide(
            id: "verifying-roles",
            title: "Verifying your roles",
            subtitle: "Step-by-step guide to verify employment",
            sections: [
                HelpContentSection(
                    title: "Choose the role or record",
                    body: "Open Career and select the employment record you want to verify. Use the verification action if the record is eligible. If a request already exists, open it in Verify to see its current status rather than creating another request."
                ),
                HelpContentSection(
                    title: "Review your information",
                    body: "Check the employer or organization, role and employment dates. Complete missing details and confirm that the verification contact information is accurate before submitting. Editing controls depend on the record and request state."
                ),
                HelpContentSection(
                    title: "Provide Evidence where requested",
                    body: "Attach clear supporting documents using the record's Evidence controls. Follow the requirements displayed for that record. Evidence helps the review but is not itself a verification outcome."
                ),
                HelpContentSection(
                    title: "Send to KairoID for review",
                    body: "Complete the required details and consent step, then tap Send to KairoID for review when available. This submits the request for review; it does not instantly verify the role or mean an employer has already responded."
                ),
                HelpContentSection(
                    title: "What happens next",
                    body: "Follow the status in Verify. A request may show Pending KairoID Review, Awaiting verifier, Verifier reviewing or Needs your attention before an outcome such as Verified, Rejected or Unable to Verify. In progress groups ongoing requests. Timing depends on the review and responding organization; there is no guaranteed completion time."
                ),
                HelpContentSection(
                    title: "If more information is needed",
                    body: "Open the request marked Needs your attention and read the correction or information request. Use the available controls to correct details, update Evidence or provide the requested response, then submit it using the action shown. If the necessary control is unavailable, contact support rather than submitting duplicate requests."
                ),
                HelpContentSection(
                    title: "After verification",
                    body: "A successful outcome is shown as Verified on the corresponding record and reflected in your Trust Passport where applicable. It applies to that record, not every claim in your account. If the outcome is Rejected or Unable to Verify, read the reason and follow the available next steps."
                ),
            ]
        ),
        HelpGuide(
            id: "trust-score",
            title: "Trust score explained",
            subtitle: "Understand your score and supported trust signals",
            sections: [
                HelpContentSection(
                    title: "What the Trust Score summarizes",
                    body: "The Trust Score summarizes supported trust signals in your KairoID profile, including identity-related checks, employment and education. It uses recorded verification outcomes, not just how much text you have filled in. Where consent is required, review the Trust Score consent prompt before enabling it."
                ),
                HelpContentSection(
                    title: "Verified information and other signals",
                    body: "Verified employment and education contribute more strongly than Candidate-provided records. Different supported signals contribute differently. Uploading an unverified identity document alone does not increase your Trust Score. Adding Skills, Languages or a longer profile is not a guaranteed score increase."
                ),
                HelpContentSection(
                    title: "Why your score may change",
                    body: "The score is recalculated from the supported information and verification states available at the time. It may change when records are verified, updated or removed, or their recorded state changes. Not every edit changes the score, and no action guarantees a fixed number of points."
                ),
                HelpContentSection(
                    title: "How can I strengthen my Trust Score?",
                    body: "Keep relevant employment and education details accurate, complete missing information needed for a request, and seek verification for supported records. Resolve requests that need your attention and complete available account verification steps. These actions support a stronger verification record, but profile completeness alone does not earn points."
                ),
                HelpContentSection(
                    title: "What does Candidate-provided mean?",
                    body: "Candidate-provided means information was supplied by you and is not represented as independently verified. Verified indicates that the corresponding record has a successful supported verification outcome. Adding a document or sharing a record does not change that distinction."
                ),
                HelpContentSection(
                    title: "What the score does not mean",
                    body: "Your Trust Score is not a credit score, government score or guarantee of employment. It does not verify every statement in your profile. Read individual record statuses alongside the score to understand what has actually been verified."
                ),
            ]
        ),
        HelpGuide(
            id: "sharing-passport",
            title: "Sharing your Trust Passport",
            subtitle: "Choose what recipients can see",
            sections: [
                HelpContentSection(
                    title: "Choose what you want to share",
                    body: "Open Passport Sharing and enter the share purpose. Choose Verified only or Verified + Candidate-provided, then select the available categories and permissions, including whether to show the Trust Score. Candidate-provided information stays clearly labeled; sharing does not make it Verified."
                ),
                HelpContentSection(
                    title: "Review what the recipient will see",
                    body: "Check the Sharing and Not sharing summary before creating a link. Use Preview recipient view on the created share to inspect the actual recipient view before sending it. Recipients see the permitted Passport content, not your entire account or unrestricted private document vault."
                ),
                HelpContentSection(
                    title: "Create and share a link",
                    body: "Choose the link availability option, review the settings and create the share. Use the link, QR code or available share action to pass it on. Passport Sharing and Document Packs have separate controls; review the permissions for the specific item you are sharing."
                ),
                HelpContentSection(
                    title: "Send it to the intended recipient",
                    body: "Treat a share link or QR code as sensitive: someone who receives it may be able to open the permitted content. Check who you are sending it to and avoid posting it publicly unless that is intentional. A purpose label is not an identity check on the person opening the link."
                ),
                HelpContentSection(
                    title: "Manage existing shares",
                    body: "Review existing links in Passport Sharing. Links with an expiry stop being available when they expire, and you can Revoke a share to stop future access through it. Existing links cannot be expanded; create a new link to share more. Revocation cannot retrieve copies or screenshots a recipient already saved."
                ),
            ]
        ),
    ]

    static let faqs: [HelpFAQ] = [
        HelpFAQ(
            id: "timing",
            question: "How long does verification take?",
            answer: "Timing depends on the verification method, review and responding organization. KairoID does not promise a fixed completion time. Check Verify for the current status and any action needed from you."
        ),
        HelpFAQ(
            id: "documents",
            question: "What documents should I upload?",
            answer: "Use clear, relevant documents requested for the record. Follow the Evidence screen's document types, file formats and size limits. Uploading a document does not automatically verify its contents."
        ),
        HelpFAQ(
            id: "privacy",
            question: "Is my data private?",
            answer: "Privacy controls let you choose the content included in a Passport share or Document Pack. Review permissions and the recipient view before sending a link. Recipients do not get access to your entire account. Treat share links as sensitive and revoke them when no longer needed."
        ),
        HelpFAQ(
            id: "candidate-provided",
            question: "What does Candidate-provided mean?",
            answer: "You supplied the information, and it is not represented as independently verified. Adding Evidence or sharing the information does not change it to Verified."
        ),
        HelpFAQ(
            id: "verified",
            question: "What does Verified mean?",
            answer: "The corresponding record has a successful outcome from a supported verification process. It does not mean every claim or document in your account is verified."
        ),
        HelpFAQ(
            id: "editing",
            question: "Can I edit information after adding it?",
            answer: "Use Edit where it is available on your profile or record. Some submitted, historical or verified information is read-only. For requests needing corrections, follow the actions shown in Verify. Contact support if a needed correction is not available."
        ),
        HelpFAQ(
            id: "removing-evidence",
            question: "Can I remove a document or Evidence?",
            answer: "Use Remove or the document-management controls where available. Editable records and private documents may allow removal; historical or protected verification Evidence can be view-only. Removing a current attachment does not promise erasure of retained verification history."
        ),
        HelpFAQ(
            id: "pending",
            question: "Why is my verification still pending?",
            answer: "The request may be awaiting KairoID review, a verifier or further information. Open the request in Verify to check its exact status and any action needed. Pending is not a Verified outcome."
        ),
        HelpFAQ(
            id: "information",
            question: "What happens if a verification needs more information?",
            answer: "Open the request marked Needs your attention, read what is needed and use its correction or response controls. Submit the requested information using the action shown; avoid creating a duplicate request."
        ),
        HelpFAQ(
            id: "passport",
            question: "What is my Trust Passport?",
            answer: "Your Trust Passport brings together the professional information and verification signals you maintain in KairoID. It distinguishes Candidate-provided and Verified records. It is not a government identity document or legal proof of identity."
        ),
        HelpFAQ(
            id: "score",
            question: "What is the Trust Score?",
            answer: "It summarizes supported trust signals from identity-related checks, employment and education. Read it alongside individual verification statuses. It is not a credit score or a guarantee of employment."
        ),
        HelpFAQ(
            id: "improve-score",
            question: "How can I improve my Trust Score?",
            answer: "Keep relevant records accurate, request supported verifications and resolve requests needing attention. Verified outcomes matter more than profile text alone. Unverified identity uploads do not increase the score, and no action guarantees a particular number of points."
        ),
        HelpFAQ(
            id: "visibility",
            question: "Can I control what other people see?",
            answer: "Yes. Choose the sharing mode, categories and permissions in Passport Sharing. Review the recipient view before sending the link. Document Packs have their own selection controls. A share does not give recipients access to your whole KairoID account."
        ),
        HelpFAQ(
            id: "stop-sharing",
            question: "Can I stop sharing something?",
            answer: "Revoke an existing Passport share to stop future access through that link, or let its selected expiry take effect. Review Document Pack links separately. Revocation cannot remove copies or screenshots someone already saved."
        ),
        HelpFAQ(
            id: "skills-languages",
            question: "Can I update my skills and languages?",
            answer: "Yes. Use the searchable, standardized Skills and Languages selectors and choose a language proficiency level. Duplicate selections are prevented. Older free-text entries remain visible and removable; editing a legacy language requires a canonical replacement. These details are self-declared, not automatically Verified."
        ),
        HelpFAQ(
            id: "support",
            question: "How do I contact KairoID support?",
            answer: "Tap Support or Contact support in the Help Center, then choose Email support to open the official email flow. You can also describe a problem using Report an issue. Do not include passwords, one-time codes or private share links in your report."
        ),
    ]
}
