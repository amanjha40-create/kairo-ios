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
                        statusTitle: "Ready to start",
                        actionTitle: "Start verification",
                        action: .startVerification(.employment)
                    ),
                    requests: [
                        VerifyRequest(
                            id: "employment-brightpath",
                            type: "Employment verification",
                            organization: "BrightPath Technologies",
                            requester: "Kairo candidate trust team",
                            requestedItem: "Current role and employment dates",
                            status: .pendingSubjectAcceptance,
                            dateLabel: "Requested 1 Aug 2026",
                            timelineSummary: "Request opened today",
                            requiredAction: "Review and approve the employment request",
                            supportingNote: "Your approval allows Kairo to begin the local verification preview.",
                            evidenceRequirement: "No evidence has been requested in this fixture yet.",
                            timeline: [
                                VerifyTimelineEvent(
                                    id: "fixture-employment-created",
                                    title: "Employment verification opened",
                                    source: "Kairo candidate trust team",
                                    dateLabel: "1 Aug 2026"
                                )
                            ],
                            availableActions: [.accept]
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
                            supportingNote: "This fixture preview does not send any information to an institution.",
                            evidenceRequirement: "Clarify the qualification details requested in this fixture.",
                            timeline: [
                                VerifyTimelineEvent(
                                    id: "fixture-education-requested",
                                    title: "Additional information requested",
                                    source: "Kairo education trust team",
                                    dateLabel: "31 Jul 2026"
                                )
                            ],
                            availableActions: [.submitInformation]
                        ),
                        VerifyRequest(
                            id: "employment-northstar",
                            type: "Employment verification",
                            organization: "Northstar Labs",
                            requester: "Kairo candidate trust team",
                            requestedItem: "Previous role confirmation",
                            status: .inProgress,
                            dateLabel: "Updated 30 Jul 2026",
                            timelineSummary: "Submitted 2 days ago",
                            requiredAction: "Waiting for employer review",
                            supportingNote: "Kairo will surface the next step when this verification changes.",
                            evidenceRequirement: "Employment evidence was already submitted in this fixture.",
                            timeline: [
                                VerifyTimelineEvent(
                                    id: "fixture-employment-submitted",
                                    title: "Verification submitted",
                                    source: "You",
                                    dateLabel: "30 Jul 2026"
                                )
                            ],
                            availableActions: []
                        ),
                        VerifyRequest(
                            id: "education-welingkar-review",
                            type: "Education verification",
                            organization: "Welingkar Institute of Management",
                            requester: "Kairo education trust team",
                            requestedItem: "MBA degree confirmation",
                            status: .pendingAdminReview,
                            dateLabel: "Updated 31 Jul 2026",
                            timelineSummary: "Under review since yesterday",
                            requiredAction: "No action needed right now",
                            supportingNote: "This fixture state represents an institution reviewing your record.",
                            evidenceRequirement: "Academic evidence is already attached in this fixture.",
                            timeline: [
                                VerifyTimelineEvent(
                                    id: "fixture-education-review",
                                    title: "Submitted for review",
                                    source: "You",
                                    dateLabel: "31 Jul 2026"
                                )
                            ],
                            availableActions: []
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
                            supportingNote: "This verification already strengthens your Trust Passport.",
                            evidenceRequirement: "Verification is complete.",
                            timeline: [
                                VerifyTimelineEvent(
                                    id: "fixture-employment-verified",
                                    title: "Employment verified",
                                    source: "BrightPath Technologies",
                                    dateLabel: "28 Jul 2026"
                                )
                            ],
                            availableActions: []
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
                            supportingNote: "Identity verification is already part of your Trust Passport foundation.",
                            evidenceRequirement: "Verification is complete.",
                            timeline: [
                                VerifyTimelineEvent(
                                    id: "fixture-identity-verified",
                                    title: "Identity verified",
                                    source: "Kairo identity trust team",
                                    dateLabel: "1 Aug 2026"
                                )
                            ],
                            availableActions: []
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
                            supportingNote: "Email verification is already active in your Trust Passport.",
                            evidenceRequirement: "Verification is complete.",
                            timeline: [
                                VerifyTimelineEvent(
                                    id: "fixture-email-verified",
                                    title: "Email ownership verified",
                                    source: "Kairo identity trust team",
                                    dateLabel: "1 Aug 2026"
                                )
                            ],
                            availableActions: []
                        )
                    ],
                    suggestions: [
                        VerifySuggestion(
                            id: "education",
                            kind: .education,
                            title: "Verify your highest education",
                            valueStatement: "Add stronger academic trust to your Passport.",
                            actionTitle: "Start",
                            action: .startVerification(.education)
                        ),
                        VerifySuggestion(
                            id: "certification",
                            kind: .certification,
                            title: "Verify a professional certification",
                            valueStatement: "Show specialised expertise with a trusted credential.",
                            actionTitle: "Start",
                            action: .startVerification(.certification)
                        ),
                        VerifySuggestion(
                            id: "project",
                            kind: .project,
                            title: "Add and verify a recent project",
                            valueStatement: "Turn practical work into a reusable signal of trust.",
                            actionTitle: "Start",
                            action: .startVerification(.project)
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
                    message: "Start with one important part of your career and build trust from there.",
                    primaryActionTitle: "Start your first verification",
                    primaryAction: .startVerification(.employment),
                    secondaryActionTitle: "View Trust Passport",
                    secondaryAction: .viewTrustPassport
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

    static func loading(header: VerifyHeader = .live) -> VerifyOverviewState {
        VerifyOverviewState(
            header: header,
            phase: .loading
        )
    }

    static func errorFixture() -> VerifyOverviewState {
        error(
            header: .fixture,
            title: "Verify overview unavailable",
            message: "Kairo could not prepare your Trust Center preview. Try again when local fixture data is available."
        )
    }

    static func error(
        header: VerifyHeader = .live,
        title: String,
        message: String
    ) -> VerifyOverviewState {
        VerifyOverviewState(
            header: header,
            phase: .error(
                VerifyOverviewErrorState(
                    title: title,
                    message: message
                )
            )
        )
    }

    static func live(
        header: VerifyHeader = .live,
        content: VerifyOverviewContent,
        isEmpty: Bool
    ) -> VerifyOverviewState {
        VerifyOverviewState(
            header: header,
            phase: isEmpty ? .empty(content.emptyContent) : .populated(content)
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

    nonisolated static let live = VerifyHeader(
        supportingLine: "Every completed verification makes your professional trust more reusable."
    )

    nonisolated static let fixture = live
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

nonisolated enum VerifyVerificationStatus: Equatable, Sendable {
    case draft
    case pendingSubjectAcceptance
    case accepted
    case pendingSubjectSubmission
    case pendingAdminReview
    case awaitingSubjectCorrections
    case pendingAdminReReview
    case approvedForOrganizationVerification
    case pendingOrganizationResolution
    case pendingOrganizationAcceptance
    case inProgress
    case awaitingInformation
    case verified
    case rejected
    case unableToVerify
    case cancelled
    case expired
    case unknown(String)

    static let displayOrder: [VerifyVerificationStatus] = [
        .draft,
        .pendingSubjectAcceptance,
        .accepted,
        .pendingSubjectSubmission,
        .awaitingInformation,
        .awaitingSubjectCorrections,
        .pendingAdminReview,
        .pendingAdminReReview,
        .approvedForOrganizationVerification,
        .pendingOrganizationResolution,
        .pendingOrganizationAcceptance,
        .inProgress,
        .verified,
        .rejected,
        .unableToVerify,
        .cancelled,
        .expired
    ]

    init(rawBackendValue: String) {
        switch rawBackendValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
        case "draft":
            self = .draft
        case "pending_subject_acceptance":
            self = .pendingSubjectAcceptance
        case "accepted":
            self = .accepted
        case "pending_subject_submission":
            self = .pendingSubjectSubmission
        case "pending_admin_review":
            self = .pendingAdminReview
        case "awaiting_subject_corrections":
            self = .awaitingSubjectCorrections
        case "pending_admin_re_review":
            self = .pendingAdminReReview
        case "approved_for_organization_verification":
            self = .approvedForOrganizationVerification
        case "pending_organization_resolution":
            self = .pendingOrganizationResolution
        case "pending_organization_acceptance":
            self = .pendingOrganizationAcceptance
        case "in_progress":
            self = .inProgress
        case "awaiting_information":
            self = .awaitingInformation
        case "verified":
            self = .verified
        case "rejected":
            self = .rejected
        case "unable_to_verify":
            self = .unableToVerify
        case "cancelled":
            self = .cancelled
        case "expired":
            self = .expired
        default:
            self = .unknown(rawBackendValue)
        }
    }

    var rawBackendValue: String {
        switch self {
        case .draft:
            "draft"
        case .pendingSubjectAcceptance:
            "pending_subject_acceptance"
        case .accepted:
            "accepted"
        case .pendingSubjectSubmission:
            "pending_subject_submission"
        case .pendingAdminReview:
            "pending_admin_review"
        case .awaitingSubjectCorrections:
            "awaiting_subject_corrections"
        case .pendingAdminReReview:
            "pending_admin_re_review"
        case .approvedForOrganizationVerification:
            "approved_for_organization_verification"
        case .pendingOrganizationResolution:
            "pending_organization_resolution"
        case .pendingOrganizationAcceptance:
            "pending_organization_acceptance"
        case .inProgress:
            "in_progress"
        case .awaitingInformation:
            "awaiting_information"
        case .verified:
            "verified"
        case .rejected:
            "rejected"
        case .unableToVerify:
            "unable_to_verify"
        case .cancelled:
            "cancelled"
        case .expired:
            "expired"
        case .unknown(let rawValue):
            rawValue
        }
    }

    var group: VerifyRequestGroup {
        switch self {
        case .draft,
             .pendingSubjectAcceptance,
             .accepted,
             .pendingSubjectSubmission,
             .awaitingSubjectCorrections,
             .awaitingInformation:
            .pending
        case .pendingAdminReview,
             .pendingAdminReReview,
             .approvedForOrganizationVerification,
             .pendingOrganizationResolution,
             .pendingOrganizationAcceptance,
             .inProgress,
             .unknown:
            .inProgress
        case .verified,
             .rejected,
             .unableToVerify,
             .cancelled,
             .expired:
            .completed
        }
    }

    var style: VerifyStatusStyle {
        switch self {
        case .draft:
            VerifyStatusStyle(
                title: "Draft",
                symbol: "square.and.pencil",
                tone: .neutral
            )
        case .pendingSubjectAcceptance:
            VerifyStatusStyle(
                title: "Awaiting your approval",
                symbol: "checkmark.circle",
                tone: .accent
            )
        case .accepted:
            VerifyStatusStyle(
                title: "Accepted",
                symbol: "checkmark.circle.fill",
                tone: .accent
            )
        case .pendingSubjectSubmission:
            VerifyStatusStyle(
                title: "Awaiting your submission",
                symbol: "paperplane",
                tone: .accent
            )
        case .pendingAdminReview:
            VerifyStatusStyle(
                title: "Under admin review",
                symbol: "hourglass",
                tone: .warning
            )
        case .awaitingSubjectCorrections:
            VerifyStatusStyle(
                title: "Corrections requested",
                symbol: "arrow.uturn.backward.circle",
                tone: .warning
            )
        case .pendingAdminReReview:
            VerifyStatusStyle(
                title: "Under re-review",
                symbol: "arrow.clockwise.circle",
                tone: .warning
            )
        case .approvedForOrganizationVerification:
            VerifyStatusStyle(
                title: "Approved for verification",
                symbol: "checkmark.shield",
                tone: .accent
            )
        case .pendingOrganizationResolution:
            VerifyStatusStyle(
                title: "Pending organization resolution",
                symbol: "building.2",
                tone: .warning
            )
        case .pendingOrganizationAcceptance:
            VerifyStatusStyle(
                title: "Pending organization acceptance",
                symbol: "building.columns",
                tone: .warning
            )
        case .inProgress:
            VerifyStatusStyle(
                title: "In progress",
                symbol: "clock.arrow.circlepath",
                tone: .accent
            )
        case .awaitingInformation:
            VerifyStatusStyle(
                title: "Additional information requested",
                symbol: "text.badge.plus",
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
        case .unableToVerify:
            VerifyStatusStyle(
                title: "Unable to verify",
                symbol: "questionmark.diamond",
                tone: .neutral
            )
        case .cancelled:
            VerifyStatusStyle(
                title: "Cancelled",
                symbol: "nosign",
                tone: .neutral
            )
        case .expired:
            VerifyStatusStyle(
                title: "Expired",
                symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tone: .neutral
            )
        case .unknown:
            VerifyStatusStyle(
                title: "Status unavailable",
                symbol: "questionmark.circle",
                tone: .neutral
            )
        }
    }

    var rank: Int {
        Self.displayOrder.firstIndex(of: self) ?? Self.displayOrder.count
    }
}

enum VerifyRequestActionTransition: Equatable, Sendable {
    case accept
    case decline
}

enum VerifyCallToAction: Equatable, Sendable {
    case startVerification(VerifyVerificationKind)
    case openRequest(String)
    case openCareer
    case viewTrustPassport
}

enum VerifyRequestAction: Equatable, Hashable, Sendable {
    case accept
    case submitInformation
    case submitForReview
    case resubmitForReview

    var buttonTitle: String {
        switch self {
        case .accept:
            "Accept request"
        case .submitInformation:
            "Provide information"
        case .submitForReview:
            "Submit for review"
        case .resubmitForReview:
            "Resubmit for review"
        }
    }
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

    var emptyContent: VerifyOverviewEmptyContent {
        VerifyOverviewEmptyContent(
            dataSourceLabel: dataSourceLabel,
            title: "No verification requests yet.",
            message: "Kairo will show real employment and education verification requests here as they are created for your records.",
            primaryActionTitle: "Continue profile",
            primaryAction: .openCareer,
            secondaryActionTitle: "View Trust Passport",
            secondaryAction: .viewTrustPassport
        )
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
    let actionTitle: String?
    let action: VerifyCallToAction?
}

struct VerifyRequest: Equatable, Identifiable, Sendable {
    let id: String
    let routeRequestID: String?
    let type: String
    let organization: String
    let requester: String
    let requestedItem: String
    let status: VerifyVerificationStatus
    let dateLabel: String
    let timelineSummary: String
    let requiredAction: String
    let supportingNote: String
    let evidenceRequirement: String
    let timeline: [VerifyTimelineEvent]
    let availableActions: [VerifyRequestAction]

    init(
        id: String,
        routeRequestID: String? = nil,
        type: String,
        organization: String,
        requester: String,
        requestedItem: String,
        status: VerifyVerificationStatus,
        dateLabel: String,
        timelineSummary: String,
        requiredAction: String,
        supportingNote: String,
        evidenceRequirement: String,
        timeline: [VerifyTimelineEvent],
        availableActions: [VerifyRequestAction]
    ) {
        self.id = id
        self.routeRequestID = routeRequestID
        self.type = type
        self.organization = organization
        self.requester = requester
        self.requestedItem = requestedItem
        self.status = status
        self.dateLabel = dateLabel
        self.timelineSummary = timelineSummary
        self.requiredAction = requiredAction
        self.supportingNote = supportingNote
        self.evidenceRequirement = evidenceRequirement
        self.timeline = timeline
        self.availableActions = availableActions
    }

    func acceptedPreview() -> VerifyRequest {
        VerifyRequest(
            id: id,
            routeRequestID: routeRequestID,
            type: type,
            organization: organization,
            requester: requester,
            requestedItem: requestedItem,
            status: .pendingAdminReview,
            dateLabel: "Updated just now",
            timelineSummary: "Approved and submitted locally",
            requiredAction: "Waiting for review",
            supportingNote: "This local preview confirms the next step without sending any data.",
            evidenceRequirement: evidenceRequirement,
            timeline: timeline + [
                VerifyTimelineEvent(
                    id: "\(id)-accepted-preview",
                    title: "Accepted locally",
                    source: "You",
                    dateLabel: "Just now"
                )
            ],
            availableActions: []
        )
    }

    func declinedPreview() -> VerifyRequest {
        VerifyRequest(
            id: id,
            routeRequestID: routeRequestID,
            type: type,
            organization: organization,
            requester: requester,
            requestedItem: requestedItem,
            status: .rejected,
            dateLabel: "Updated just now",
            timelineSummary: "Declined locally",
            requiredAction: "No further action",
            supportingNote: "This local preview records the decline only for the current session.",
            evidenceRequirement: evidenceRequirement,
            timeline: timeline + [
                VerifyTimelineEvent(
                    id: "\(id)-declined-preview",
                    title: "Declined locally",
                    source: "You",
                    dateLabel: "Just now"
                )
            ],
            availableActions: []
        )
    }
}

struct VerifyTimelineEvent: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let source: String
    let dateLabel: String
}

struct VerifySuggestion: Equatable, Identifiable, Sendable {
    let id: String
    let kind: VerifyVerificationKind?
    let title: String
    let valueStatement: String
    let actionTitle: String?
    let action: VerifyCallToAction?
    var isEnabled: Bool = true
    var availabilityNote: String?
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
    let primaryActionTitle: String?
    let primaryAction: VerifyCallToAction?
    let secondaryActionTitle: String?
    let secondaryAction: VerifyCallToAction?
}

struct VerifyOverviewErrorState: Equatable, Sendable {
    let title: String
    let message: String
}
