import Foundation

nonisolated enum CareerOverviewFixtureKind: String, CaseIterable, Equatable, Sendable {
    case populated
    case empty
    case loading
    case error
}

nonisolated struct CareerOverviewState: Equatable, Sendable {
    let summary: CareerProfessionalSummary
    let dataSourceLabel: String
    let phase: CareerOverviewPhase

    nonisolated static func `default`(isDemoMode: Bool) -> CareerOverviewState {
        populatedFixture(dataSourceLabel: isDemoMode ? "Demo data" : "Preview data")
    }

    nonisolated static func populatedFixture(dataSourceLabel: String = "Demo data") -> CareerOverviewState {
        CareerOverviewState(
            summary: .fixture,
            dataSourceLabel: dataSourceLabel,
            phase: .populated(
                CareerOverviewContent(
                    employment: [
                        CareerEmploymentItem(
                            routeID: "fixture_employment_1",
                            company: "Northline Career Services",
                            role: "Trust & Operations Associate",
                            dateRange: "Jan 2024 - Present",
                            verificationStatus: .verified,
                            allowsEdit: true,
                            allowsDelete: false
                        ),
                        CareerEmploymentItem(
                            routeID: "fixture_employment_2",
                            company: "BrightPath Technologies",
                            role: "Candidate Success Specialist",
                            dateRange: "Aug 2021 - Dec 2023",
                            verificationStatus: .pendingVerification,
                            allowsEdit: true,
                            allowsDelete: false
                        ),
                        CareerEmploymentItem(
                            routeID: "fixture_employment_3",
                            company: "Horizon Works",
                            role: "Operations Analyst",
                            dateRange: "Jul 2019 - Jul 2021",
                            verificationStatus: .notVerified,
                            allowsEdit: true,
                            allowsDelete: true
                        )
                    ],
                    education: [
                        CareerEducationItem(
                            routeID: "fixture_education_1",
                            institution: "Christ University",
                            degree: "BBA, Human Resources & Operations",
                            dateRange: "2016 - 2019",
                            verificationStatus: .verified
                        ),
                        CareerEducationItem(
                            routeID: "fixture_education_2",
                            institution: "St. Xavier's College",
                            degree: "Certificate in Business Communication",
                            dateRange: "2018",
                            verificationStatus: .notVerified
                        )
                    ],
                    certifications: [
                        CareerCertificationItem(
                            routeID: "fixture_certification_1",
                            title: "People Operations Foundations",
                            issuer: "Northline Academy",
                            issueDate: "Mar 2025",
                            verificationStatus: .verified,
                            hasDocument: true
                        ),
                        CareerCertificationItem(
                            routeID: "fixture_certification_2",
                            title: "Candidate Experience Design",
                            issuer: "BrightPath Learning",
                            issueDate: "Nov 2023",
                            verificationStatus: .pendingVerification,
                            hasDocument: false
                        )
                    ],
                    projects: [
                        CareerProjectItem(
                            routeID: "fixture_project_1",
                            title: "Career Trust Onboarding Pilot",
                            role: "Program Lead",
                            duration: "6 months",
                            portfolioLinkTitle: "Portfolio link",
                            verificationStatus: .verified
                        ),
                        CareerProjectItem(
                            routeID: "fixture_project_2",
                            title: "University Hiring Readiness Workshop",
                            role: "Facilitator",
                            duration: "3 months",
                            portfolioLinkTitle: "Portfolio link",
                            verificationStatus: nil
                        )
                    ],
                    skills: [
                        CareerSkillItem(
                            routeID: "fixture_skill_1",
                            name: "Candidate Operations",
                            verificationStatus: .verified
                        ),
                        CareerSkillItem(
                            routeID: "fixture_skill_2",
                            name: "Employment Verification",
                            verificationStatus: .verified
                        ),
                        CareerSkillItem(
                            routeID: "fixture_skill_3",
                            name: "Process Design",
                            verificationStatus: .verified
                        ),
                        CareerSkillItem(
                            routeID: "fixture_skill_4",
                            name: "Stakeholder Communication",
                            verificationStatus: .verified
                        ),
                        CareerSkillItem(
                            routeID: "fixture_skill_5",
                            name: "University Outreach",
                            verificationStatus: .pendingVerification
                        ),
                        CareerSkillItem(
                            routeID: "fixture_skill_6",
                            name: "Project Coordination",
                            verificationStatus: .pendingVerification
                        ),
                        CareerSkillItem(
                            routeID: "fixture_skill_7",
                            name: "Trust Operations",
                            verificationStatus: .notVerified
                        ),
                        CareerSkillItem(
                            routeID: "fixture_skill_8",
                            name: "People Experience",
                            verificationStatus: .notVerified
                        )
                    ],
                    portfolio: [
                        CareerPortfolioItem(
                            routeID: "fixture_portfolio_1",
                            title: "Candidate Experience Case Study",
                            description: "A work sample from the existing Portfolio collection.",
                            verificationStatus: .notVerified,
                            hasDocument: true,
                            url: URL(string: "https://example.invalid/case-study"),
                            tags: ["Research", "Accessibility", "iOS"],
                            originalFilename: "candidate-experience-case-study.pdf",
                            byteSize: 2_048_000,
                            createdAt: Date(timeIntervalSince1970: 1_735_689_600),
                            updatedAt: Date(timeIntervalSince1970: 1_756_684_800)
                        )
                    ]
                )
            )
        )
    }

    nonisolated static func emptyFixture(dataSourceLabel: String = "Demo data") -> CareerOverviewState {
        CareerOverviewState(
            summary: .emptyFixture,
            dataSourceLabel: dataSourceLabel,
            phase: .empty(
                CareerOverviewContent(
                    employment: [],
                    education: [],
                    certifications: [],
                    projects: [],
                    skills: [],
                    portfolio: []
                )
            )
        )
    }

    nonisolated static func loadingFixture(dataSourceLabel: String = "Demo data") -> CareerOverviewState {
        CareerOverviewState(
            summary: .fixture,
            dataSourceLabel: dataSourceLabel,
            phase: .loading
        )
    }

    nonisolated static func errorFixture(dataSourceLabel: String = "Demo data") -> CareerOverviewState {
        CareerOverviewState(
            summary: .fixture,
            dataSourceLabel: dataSourceLabel,
            phase: .error(
                CareerOverviewErrorState(
                    title: "Career overview unavailable",
                    message: "KairoID could not prepare your professional timeline preview. Try again when local fixture data is available."
                )
            )
        )
    }

    nonisolated static func loading(
        summary: CareerProfessionalSummary,
        dataSourceLabel: String = "Live data"
    ) -> CareerOverviewState {
        CareerOverviewState(
            summary: summary,
            dataSourceLabel: dataSourceLabel,
            phase: .loading
        )
    }

    nonisolated static func error(
        summary: CareerProfessionalSummary,
        title: String,
        message: String,
        dataSourceLabel: String = "Live data"
    ) -> CareerOverviewState {
        CareerOverviewState(
            summary: summary,
            dataSourceLabel: dataSourceLabel,
            phase: .error(
                CareerOverviewErrorState(
                    title: title,
                    message: message
                )
            )
        )
    }

    nonisolated static func live(
        summary: CareerProfessionalSummary,
        dataSourceLabel: String,
        content: CareerOverviewContent,
        isEmpty: Bool
    ) -> CareerOverviewState {
        CareerOverviewState(
            summary: summary,
            dataSourceLabel: dataSourceLabel,
            phase: isEmpty ? .empty(content) : .populated(content)
        )
    }
}

