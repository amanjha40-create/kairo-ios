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
                            verificationStatus: .verified
                        ),
                        CareerCertificationItem(
                            routeID: "fixture_certification_2",
                            title: "Candidate Experience Design",
                            issuer: "BrightPath Learning",
                            issueDate: "Nov 2023",
                            verificationStatus: .pendingVerification
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
                    skills: []
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
                    message: "Kairo could not prepare your professional timeline preview. Try again when local fixture data is available."
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

nonisolated enum CareerVerificationTone: Equatable, Sendable {
    case success
    case pending
    case neutral
}

nonisolated struct CareerVerificationBadgeStyle: Equatable, Sendable {
    let title: String
    let symbol: String
    let tone: CareerVerificationTone
}

nonisolated enum CareerVerificationStatus: String, CaseIterable, Equatable, Sendable {
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
        name: "Kairo member",
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

nonisolated struct CareerEmploymentItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let company: String
    let role: String
    let dateRange: String
    let verificationStatus: CareerVerificationStatus
    let allowsEdit: Bool
    let allowsDelete: Bool

    var id: String { routeID }
}

nonisolated struct CareerEducationItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let institution: String
    let degree: String
    let dateRange: String
    let verificationStatus: CareerVerificationStatus

    var id: String { routeID }
}

nonisolated struct CareerCertificationItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let title: String
    let issuer: String
    let issueDate: String
    let verificationStatus: CareerVerificationStatus

    var id: String { routeID }
}

nonisolated struct CareerProjectItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let title: String
    let role: String
    let duration: String
    let portfolioLinkTitle: String
    let verificationStatus: CareerVerificationStatus?

    var id: String { routeID }
}

nonisolated struct CareerSkillItem: Equatable, Identifiable, Sendable {
    let routeID: String
    let name: String
    let verificationStatus: CareerVerificationStatus

    var id: String { routeID }
}

nonisolated struct CareerOverviewErrorState: Equatable, Sendable {
    let title: String
    let message: String
}
