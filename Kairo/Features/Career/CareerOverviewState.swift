import Foundation

enum CareerOverviewFixtureKind: String, CaseIterable, Equatable, Sendable {
    case populated
    case empty
    case loading
    case error
}

struct CareerOverviewState: Equatable, Sendable {
    let summary: CareerProfessionalSummary
    let dataSourceLabel: String
    let phase: CareerOverviewPhase

    static func `default`(isDemoMode: Bool) -> CareerOverviewState {
        populatedFixture(dataSourceLabel: isDemoMode ? "Demo data" : "Preview data")
    }

    static func populatedFixture(dataSourceLabel: String = "Demo data") -> CareerOverviewState {
        CareerOverviewState(
            summary: .fixture,
            dataSourceLabel: dataSourceLabel,
            phase: .populated(
                CareerOverviewContent(
                    employment: [
                        CareerEmploymentItem(
                            company: "Northline Career Services",
                            role: "Trust & Operations Associate",
                            dateRange: "Jan 2024 - Present",
                            verificationStatus: .verified
                        ),
                        CareerEmploymentItem(
                            company: "BrightPath Technologies",
                            role: "Candidate Success Specialist",
                            dateRange: "Aug 2021 - Dec 2023",
                            verificationStatus: .pendingVerification
                        ),
                        CareerEmploymentItem(
                            company: "Horizon Works",
                            role: "Operations Analyst",
                            dateRange: "Jul 2019 - Jul 2021",
                            verificationStatus: .notVerified
                        )
                    ],
                    education: [
                        CareerEducationItem(
                            institution: "Christ University",
                            degree: "BBA, Human Resources & Operations",
                            dateRange: "2016 - 2019",
                            verificationStatus: .verified
                        ),
                        CareerEducationItem(
                            institution: "St. Xavier's College",
                            degree: "Certificate in Business Communication",
                            dateRange: "2018",
                            verificationStatus: .notVerified
                        )
                    ],
                    certifications: [
                        CareerCertificationItem(
                            title: "People Operations Foundations",
                            issuer: "Northline Academy",
                            issueDate: "Mar 2025",
                            verificationStatus: .verified
                        ),
                        CareerCertificationItem(
                            title: "Candidate Experience Design",
                            issuer: "BrightPath Learning",
                            issueDate: "Nov 2023",
                            verificationStatus: .pendingVerification
                        )
                    ],
                    projects: [
                        CareerProjectItem(
                            title: "Career Trust Onboarding Pilot",
                            role: "Program Lead",
                            duration: "6 months",
                            portfolioLinkTitle: "Portfolio link",
                            verificationStatus: .verified
                        ),
                        CareerProjectItem(
                            title: "University Hiring Readiness Workshop",
                            role: "Facilitator",
                            duration: "3 months",
                            portfolioLinkTitle: "Portfolio link",
                            verificationStatus: nil
                        )
                    ],
                    skills: [
                        "Candidate Operations",
                        "Employment Verification",
                        "Process Design",
                        "Stakeholder Communication",
                        "University Outreach",
                        "Project Coordination",
                        "Trust Operations",
                        "People Experience"
                    ]
                )
            )
        )
    }

    static func emptyFixture(dataSourceLabel: String = "Demo data") -> CareerOverviewState {
        CareerOverviewState(
            summary: .emptyFixture,
            dataSourceLabel: dataSourceLabel,
            phase: .empty(
                CareerOverviewContent(
                    employment: [],
                    education: [],
                    certifications: [],
                    projects: [],
                    skills: []
                )
            )
        )
    }

    static func loadingFixture(dataSourceLabel: String = "Demo data") -> CareerOverviewState {
        CareerOverviewState(
            summary: .fixture,
            dataSourceLabel: dataSourceLabel,
            phase: .loading
        )
    }

    static func errorFixture(dataSourceLabel: String = "Demo data") -> CareerOverviewState {
        CareerOverviewState(
            summary: .fixture,
            dataSourceLabel: dataSourceLabel,
            phase: .error(
                CareerOverviewErrorState(
                    title: "Career overview unavailable",
                    message: "Kairo could not prepare your professional timeline preview. Try again when local fixture data is available."
                )
            )
        )
    }
}

enum CareerOverviewPhase: Equatable, Sendable {
    case loading
    case populated(CareerOverviewContent)
    case empty(CareerOverviewContent)
    case error(CareerOverviewErrorState)
}

enum CareerOverviewSection: String, CaseIterable, Equatable, Sendable {
    case professionalSummary
    case employment
    case education
    case certifications
    case projects
    case skills

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
        case .projects:
            "Projects"
        case .skills:
            "Skills"
        }
    }
}

enum CareerVerificationTone: Equatable, Sendable {
    case success
    case pending
    case neutral
}

struct CareerVerificationBadgeStyle: Equatable, Sendable {
    let title: String
    let symbol: String
    let tone: CareerVerificationTone
}

enum CareerVerificationStatus: String, CaseIterable, Equatable, Sendable {
    case verified
    case pendingVerification
    case notVerified

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
                title: "Pending Verification",
                symbol: "clock.badge.checkmark.fill",
                tone: .pending
            )
        case .notVerified:
            CareerVerificationBadgeStyle(
                title: "Not Verified",
                symbol: "circle.dashed",
                tone: .neutral
            )
        }
    }

    var accessibilityLabel: String {
        badgeStyle.title
    }
}

struct CareerProfessionalSummary: Equatable, Sendable {
    let initials: String
    let name: String
    let professionalHeadline: String
    let currentCompany: String
    let currentLocation: String
    let trustPassportStatus: String

    static let fixture = CareerProfessionalSummary(
        initials: "AA",
        name: "Aarav Anand",
        professionalHeadline: "Trust & Operations Associate",
        currentCompany: "Northline Career Services",
        currentLocation: "Bengaluru, India",
        trustPassportStatus: "Active"
    )

    static let emptyFixture = CareerProfessionalSummary(
        initials: "AA",
        name: "Aarav Anand",
        professionalHeadline: "Start shaping your verified professional history",
        currentCompany: "Add your current role",
        currentLocation: "Bengaluru, India",
        trustPassportStatus: "Ready"
    )
}

struct CareerOverviewContent: Equatable, Sendable {
    let employment: [CareerEmploymentItem]
    let education: [CareerEducationItem]
    let certifications: [CareerCertificationItem]
    let projects: [CareerProjectItem]
    let skills: [String]

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

        if !projects.isEmpty {
            sections.append(.projects)
        }

        if !skills.isEmpty {
            sections.append(.skills)
        }

        return sections
    }
}

struct CareerEmploymentItem: Equatable, Identifiable, Sendable {
    let company: String
    let role: String
    let dateRange: String
    let verificationStatus: CareerVerificationStatus

    var id: String { "\(company)-\(role)" }
}

struct CareerEducationItem: Equatable, Identifiable, Sendable {
    let institution: String
    let degree: String
    let dateRange: String
    let verificationStatus: CareerVerificationStatus

    var id: String { "\(institution)-\(degree)" }
}

struct CareerCertificationItem: Equatable, Identifiable, Sendable {
    let title: String
    let issuer: String
    let issueDate: String
    let verificationStatus: CareerVerificationStatus

    var id: String { "\(title)-\(issuer)" }
}

struct CareerProjectItem: Equatable, Identifiable, Sendable {
    let title: String
    let role: String
    let duration: String
    let portfolioLinkTitle: String
    let verificationStatus: CareerVerificationStatus?

    var id: String { "\(title)-\(role)" }
}

struct CareerOverviewErrorState: Equatable, Sendable {
    let title: String
    let message: String
}
