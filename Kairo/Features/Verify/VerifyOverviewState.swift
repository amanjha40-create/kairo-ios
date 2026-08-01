import Foundation

enum VerifyOverviewFixtureKind: String, CaseIterable, Equatable, Sendable {
    case populated
    case empty
    case loading
    case error
}

struct VerifyOverviewState: Equatable, Sendable {
    let header: VerifyHeader
    let phase: VerifyOverviewPhase

    static func `default`(isDemoMode: Bool) -> VerifyOverviewState {
        populatedFixture(dataSourceLabel: isDemoMode ? "Demo data" : "Preview data")
    }

    static func populatedFixture(dataSourceLabel: String = "Demo data") -> VerifyOverviewState {
        VerifyOverviewState(
            header: .fixture,
            phase: .populated(
                VerifyOverviewContent(
                    dataSourceLabel: dataSourceLabel,
                    priorityAction: VerifyPriorityAction(
                        title: "Verify your current employment",
                        organization: "BrightPath Technologies",
                        supportingCopy: "Confirm your current role to strengthen your Trust Passport.",
                        trustImpact: "High trust impact",
                        estimatedCompletionTime: "About 5 minutes",
                        statusTitle: "Ready to start"
                    ),
                    requests: [
                        VerifyRequest(
                            id: "employment-brightpath",
                            type: "Employment verification",
                            organization: "BrightPath Technologies",
                            requester: "Kairo candidate trust team",
                            requestedItem: "Current role and employment dates",
                            status: .awaitingApproval,
                            dateLabel: "Requested 1 Aug 2026",
                            timelineSummary: "Request opened today",
                            requiredAction: "Review and approve the employment request",
                            supportingNote: "Your approval allows Kairo to begin the local verification preview."
                        ),
                        VerifyRequest(
                            id: "education-welingkar-pending",
                            type: "Education verification",
                            organization: "Welingkar Institute of Management",
                            requester: "Kairo education trust team",
                            requestedItem: "MBA graduation details",
                            status: .awaitingInformation,
                            dateLabel: "Updated 31 Jul 2026",
                            timelineSummary: "Additional details requested yesterday",
                            requiredAction: "Provide clarification about your qualification record",
                            supportingNote: "This fixture preview does not send any information to an institution."
                        ),
                        VerifyRequest(
                            id: "employment-northstar",
                            type: "Employment verification",
                            organization: "Northstar Labs",
                            requester: "Kairo candidate trust team",
                            requestedItem: "Previous role confirmation",
                            status: .submitted,
                            dateLabel: "Updated 30 Jul 2026",
                            timelineSummary: "Submitted 2 days ago",
                            requiredAction: "Waiting for employer review",
                            supportingNote: "Kairo will surface the next step when this verification changes."
                        ),
                        VerifyRequest(
                            id: "education-welingkar-review",
                            type: "Education verification",
                            organization: "Welingkar Institute of Management",
                            requester: "Kairo education trust team",
                            requestedItem: "MBA degree confirmation",
                            status: .underReview,
                            dateLabel: "Updated 31 Jul 2026",
                            timelineSummary: "Under review since yesterday",
                            requiredAction: "No action needed right now",
                            supportingNote: "This fixture state represents an institution reviewing your record."
                        ),
                        VerifyRequest(
                            id: "completed-employment-brightpath",
                            type: "Employment",
                            organization: "BrightPath Technologies",
                            requester: "Kairo candidate trust team",
                            requestedItem: "Current employment",
                            status: .verified,
                            dateLabel: "Completed 28 Jul 2026",
                            timelineSummary: "Employment verified",
                            requiredAction: "No action needed",
                            supportingNote: "This verification already strengthens your Trust Passport."
                        ),
                        VerifyRequest(
                            id: "completed-identity-aarav",
                            type: "Identity",
                            organization: "Aarav Mehta",
                            requester: "Kairo identity trust team",
                            requestedItem: "Identity check",
                            status: .verified,
                            dateLabel: "Completed 1 Aug 2026",
                            timelineSummary: "Identity verified today",
                            requiredAction: "No action needed",
                            supportingNote: "Identity verification is already part of your Trust Passport foundation."
                        ),
                        VerifyRequest(
                            id: "completed-email-aarav",
                            type: "Email",
                            organization: "aarav@example.com",
                            requester: "Kairo identity trust team",
                            requestedItem: "Email ownership",
                            status: .verified,
                            dateLabel: "Completed 1 Aug 2026",
                            timelineSummary: "Email verified today",
                            requiredAction: "No action needed",
                            supportingNote: "Email verification is already active in your Trust Passport."
                        )
                    ],
                    suggestions: [
                        VerifySuggestion(
                            type: .education,
                            title: "Verify your highest education",
                            valueStatement: "Add stronger academic trust to your Passport."
                        ),
                        VerifySuggestion(
                            type: .certification,
                            title: "Verify a professional certification",
                            valueStatement: "Show specialised expertise with a trusted credential."
                        ),
                        VerifySuggestion(
                            type: .project,
                            title: "Add and verify a recent project",
                            valueStatement: "Turn practical work into a reusable signal of trust."
                        )
                    ]
                )
            )
        )
    }