nonisolated enum CareerOverviewPhase: Equatable, Sendable {
    case loading
    case populated(CareerOverviewContent)
    case empty(CareerOverviewContent)
    case error(CareerOverviewErrorState)
}

nonisolated enum CareerOverviewSection: String, CaseIterable, Equatable, Sendable {
    case professionalSummary
    case employment
    case education
    case certifications
    case skills
    case projects
    case portfolio

    var title: String {
        switch self {
        case .professionalSummary:
            "Professional Summary"
        case .employment:
            "Employment"
        case .education:
            "Education"
        case .certifications:
            "Certifications"
        case .skills:
            "Skills"
        case .projects:
            "Projects"
        case .portfolio:
            "Portfolio"
        }
    }
}

nonisolated enum CareerVerificationTone: Equatable, Sendable {
    case success
    case pending
    case attention
    case rejected
    case withdrawn
    case draft
    case candidateProvided
}

nonisolated struct CareerVerificationBadgeStyle: Equatable, Sendable {
    let title: String
    let symbol: String
    let tone: CareerVerificationTone
}

nonisolated enum CareerVerificationStatus: Equatable, Sendable {
    case verified
    case pendingVerification
    case notVerified
    case precise(String)

    init(rawBackendValue: String) {
        switch rawBackendValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "verified", "approved": self = .verified
        case "pending", "pending_review", "pending_verification", "awaiting_verification": self = .pendingVerification
        case "self_declared", "candidate_provided", "not_verified", "unverified", "missing", "withdrawn", "withdrawn_by_candidate": self = .notVerified
        default: self = .precise(rawBackendValue)
        }
    }

    var badgeStyle: CareerVerificationBadgeStyle {
        switch self {
        case .verified:
            CareerVerificationBadgeStyle(
                title: "Verified",
                symbol: "checkmark.seal.fill",
                tone: .success
            )
        case .pendingVerification:
            CareerVerificationBadgeStyle(
                title: "Pending",
                symbol: "clock.badge.checkmark.fill",
                tone: .pending
            )
        case .notVerified:
            CareerVerificationBadgeStyle(
                title: ProductStatusLanguage.candidateProvided,
                symbol: "circle.dashed",
                tone: .candidateProvided
            )
        case .precise(let value):
            Self.preciseBadgeStyle(for: value)
        }
    }

    private static func preciseBadgeStyle(for rawValue: String) -> CareerVerificationBadgeStyle {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return switch value {
        case "partially_verified", "partial_match":
            CareerVerificationBadgeStyle(title: "Partially verified", symbol: "checkmark.circle.badge.questionmark", tone: .pending)
        case "submitted":
            CareerVerificationBadgeStyle(title: "Submitted", symbol: "paperplane.fill", tone: .pending)
        case "under_review", "in_review", "pending_admin_review", "pending_admin_re_review", "pending_admin_quality_review":
            CareerVerificationBadgeStyle(title: "Needs review", symbol: "clock.badge.checkmark.fill", tone: .pending)
        case "additional_info_requested", "awaiting_subject_corrections", "awaiting_information":
            CareerVerificationBadgeStyle(title: "Needs review", symbol: "exclamationmark.circle.fill", tone: .attention)
        case "rejected", "failed", "unable_to_verify", "cancelled", "expired":
            CareerVerificationBadgeStyle(title: ProductStatusLanguage.title(for: value), symbol: "xmark.circle.fill", tone: .rejected)
        case "withdrawn", "withdrawn_by_candidate":
            CareerVerificationBadgeStyle(title: "Withdrawn", symbol: "minus.circle.fill", tone: .withdrawn)
        case "draft", "pending_upload":
            CareerVerificationBadgeStyle(title: "Draft", symbol: "pencil", tone: .draft)
        default:
            CareerVerificationBadgeStyle(title: ProductStatusLanguage.unavailable, symbol: "questionmark.circle", tone: .draft)
        }
    }

    var accessibilityLabel: String {
        badgeStyle.title
    }

    var canStartVerification: Bool {
        switch self {
        case .notVerified: true
        case .precise(let raw):
            ["draft", "self_declared", "candidate_provided", "not_verified", "unverified", "missing"]
                .contains(raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        case .verified, .pendingVerification: false
        }
    }
}

