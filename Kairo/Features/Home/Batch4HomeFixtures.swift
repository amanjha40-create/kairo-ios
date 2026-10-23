import SwiftUI

/// In-memory visual states. Only the validated UI-test route can select these.
enum Batch4HomeScenario: String, CaseIterable {
    case onboarded, empty, partial, complete, attention, inProgress, noTasks
    case unavailable, loading, error, offline

    var state: HomeOverviewState {
        let header = HomeHeader(greeting: "Welcome back,", firstName: "Synthetic",
            supportingCopy: "Synthetic Home", initials: "SY")
        if self == .loading { return .loading(header: header) }
        if self == .error || self == .offline {
            return .error(header: header, title: self == .offline ? "You're offline" : "Home overview unavailable",
                message: "Synthetic read failure. Try again.")
        }
        let attention = HomeVerificationRequest(title: "Review invitation", organization: "Synthetic institution",
            status: "Awaiting your approval", authoritativeDestinationID: "synthetic-attention",
            destinationTab: .verify, needsAttention: true)
        let progress = HomeVerificationRequest(title: "Employment verification", organization: "Synthetic employer",
            status: "Pending KairoID Review", authoritativeDestinationID: "synthetic-progress",
            destinationTab: .verify)
        let finished = self == .complete || self == .noTasks
        let needsAttention = self == .attention || self == .onboarded
        let requests = needsAttention ? [attention, progress] : (self == .inProgress ? [progress] : [])
        return .live(header: header, content: .init(
            dataSourceLabel: "Synthetic preview",
            trustScore: .init(score: self == .empty || self == .unavailable ? nil : 72,
                status: self == .unavailable ? "Consent required" : ProductStatusLanguage.verificationIncomplete,
                progress: nil, supportingCopy: "Synthetic score, not a verification status", requiresConsent: self == .unavailable),
            recommendation: .init(title: finished ? "Review your Career" : "Add your education",
                supportingCopy: finished ? "Your existing Career details" : "Complete your professional history",
                actionTitle: "Continue profile", destinationTab: .career),
            trustTasks: finished ? [] : [
                .init(priority: 2, systemImage: "briefcase", title: "Add your employment history",
                    valueStatement: "Synthetic requirement", status: .pending, destinationTab: .career),
                .init(priority: 1, systemImage: "graduationcap", title: "Add your education",
                    valueStatement: "Synthetic requirement", status: .pending, destinationTab: .career)
            ], verificationRequests: requests,
            profileCompletion: .init(percentage: finished ? 100 : (self == .empty ? 0 : 45),
                supportingCopy: "Synthetic progress", destinationTab: .career),
            recentActivity: self == .empty ? [] : [.init(title: "Synthetic profile updated", relativeTime: "Today")],
            recentPassportViews: [], verificationRequestsAvailable: self != .unavailable,
            careerSummary: self == .empty ? "0 Employment · 0 Education" : "1 Employment · 1 Education"
        ), isEmpty: self == .empty)
    }
}

struct Batch4HomeFixtureView: View {
    let scenario: Batch4HomeScenario
    @State private var recovered = false

    var body: some View {
        HomeOverviewScreenView(state: recovered ? Batch4HomeScenario.onboarded.state : scenario.state,
            retryAction: { recovered = true }, refreshAction: { recovered = true })
    }
}