    static func emptyFixture(dataSourceLabel: String = "Demo data") -> VerifyOverviewState {
        VerifyOverviewState(
            header: .fixture,
            phase: .empty(
                VerifyOverviewEmptyContent(
                    dataSourceLabel: dataSourceLabel,
                    title: "No verifications yet.",
                    message: "Start with one important part of your career and build trust from there."
                )
            )
        )
    }

    static func loadingFixture() -> VerifyOverviewState {
        VerifyOverviewState(
            header: .fixture,
            phase: .loading
        )
    }

    static func errorFixture() -> VerifyOverviewState {
        VerifyOverviewState(
            header: .fixture,
            phase: .error(
                VerifyOverviewErrorState(
                    title: "Verify overview unavailable",
                    message: "Kairo could not prepare your Trust Center preview. Try again when local fixture data is available."
                )
            )
        )
    }

    func applying(_ action: VerifyRequestActionTransition, to requestID: String) -> VerifyOverviewState {
        guard case .populated(let content) = phase else {
            return self
        }

        return VerifyOverviewState(
            header: header,
            phase: .populated(content.applying(action, to: requestID))
        )
    }
}

enum VerifyOverviewPhase: Equatable, Sendable {
    case loading
    case populated(VerifyOverviewContent)
    case empty(VerifyOverviewEmptyContent)
    case error(VerifyOverviewErrorState)
}

struct VerifyHeader: Equatable, Sendable {
    let supportingLine: String

    static let fixture = VerifyHeader(
        supportingLine: "Every completed verification makes your professional trust more reusable."
    )
}

enum VerifyOverviewSection: String, CaseIterable, Equatable, Sendable {
    case priorityAction
    case pendingRequests
    case inProgress
    case completed
    case suggestedNext
}

enum VerifyRequestGroup: Equatable, Sendable {
    case pending
    case inProgress
    case completed
}

enum VerifyStatusTone: Equatable, Sendable {
    case accent
    case success
    case warning
    case danger
    case neutral
}

struct VerifyStatusStyle: Equatable, Sendable {
    let title: String
    let symbol: String
    let tone: VerifyStatusTone
}

enum VerifyVerificationStatus: String, CaseIterable, Equatable, Sendable {
    case awaitingApproval
    case awaitingInformation
    case submitted
    case underReview
    case verified
    case rejected
    case expired

    static let displayOrder: [VerifyVerificationStatus] = [
        .awaitingApproval,
        .awaitingInformation,
        .submitted,
        .underReview,
        .verified,
        .rejected,
        .expired
    ]

    var group: VerifyRequestGroup {
        switch self {
        case .awaitingApproval, .awaitingInformation:
            .pending
        case .submitted, .underReview:
            .inProgress
        case .verified, .rejected, .expired:
            .completed
        }
    }

    var style: VerifyStatusStyle {
        switch self {
        case .awaitingApproval:
            VerifyStatusStyle(
                title: "Awaiting your approval",
                symbol: "checkmark.circle",
                tone: .accent
            )
        case .awaitingInformation:
            VerifyStatusStyle(
                title: "Additional information requested",
                symbol: "text.badge.plus",
                tone: .warning
            )
        case .submitted:
            VerifyStatusStyle(
                title: "Submitted",
                symbol: "paperplane",
                tone: .accent
            )
        case .underReview:
            VerifyStatusStyle(
                title: "Under review",
                symbol: "hourglass",
                tone: .warning
            )
        case .verified:
            VerifyStatusStyle(
                title: "Verified",
                symbol: "checkmark.seal.fill",
                tone: .success
            )
        case .rejected:
            VerifyStatusStyle(
                title: "Rejected",
                symbol: "xmark.octagon",
                tone: .danger
            )
        case .expired:
            VerifyStatusStyle(
                title: "Expired",
                symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tone: .neutral
            )
        }
    }