nonisolated struct CareerProfessionalSummary: Equatable, Sendable {
    let initials: String
    let name: String
    let professionalHeadline: String
    let currentCompany: String
    let currentLocation: String
    let trustPassportStatus: String

    nonisolated static let fixture = CareerProfessionalSummary(
        initials: "AA",
        name: "Aarav Anand",
        professionalHeadline: "Trust & Operations Associate",
        currentCompany: "Northline Career Services",
        currentLocation: "Bengaluru, India",
        trustPassportStatus: "Active"
    )

    nonisolated static let emptyFixture = CareerProfessionalSummary(
        initials: "AA",
        name: "Aarav Anand",
        professionalHeadline: "Start shaping your verified professional history",
        currentCompany: "Add your current role",
        currentLocation: "Bengaluru, India",
        trustPassportStatus: "Ready"
    )

    nonisolated static let placeholder = CareerProfessionalSummary(
        initials: "KA",
        name: "KairoID member",
        professionalHeadline: "Preparing your professional history",
        currentCompany: "Current company not added yet",
        currentLocation: "Current location not added yet",
        trustPassportStatus: "Preparing"
    )
}

nonisolated struct CareerOverviewContent: Equatable, Sendable {
    let employment: [CareerEmploymentItem]
    let education: [CareerEducationItem]
    let certifications: [CareerCertificationItem]
    let projects: [CareerProjectItem]
    let skills: [CareerSkillItem]
    var portfolio: [CareerPortfolioItem] = []

    var visibleSections: [CareerOverviewSection] {
        var sections: [CareerOverviewSection] = [.professionalSummary]

        if !employment.isEmpty {
            sections.append(.employment)
        }

        if !education.isEmpty {
            sections.append(.education)
        }

        if !certifications.isEmpty {
            sections.append(.certifications)
        }

        if !skills.isEmpty {
            sections.append(.skills)
        }

        if !projects.isEmpty {
            sections.append(.projects)
        }

        if !portfolio.isEmpty {
            sections.append(.portfolio)
        }

        return sections
    }
}

