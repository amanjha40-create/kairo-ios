import Foundation

enum HomeOverviewFixtureKind: String, CaseIterable, Equatable, Sendable {
    case populated
    case empty
    case loading
    case error
}

struct HomeOverviewState: Equatable, Sendable {
    let header: HomeHeader
    let phase: HomeOverviewPhase

    static func `default`(isDemoMode: Bool) -> HomeOverviewState {
        isDemoMode
            ? populatedFixture(dataSourceLabel: "Demo data")
            : loading(header: .placeholder)
    }

    static func populatedFixture(dataSourceLabel: String = "Demo data") -> HomeOverviewState {
        HomeOverviewState(
            header: .fixture,
            phase: .populated(
                HomeOverviewContent(
                    dataSourceLabel: dataSourceLabel,
                    trustScore: HomeTrustScore(
                        score: 72,
                        status: "Building strong trust",
                        progress: 0.72,
                        supportingCopy: "Verify more of your career to strengthen your Trust Passport."
                    ),
                    recommendation: HomeRecommendation(
                        title: "Verify current employment",
                        supportingCopy: "This can make your Trust Passport more useful to employers and institutions.",
                        actionTitle: "Start verification",
                        destinationTab: .verify
                    ),
                    trustTasks: [
                        HomeTrustTask(
                            priority: 1,
                            systemImage: "checkmark.shield",
                            title: "Verify current employment",
                            valueStatement: "Show employers that your current role is confirmed.",
                            status: .pending,
                            destinationTab: .verify
                        ),
                        HomeTrustTask(
                            priority: 2,
                            systemImage: "graduationcap",
                            title: "Add your highest education",
                            valueStatement: "Strengthen your Trust Passport with your strongest academic signal.",
                            status: .pending,
                            destinationTab: .career
                        ),
                        HomeTrustTask(
                            priority: 3,
                            systemImage: "checkmark.seal",
                            title: "Add a professional certification",
                            valueStatement: "Show specialised expertise once certifications are connected.",
                            status: .comingSoon,
                            destinationTab: nil
                        ),
                        HomeTrustTask(
                            priority: 4,
                            systemImage: "briefcase",
                            title: "Add your previous employment",
                            valueStatement: "Complete your timeline with more verified experience.",
                            status: .pending,
                            destinationTab: .career
                        )
                    ],
                    verificationRequests: [
                        HomeVerificationRequest(
                            title: "Employment verification",
                            organization: "BrightPath Technologies",
                            status: "Awaiting your approval",
                            destinationTab: .verify
                        )
                    ],
                    profileCompletion: HomeProfileCompletion(
                        percentage: 68,
                        supportingCopy: "Add more verified career details to make your Trust Passport more complete.",
                        destinationTab: .career
                    ),
                    recentActivity: [
                        HomeActivityItem(title: "Email verified", relativeTime: "Just now"),
                        HomeActivityItem(title: "Mobile number verified", relativeTime: "18 minutes ago"),
                        HomeActivityItem(title: "Trust Passport created", relativeTime: "Today")
                    ],
                    recentPassportViews: [
                        HomePassportViewItem(
                            title: "Northstar Labs viewed your Trust Passport",
                            relativeTime: "2 hours ago"
                        )
                    ]
                )
            )
        )
    }

    static func emptyFixture(dataSourceLabel: String = "Demo data") -> HomeOverviewState {
        HomeOverviewState(
            header: .fixture,
            phase: .empty(
                HomeOverviewContent(
                    dataSourceLabel: dataSourceLabel,
                    trustScore: HomeTrustScore(
                        score: nil,
                        status: "Trust Score coming soon",
                        progress: nil,
                        supportingCopy: "Complete your first professional verification to preview how your trust begins to grow."
                    ),
                    recommendation: HomeRecommendation(
                        title: "Verify your current employment",
                        supportingCopy: "This is the fastest next step to make your Trust Passport more useful.",
                        actionTitle: "Start verification",
                        destinationTab: .verify
                    ),
                    trustTasks: [
                        HomeTrustTask(
                            priority: 1,
                            systemImage: "checkmark.shield",
                            title: "Verify current employment",
                            valueStatement: "Turn your current role into a reusable trust signal.",
                            status: .pending,
                            destinationTab: .verify
                        ),
                        HomeTrustTask(
                            priority: 2,
                            systemImage: "graduationcap",
                            title: "Add your highest education",
                            valueStatement: "Give your Trust Passport a stronger academic foundation.",
                            status: .pending,
                            destinationTab: .career
                        ),
                        HomeTrustTask(
                            priority: 3,
                            systemImage: "checkmark.seal",
                            title: "Add a professional certification",
                            valueStatement: "Certifications will strengthen trust once this area is connected.",
                            status: .comingSoon,
                            destinationTab: nil
                        )
                    ],
                    verificationRequests: [],
                    profileCompletion: HomeProfileCompletion(
                        percentage: 68,
                        supportingCopy: "Add more verified career details to make your Trust Passport more complete.",
                        destinationTab: .career
                    ),
                    recentActivity: [
                        HomeActivityItem(title: "Email verified", relativeTime: "Today"),
                        HomeActivityItem(title: "Mobile number verified", relativeTime: "Today"),
                        HomeActivityItem(title: "Trust Passport created", relativeTime: "Today")
                    ],
                    recentPassportViews: []
                )
            )
        )
    }