    var rank: Int {
        Self.displayOrder.firstIndex(of: self) ?? 0
    }
}

enum VerifyRequestActionTransition: Equatable, Sendable {
    case accept
    case decline
}

struct VerifyOverviewContent: Equatable, Sendable {
    let dataSourceLabel: String
    let priorityAction: VerifyPriorityAction
    let requests: [VerifyRequest]
    let suggestions: [VerifySuggestion]

    var visibleSections: [VerifyOverviewSection] {
        [
            .priorityAction,
            .pendingRequests,
            .inProgress,
            .completed,
            .suggestedNext
        ]
    }

    var pendingRequests: [VerifyRequest] {
        requests(in: .pending)
    }

    var inProgressRequests: [VerifyRequest] {
        requests(in: .inProgress)
    }

    var completedRequests: [VerifyRequest] {
        requests(in: .completed)
    }

    func request(id: String) -> VerifyRequest? {
        requests.first(where: { $0.id == id })
    }

    func applying(_ action: VerifyRequestActionTransition, to requestID: String) -> VerifyOverviewContent {
        VerifyOverviewContent(
            dataSourceLabel: dataSourceLabel,
            priorityAction: priorityAction,
            requests: requests.map { request in
                guard request.id == requestID else {
                    return request
                }

                switch action {
                case .accept:
                    return request.acceptedPreview()
                case .decline:
                    return request.declinedPreview()
                }
            },
            suggestions: suggestions
        )
    }

    private func requests(in group: VerifyRequestGroup) -> [VerifyRequest] {
        requests
            .enumerated()
            .filter { $0.element.status.group == group }
            .sorted { lhs, rhs in
                if lhs.element.status.rank == rhs.element.status.rank {
                    return lhs.offset < rhs.offset
                }

                return lhs.element.status.rank < rhs.element.status.rank
            }
            .map(\.element)
    }
}

struct VerifyPriorityAction: Equatable, Sendable {
    let title: String
    let organization: String
    let supportingCopy: String
    let trustImpact: String
    let estimatedCompletionTime: String
    let statusTitle: String
}

struct VerifyRequest: Equatable, Identifiable, Sendable {
    let id: String
    let type: String
    let organization: String
    let requester: String
    let requestedItem: String
    let status: VerifyVerificationStatus
    let dateLabel: String
    let timelineSummary: String
    let requiredAction: String
    let supportingNote: String

    func acceptedPreview() -> VerifyRequest {
        VerifyRequest(
            id: id,
            type: type,
            organization: organization,
            requester: requester,
            requestedItem: requestedItem,
            status: .submitted,
            dateLabel: "Updated just now",
            timelineSummary: "Approved and submitted locally",
            requiredAction: "Waiting for review",
            supportingNote: "This local preview confirms the next step without sending any data."
        )
    }

    func declinedPreview() -> VerifyRequest {
        VerifyRequest(
            id: id,
            type: type,
            organization: organization,
            requester: requester,
            requestedItem: requestedItem,
            status: .rejected,
            dateLabel: "Updated just now",
            timelineSummary: "Declined locally",
            requiredAction: "No further action",
            supportingNote: "This local preview records the decline only for the current session."
        )
    }
}

struct VerifySuggestion: Equatable, Identifiable, Sendable {
    let type: VerifyVerificationKind
    let title: String
    let valueStatement: String

    var id: String { type.rawValue }
}

enum VerifyVerificationKind: String, CaseIterable, Identifiable, Equatable, Sendable {
    case employment
    case education
    case certification
    case project

    var id: String { rawValue }

    var title: String {
        switch self {
        case .employment:
            "Employment"
        case .education:
            "Education"
        case .certification:
            "Certification"
        case .project:
            "Project"
        }
    }

    var systemImage: String {
        switch self {
        case .employment:
            "briefcase"
        case .education:
            "graduationcap"
        case .certification:
            "checkmark.seal"
        case .project:
            "sparkles.rectangle.stack"
        }
    }

    var supportingCopy: String {
        switch self {
        case .employment:
            "Confirm the role that matters most right now."
        case .education:
            "Add academic trust to your Passport."
        case .certification:
            "Turn credentials into a reusable signal."
        case .project:
            "Show evidence of practical work and outcomes."
        }
    }
}