nonisolated struct CareerDetailMetadata: Equatable, Sendable {
    let title: String
    let value: String
}

nonisolated struct CareerEmploymentItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let company: String
    let role: String
    let dateRange: String
    let verificationStatus: CareerVerificationStatus
    let allowsEdit: Bool
    let allowsDelete: Bool
    var detailMetadata: [CareerDetailMetadata] = []

    var id: String { routeID }
}

nonisolated struct CareerEducationItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let institution: String
    let degree: String
    let dateRange: String
    let verificationStatus: CareerVerificationStatus
    var detailMetadata: [CareerDetailMetadata] = []

    var id: String { routeID }
}

nonisolated struct CareerCertificationItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let title: String
    let issuer: String
    let issueDate: String
    let verificationStatus: CareerVerificationStatus
    let hasDocument: Bool
    var detailMetadata: [CareerDetailMetadata] = []
    var credentialURL: URL? = nil

    var id: String { routeID }
}

nonisolated struct CareerProjectItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let title: String
    let role: String
    let duration: String
    let portfolioLinkTitle: String
    let verificationStatus: CareerVerificationStatus?
    var detailMetadata: [CareerDetailMetadata] = []
    var projectURL: URL? = nil
    var repositoryURL: URL? = nil

    var links: [CareerRecordLink] {
        [CareerRecordLink(title: "Project URL", url: projectURL),
         CareerRecordLink(title: "Repository URL", url: repositoryURL)].compactMap { $0 }
    }

    var id: String { routeID }
}

nonisolated struct CareerSkillItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let name: String
    let verificationStatus: CareerVerificationStatus

    var id: String { routeID }
}

nonisolated struct CareerPortfolioItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let title: String
    let description: String?
    let verificationStatus: CareerVerificationStatus
    let hasDocument: Bool
    let url: URL?
    var tags: [String] = []
    var originalFilename: String? = nil
    var byteSize: Int? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    var id: String { routeID }
}

nonisolated struct CareerOverviewErrorState: Equatable, Sendable {
    let title: String
    let message: String
}