    static func loadingFixture() -> HomeOverviewState {
        HomeOverviewState(
            header: .fixture,
            phase: .loading
        )
    }

    static func loading(header: HomeHeader) -> HomeOverviewState {
        HomeOverviewState(
            header: header,
            phase: .loading
        )
    }

    static func errorFixture() -> HomeOverviewState {
        HomeOverviewState(
            header: .fixture,
            phase: .error(
                HomeOverviewErrorState(
                    title: "Home overview unavailable",
                    message: "Kairo could not prepare your trust overview preview. Try again when the next demo data set is available."
                )
            )
        )
    }

    static func error(
        header: HomeHeader,
        title: String,
        message: String
    ) -> HomeOverviewState {
        HomeOverviewState(
            header: header,
            phase: .error(
                HomeOverviewErrorState(
                    title: title,
                    message: message
                )
            )
        )
    }

    static func live(
        header: HomeHeader,
        content: HomeOverviewContent,
        isEmpty: Bool
    ) -> HomeOverviewState {
        HomeOverviewState(
            header: header,
            phase: isEmpty ? .empty(content) : .populated(content)
        )
    }
}

enum HomeOverviewPhase: Equatable, Sendable {
    case loading
    case populated(HomeOverviewContent)
    case empty(HomeOverviewContent)
    case error(HomeOverviewErrorState)
}

struct HomeHeader: Equatable, Sendable {
    let greeting: String
    let firstName: String
    let supportingCopy: String
    let initials: String

    static let placeholder = HomeHeader(
        greeting: "Welcome back,",
        firstName: "there",
        supportingCopy: "Kairo is preparing your latest trust snapshot.",
        initials: "KA"
    )

    static let fixture = HomeHeader(
        greeting: "Good morning,",
        firstName: "Aarav",
        supportingCopy: "Your professional trust is growing.",
        initials: "AA"
    )
}

struct HomeOverviewContent: Equatable, Sendable {
    let dataSourceLabel: String
    let trustScore: HomeTrustScore
    let recommendation: HomeRecommendation
    let trustTasks: [HomeTrustTask]
    let verificationRequests: [HomeVerificationRequest]
    let profileCompletion: HomeProfileCompletion
    let recentActivity: [HomeActivityItem]
    let recentPassportViews: [HomePassportViewItem]

    var visibleTrustTasks: [HomeTrustTask] {
        Array(trustTasks.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.title < rhs.title
            }

            return lhs.priority < rhs.priority
        }.prefix(3))
    }
}

struct HomeTrustScore: Equatable, Sendable {
    let score: Int?
    let status: String
    let progress: Double?
    let supportingCopy: String
}

struct HomeRecommendation: Equatable, Sendable {
    let title: String
    let supportingCopy: String
    let actionTitle: String
    let destinationTab: CandidateTab
}

struct HomeTrustTask: Equatable, Identifiable, Sendable {
    enum Status: Equatable, Sendable {
        case pending
        case complete
        case comingSoon

        var title: String {
            switch self {
            case .pending:
                "Pending"
            case .complete:
                "Complete"
            case .comingSoon:
                "Available in Career"
            }
        }
    }

    let priority: Int
    let systemImage: String
    let title: String
    let valueStatement: String
    let status: Status
    let destinationTab: CandidateTab?

    var id: String { title }
}

struct HomeVerificationRequest: Equatable, Identifiable, Sendable {
    let title: String
    let organization: String
    let status: String
    let destinationTab: CandidateTab

    var id: String { "\(title)-\(organization)" }
}

struct HomeProfileCompletion: Equatable, Sendable {
    private(set) var percentage: Int
    let supportingCopy: String
    let destinationTab: CandidateTab

    init(percentage: Int, supportingCopy: String, destinationTab: CandidateTab) {
        self.percentage = min(max(percentage, 0), 100)
        self.supportingCopy = supportingCopy
        self.destinationTab = destinationTab
    }

    var progress: Double {
        Double(percentage) / 100
    }
}

struct HomeActivityItem: Equatable, Identifiable, Sendable {
    let title: String
    let relativeTime: String

    var id: String { "\(title)-\(relativeTime)" }
}

struct HomePassportViewItem: Equatable, Identifiable, Sendable {
    let title: String
    let relativeTime: String

    var id: String { "\(title)-\(relativeTime)" }
}

struct HomeOverviewErrorState: Equatable, Sendable {
    let title: String
    let message: String
}