struct VerifyOverviewEmptyContent: Equatable, Sendable {
    let dataSourceLabel: String
    let title: String
    let message: String
}

struct VerifyOverviewErrorState: Equatable, Sendable {
    let title: String
    let message: String
}

enum VerifyStartVerificationPhase: Equatable, Sendable {
    case form
    case confirmation(VerifyVerificationKind)
}

struct VerifyStartVerificationSheetState: Equatable, Sendable {
    var selectedType: VerifyVerificationKind?
    var phase: VerifyStartVerificationPhase
    var employment: VerifyEmploymentDraft
    var education: VerifyEducationDraft
    var certification: VerifyCertificationDraft
    var project: VerifyProjectDraft

    init(
        selectedType: VerifyVerificationKind? = nil,
        phase: VerifyStartVerificationPhase = .form,
        employment: VerifyEmploymentDraft = .fixture,
        education: VerifyEducationDraft = .fixture,
        certification: VerifyCertificationDraft = .fixture,
        project: VerifyProjectDraft = .fixture
    ) {
        self.selectedType = selectedType
        self.phase = phase
        self.employment = employment
        self.education = education
        self.certification = certification
        self.project = project
    }

    var isContinueEnabled: Bool {
        selectedType != nil
    }

    var selectedFieldRows: [VerifyDraftFieldRow] {
        switch selectedType {
        case .employment:
            employment.fieldRows
        case .education:
            education.fieldRows
        case .certification:
            certification.fieldRows
        case .project:
            project.fieldRows
        case nil:
            []
        }
    }

    mutating func select(_ type: VerifyVerificationKind) {
        selectedType = type
        phase = .form
    }

    mutating func continueFlow() {
        guard let selectedType else {
            return
        }

        phase = .confirmation(selectedType)
    }
}

struct VerifyDraftFieldRow: Equatable, Identifiable, Sendable {
    let title: String
    let value: String

    var id: String { title }
}

struct VerifyEmploymentDraft: Equatable, Sendable {
    var organization: String
    var role: String
    var startDate: String
    var endDate: String

    static let fixture = VerifyEmploymentDraft(
        organization: "BrightPath Technologies",
        role: "Product Operations Manager",
        startDate: "Jan 2024",
        endDate: "Current role"
    )

    var fieldRows: [VerifyDraftFieldRow] {
        [
            VerifyDraftFieldRow(title: "Organisation", value: organization),
            VerifyDraftFieldRow(title: "Role", value: role),
            VerifyDraftFieldRow(title: "Start date", value: startDate),
            VerifyDraftFieldRow(title: "End date", value: endDate)
        ]
    }
}

struct VerifyEducationDraft: Equatable, Sendable {
    var institution: String
    var qualification: String
    var graduationYear: String

    static let fixture = VerifyEducationDraft(
        institution: "Welingkar Institute of Management",
        qualification: "MBA",
        graduationYear: "2021"
    )

    var fieldRows: [VerifyDraftFieldRow] {
        [
            VerifyDraftFieldRow(title: "Institution", value: institution),
            VerifyDraftFieldRow(title: "Qualification", value: qualification),
            VerifyDraftFieldRow(title: "Graduation year", value: graduationYear)
        ]
    }
}

struct VerifyCertificationDraft: Equatable, Sendable {
    var issuer: String
    var certificationName: String
    var issueDate: String

    static let fixture = VerifyCertificationDraft(
        issuer: "Scrum Alliance",
        certificationName: "Certified Scrum Product Owner",
        issueDate: "Mar 2025"
    )

    var fieldRows: [VerifyDraftFieldRow] {
        [
            VerifyDraftFieldRow(title: "Issuer", value: issuer),
            VerifyDraftFieldRow(title: "Certification name", value: certificationName),
            VerifyDraftFieldRow(title: "Issue date", value: issueDate)
        ]
    }
}

struct VerifyProjectDraft: Equatable, Sendable {
    var projectName: String
    var role: String
    var evidenceNote: String

    static let fixture = VerifyProjectDraft(
        projectName: "Trust Operations Workflow Redesign",
        role: "Project Lead",
        evidenceNote: "Portfolio link and summary note will connect in a later milestone."
    )

    var fieldRows: [VerifyDraftFieldRow] {
        [
            VerifyDraftFieldRow(title: "Project name", value: projectName),
            VerifyDraftFieldRow(title: "Role", value: role),
            VerifyDraftFieldRow(title: "Evidence note", value: evidenceNote)
        ]
    }
}
