import Foundation

enum PassportOverviewFixtureKind: String, CaseIterable, Equatable, Sendable {
    case populated
    case empty
    case loading
    case error
}

struct PassportOverviewState: Equatable, Sendable {
    let header: PassportHeader
    let phase: PassportOverviewPhase

    static func `default`(isDemoMode: Bool) -> PassportOverviewState {
        populatedFixture(dataSourceLabel: isDemoMode ? "Demo data" : "Preview data")
    }

    static func populatedFixture(dataSourceLabel: String = "Demo data") -> PassportOverviewState {
        PassportOverviewState(
            header: .fixture,
            phase: .populated(
                PassportOverviewContent(
                    dataSourceLabel: dataSourceLabel,
                    trustScore: .available(
                        PassportTrustScore(
                            value: 72,
                            status: "Building strong trust",
                            progress: 0.72,
                            supportingCopy: "Your Trust Passport grows stronger as more of your professional history is verified.",
                            isFixture: true
                        )
                    ),
                    strengthSummary: [
                        PassportStrengthItem(title: "Identity", value: "Verified", status: .verified),
                        PassportStrengthItem(title: "Email", value: "Verified", status: .verified),
                        PassportStrengthItem(title: "Mobile", value: "Verified", status: .verified),
                        PassportStrengthItem(title: "Employment", value: "1 verified, 1 pending", status: .pendingVerification),
                        PassportStrengthItem(title: "Education", value: "1 verified", status: .verified),
                        PassportStrengthItem(title: "Certifications", value: "1 unverified", status: .notVerified),
                        PassportStrengthItem(title: "Profile", value: "Complete", status: .complete)
                    ],
                    identity: PassportIdentityDetails.fixture,
                    employment: [
                        PassportEmploymentRecord(
                            company: "BrightPath Technologies",
                            role: "Product Operations Manager",
                            dateRange: "Jan 2024 – Present",
                            verificationStatus: .verified,
                            evidenceSummary: "Employment letter and manager confirmation on file."
                        ),
                        PassportEmploymentRecord(
                            company: "Northstar Labs",
                            role: "Operations Associate",
                            dateRange: "Jun 2021 – Dec 2023",
                            verificationStatus: .pendingVerification,
                            evidenceSummary: "Employer response pending."
                        )
                    ],
                    education: [
                        PassportEducationRecord(
                            institution: "Welingkar Institute of Management",
                            qualification: "MBA",
                            dateRange: "2019 – 2021",
                            verificationStatus: .verified,
                            evidenceSummary: "Degree certificate reviewed."
                        )
                    ],
                    certifications: [
                        PassportCertificationRecord(
                            title: "Certified Scrum Product Owner",
                            issuer: "Scrum Alliance",
                            issueDate: "Issued 2025",
                            verificationStatus: .notVerified,
                            evidenceSummary: "Certificate upload placeholder."
                        )
                    ],
                    projects: [
                        PassportProjectRecord(
                            title: "Trust Operations Workflow Redesign",
                            role: "Project Lead",
                            date: "2025",
                            evidenceStatus: "Evidence added",
                            portfolioLinkTitle: "Portfolio link placeholder"
                        )
                    ],
                    timeline: .available([
                        PassportTimelineEvent(title: "Identity verified", dateLabel: "1 Aug 2026"),
                        PassportTimelineEvent(title: "Email verified", dateLabel: "1 Aug 2026"),
                        PassportTimelineEvent(title: "Mobile verified", dateLabel: "1 Aug 2026"),
                        PassportTimelineEvent(title: "Employment verified", dateLabel: "30 Jul 2026"),
                        PassportTimelineEvent(title: "Trust Passport created", dateLabel: "29 Jul 2026")
                    ])
                )
            )
        )
    }

    static func emptyFixture(dataSourceLabel: String = "Demo data") -> PassportOverviewState {
        PassportOverviewState(
            header: .fixture,
            phase: .empty(
                PassportOverviewEmptyContent(
                    dataSourceLabel: dataSourceLabel,
                    title: "Your Trust Passport is taking shape.",
                    message: "Add and verify your professional history to build a Passport you can reuse throughout your career."
                )
            )
        )
    }

    static func loadingFixture() -> PassportOverviewState {
        PassportOverviewState(
            header: .fixture,
            phase: .loading
        )
    }

    static func errorFixture() -> PassportOverviewState {
        PassportOverviewState(
            header: .fixture,
            phase: .error(
                PassportOverviewErrorState(
                    title: "Trust Passport unavailable",
                    message: "Kairo could not prepare your Trust Passport preview. Try again when local fixture data is available."
                )
            )
        )
    }

    static func loading(header: PassportHeader) -> PassportOverviewState {
        PassportOverviewState(header: header, phase: .loading)
    }

    static func error(
        header: PassportHeader,
        title: String,
        message: String
    ) -> PassportOverviewState {
        PassportOverviewState(
            header: header,
            phase: .error(
                PassportOverviewErrorState(
                    title: title,
                    message: message
                )
            )
        )
    }

    static func live(
        header: PassportHeader,
        dataSourceLabel: String,
        content: PassportOverviewContent,
        isEmpty: Bool
    ) -> PassportOverviewState {
        if isEmpty {
            return PassportOverviewState(
                header: header,
                phase: .empty(
                    PassportOverviewEmptyContent(
                        dataSourceLabel: dataSourceLabel,
                        title: "Your Trust Passport is taking shape.",
                        message: "Add and verify your professional history to build a Passport you can reuse throughout your career."
                    )
                )
            )
        }

        return PassportOverviewState(header: header, phase: .populated(content))
    }
}

enum PassportOverviewPhase: Equatable, Sendable {
    case loading
    case populated(PassportOverviewContent)
    case empty(PassportOverviewEmptyContent)
    case error(PassportOverviewErrorState)
}

enum PassportOverviewSection: String, CaseIterable, Equatable, Sendable {
    case trustScore
    case passportStrength
    case identity
    case employment
    case education
    case certifications
    case projects
    case trustTimeline
    case actions
}

enum PassportStatusTone: Equatable, Sendable {
    case verified
    case pending
    case neutral
    case accent
}

struct PassportStatusStyle: Equatable, Sendable {
    let title: String
    let symbol: String
    let tone: PassportStatusTone
}

enum PassportVerificationStatus: String, CaseIterable, Equatable, Sendable {
    case verified
    case pendingVerification
    case notVerified
    case complete
    case active

    var style: PassportStatusStyle {
        switch self {
        case .verified:
            PassportStatusStyle(title: "Verified", symbol: "checkmark.seal.fill", tone: .verified)
        case .pendingVerification:
            PassportStatusStyle(title: "Pending verification", symbol: "clock.badge.checkmark.fill", tone: .pending)
        case .notVerified:
            PassportStatusStyle(title: "Not verified", symbol: "circle.dashed", tone: .neutral)
        case .complete:
            PassportStatusStyle(title: "Complete", symbol: "checkmark.circle.fill", tone: .accent)
        case .active:
            PassportStatusStyle(title: "Active", symbol: "sparkles", tone: .accent)
        }
    }
}

struct PassportHeader: Equatable, Sendable {
    let initials: String
    let name: String
    let professionalHeadline: String
    let location: String
    let status: PassportVerificationStatus
    let identityTreatment: String
    let avatarURL: URL?

    static let fixture = PassportHeader(
        initials: "AM",
        name: "Aarav Mehta",
        professionalHeadline: "Product Operations Manager",
        location: "Bengaluru, India",
        status: .active,
        identityTreatment: "Reusable professional identity",
        avatarURL: nil
    )
}

struct PassportOverviewContent: Equatable, Sendable {
    let dataSourceLabel: String
    let trustScore: PassportTrustScoreContent
    let strengthSummary: [PassportStrengthItem]
    let identity: PassportIdentityDetails
    let employment: [PassportEmploymentRecord]
    let education: [PassportEducationRecord]
    let certifications: [PassportCertificationRecord]
    let projects: [PassportProjectRecord]
    let timeline: PassportTimelineContent

    var visibleSections: [PassportOverviewSection] {
        [
            .trustScore,
            .passportStrength,
            .identity,
            .employment,
            .education,
            .certifications,
            .projects,
            .trustTimeline,
            .actions
        ]
    }
}

struct PassportOverviewEmptyContent: Equatable, Sendable {
    let dataSourceLabel: String
    let title: String
    let message: String
}

enum PassportTrustScoreContent: Equatable, Sendable {
    case available(PassportTrustScore)
    case unavailable(PassportTrustScoreUnavailableState)
}

struct PassportTrustScore: Equatable, Sendable {
    let value: Int
    let status: String
    let progress: Double
    let supportingCopy: String
    let isFixture: Bool
}

struct PassportTrustScoreUnavailableState: Equatable, Sendable {
    let title: String
    let message: String
}

struct PassportStrengthItem: Equatable, Identifiable, Sendable {
    let title: String
    let value: String
    let status: PassportVerificationStatus

    var id: String { title }
}

struct PassportIdentityDetails: Equatable, Sendable {
    let fullName: String
    let emailAddress: String
    let mobileNumber: String
    let status: PassportVerificationStatus
    let lastVerifiedDate: String

    static let fixture = PassportIdentityDetails(
        fullName: "Aarav Mehta",
        emailAddress: "aarav.mehta@example.com",
        mobileNumber: "+91 98765 43210",
        status: .verified,
        lastVerifiedDate: "1 Aug 2026"
    )
}

struct PassportEmploymentRecord: Equatable, Identifiable, Sendable {
    let company: String
    let role: String
    let dateRange: String
    let verificationStatus: PassportVerificationStatus
    let evidenceSummary: String

    var id: String { "\(company)-\(role)" }
}

struct PassportEducationRecord: Equatable, Identifiable, Sendable {
    let institution: String
    let qualification: String
    let dateRange: String
    let verificationStatus: PassportVerificationStatus
    let evidenceSummary: String

    var id: String { "\(institution)-\(qualification)" }
}

struct PassportCertificationRecord: Equatable, Identifiable, Sendable {
    let title: String
    let issuer: String
    let issueDate: String
    let verificationStatus: PassportVerificationStatus
    let evidenceSummary: String

    var id: String { "\(title)-\(issuer)" }
}

struct PassportProjectRecord: Equatable, Identifiable, Sendable {
    let title: String
    let role: String
    let date: String
    let evidenceStatus: String
    let portfolioLinkTitle: String

    var id: String { "\(title)-\(role)" }
}

enum PassportTimelineContent: Equatable, Sendable {
    case available([PassportTimelineEvent])
    case unavailable(PassportUnavailableSectionState)
}

struct PassportTimelineEvent: Equatable, Identifiable, Sendable {
    let title: String
    let dateLabel: String

    var id: String { "\(title)-\(dateLabel)" }
}

struct PassportUnavailableSectionState: Equatable, Sendable {
    let title: String
    let message: String
}

struct PassportOverviewErrorState: Equatable, Sendable {
    let title: String
    let message: String
}
