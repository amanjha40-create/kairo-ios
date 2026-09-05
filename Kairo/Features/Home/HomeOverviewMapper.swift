import Foundation
import SwiftUI

enum HomeOverviewMapper {
    static func map(_ overview: DashboardOverview) -> HomeOverviewState {
        let trustScore = makeTrustScore(from: overview.trustScore)
        let recommendation = makeRecommendation(from: overview)
        let content = HomeOverviewContent(
            dataSourceLabel: "Live data",
            trustScore: trustScore,
            recommendation: recommendation,
            trustTasks: makeTrustTasks(from: overview),
            verificationRequests: makeVerificationRequests(from: overview),
            profileCompletion: makeProfileCompletion(from: overview),
            recentActivity: makeRecentActivity(from: overview.recentActivity),
            recentPassportViews: makePassportViews(
                analytics: overview.recentShareAnalytics,
                activeShares: overview.activePassportShares.items
            )
        )

        return .live(
            header: makeHeader(from: overview.user, trustScore: trustScore),
            content: content,
            isEmpty: isEmpty(overview: overview)
        )
    }

    static func errorState(for error: Error, header: HomeHeader) -> HomeOverviewState {
        if case .transport = (error as? NetworkError) {
            return .error(
                header: header,
                title: "You're offline",
                message: "Kairo couldn't reach your Home data. Check your connection and try again."
            )
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError):
                return .error(
                    header: header,
                    title: "Home overview unavailable",
                    message: apiError.message
                )
            case .invalidResponse:
                return .error(
                    header: header,
                    title: "Home overview unavailable",
                    message: "Kairo received an unexpected Home response. Please try again."
                )
            case .invalidURL:
                return .error(
                    header: header,
                    title: "Home overview unavailable",
                    message: "Kairo's Home configuration is invalid."
                )
            case .transport, .unavailableInDemoMode:
                return .error(
                    header: header,
                    title: "You're offline",
                    message: "Kairo couldn't reach your Home data. Check your connection and try again."
                )
            }
        }

        return .error(
            header: header,
            title: "Home overview unavailable",
            message: error.localizedDescription
        )
    }

    static func requiresSessionRecovery(for error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            return true
        }

        return false
    }

    private static func makeHeader(from user: AppUser, trustScore: HomeTrustScore) -> HomeHeader {
        let displayName = firstName(from: user)
        return HomeHeader(
            greeting: greetingForCurrentTime(),
            firstName: displayName,
            supportingCopy: trustScore.score == nil
                ? "Keep building your Trust Passport."
                : "Your professional trust is growing.",
            initials: initials(from: user)
        )
    }

    private static func makeTrustScore(from trustScore: DashboardOverview.TrustScore) -> HomeTrustScore {
        let progress = trustScore.overall.map { max(0, min(100, $0)) }
        return HomeTrustScore(
            score: trustScore.overall,
            status: trustScoreStatusTitle(trustScore.status),
            progress: progress.map { Double($0) / 100 },
            supportingCopy: trustScoreSupportingCopy(trustScore)
        )
    }

    private static func makeRecommendation(from overview: DashboardOverview) -> HomeRecommendation {
        let code = overview.profileCompletion.nextRecommendedStep
            ?? overview.profileCompletion.missingRequirements.first
            ?? "complete_profile"
        let destination = destinationTab(for: code)

        return HomeRecommendation(
            title: recommendationTitle(for: code),
            supportingCopy: recommendationSupportingCopy(for: code, missingRequirements: overview.profileCompletion.missingRequirements),
            actionTitle: destination == .verify ? "Start verification" : "Continue profile",
            destinationTab: destination
        )
    }

    private static func makeTrustTasks(from overview: DashboardOverview) -> [HomeTrustTask] {
        var tasks: [HomeTrustTask] = overview.profileCompletion.missingRequirements.enumerated().map { index, requirement in
            HomeTrustTask(
                priority: index + 1,
                systemImage: iconName(for: requirement),
                title: taskTitle(for: requirement),
                valueStatement: taskValueStatement(for: requirement),
                status: .pending,
                destinationTab: destinationTab(for: requirement)
            )
        }

        if tasks.count < 3 {
            let completedTasks = overview.profileCompletion.completedSteps
                .filter { code in
                    !overview.profileCompletion.missingRequirements.contains(code)
                }
                .enumerated()
                .map { index, code in
                    HomeTrustTask(
                        priority: tasks.count + index + 1,
                        systemImage: iconName(for: code),
                        title: taskTitle(for: code),
                        valueStatement: "This part of your Trust Passport is already complete.",
                        status: .complete,
                        destinationTab: destinationTab(for: code)
                    )
                }

            tasks.append(contentsOf: completedTasks)
        }

        if tasks.isEmpty {
            tasks = [
                HomeTrustTask(
                    priority: 1,
                    systemImage: "checkmark.shield",
                    title: "Start your first verification",
                    valueStatement: "Use Verify to strengthen your Trust Passport with a reusable trust signal.",
                    status: .pending,
                    destinationTab: .verify
                )
            ]
        }

        return tasks
    }

    private static func makeVerificationRequests(
        from overview: DashboardOverview
    ) -> [HomeVerificationRequest] {
        overview.recentActivity
            .filter { $0.category == .verification }
            .prefix(1)
            .map { activity in
                HomeVerificationRequest(
                    title: activity.title,
                    organization: activity.detail ?? "Trust Center",
                    status: humanizedAction(activity.action),
                    destinationTab: .verify
                )
            }
    }

    private static func makeProfileCompletion(from overview: DashboardOverview) -> HomeProfileCompletion {
        HomeProfileCompletion(
            percentage: overview.profileCompletion.completionPercentage,
            supportingCopy: profileCompletionCopy(for: overview.profileCompletion),
            destinationTab: .career
        )
    }

    private static func makeRecentActivity(
        from items: [DashboardOverview.ActivityItem]
    ) -> [HomeActivityItem] {
        items.map {
            HomeActivityItem(
                title: $0.title,
                relativeTime: relativeTimeString(for: $0.occurredAt)
            )
        }
    }

    private static func makePassportViews(
        analytics: [DashboardOverview.ShareAnalyticsItem],
        activeShares: [DashboardOverview.ShareSummaryItem]
    ) -> [HomePassportViewItem] {
        if !analytics.isEmpty {
            return analytics.map { item in
                HomePassportViewItem(
                    title: passportViewTitle(label: item.label, totalViews: item.totalViews),
                    relativeTime: relativeTimeString(for: item.lastViewedAt)
                )
            }
        }

        return activeShares.map { item in
            HomePassportViewItem(
                title: item.label ?? "Shared Trust Passport",
                relativeTime: relativeTimeString(for: item.lastViewedAt ?? item.createdAt)
            )
        }
    }

    private static func isEmpty(overview: DashboardOverview) -> Bool {
        overview.trustScore.overall == nil &&
            overview.vaultSummary.totalItems == 0 &&
            overview.recentActivity.isEmpty &&
            overview.recentShareAnalytics.isEmpty &&
            overview.activePassportShares.count == 0
    }

    private static func firstName(from user: AppUser) -> String {
        if let fullName = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fullName.isEmpty,
           let firstName = fullName.split(separator: " ").first {
            return String(firstName)
        }

        let emailPrefix = user.email.split(separator: "@").first.map(String.init) ?? "there"
        return emailPrefix.capitalized
    }

    private static func initials(from user: AppUser) -> String {
        let parts = (user.fullName ?? user.email)
            .split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." || $0 == "_" })
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }

        let value = parts.joined()
        return value.isEmpty ? "KA" : value
    }

    private static func greetingForCurrentTime(date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5 ..< 12:
            return "Good morning,"
        case 12 ..< 17:
            return "Good afternoon,"
        default:
            return "Good evening,"
        }
    }

    private static func trustScoreStatusTitle(_ status: DashboardOverview.TrustScore.Status) -> String {
        switch status {
        case .consentRequired:
            "Consent required"
        case .incompleteVerification:
            "Incomplete verification"
        case .calculated:
            "Calculated"
        case .criticalManualFraudReview:
            "Manual review required"
        }
    }

    private static func trustScoreSupportingCopy(_ trustScore: DashboardOverview.TrustScore) -> String {
        if let manualReviewReason = trustScore.manualReviewReason, !manualReviewReason.isEmpty {
            return manualReviewReason
        }

        if let detail = trustScore.positiveContributors.first?.detail,
           !detail.isEmpty {
            return detail
        }

        if let detail = trustScore.negativeContributors.first?.detail,
           !detail.isEmpty {
            return detail
        }

        if let detail = trustScore.criticalOverrides.first?.detail,
           !detail.isEmpty {
            return detail
        }

        switch trustScore.status {
        case .consentRequired:
            return "Trust Score consent is required before Kairo can calculate your score."
        case .incompleteVerification:
            return "Complete more verifications to unlock your live Trust Score."
        case .calculated:
            return "Your Trust Score reflects the professional trust you've verified so far."
        case .criticalManualFraudReview:
            return "Kairo is reviewing your Trust Score before it can be used."
        }
    }

    private static func recommendationTitle(for code: String) -> String {
        switch code {
        case "complete_profile":
            return "Complete your profile"
        case "verify_identity":
            return "Finish identity verification"
        default:
            return taskTitle(for: code)
        }
    }

    private static func recommendationSupportingCopy(
        for code: String,
        missingRequirements: [String]
    ) -> String {
        if let firstRequirement = missingRequirements.first {
            return "Next up: \(taskTitle(for: firstRequirement))."
        }

        switch code {
        case "complete_profile":
            return "Keep adding verified profile details to strengthen your Trust Passport."
        case "verify_identity":
            return "Finish identity verification to keep your Trust Passport moving."
        default:
            return "Kairo is using your live onboarding status to guide the next step."
        }
    }

    private static func profileCompletionCopy(
        for profileCompletion: DashboardOverview.ProfileCompletion
    ) -> String {
        if let firstRequirement = profileCompletion.missingRequirements.first {
            return "Next up: \(taskTitle(for: firstRequirement))."
        }

        if profileCompletion.isOnboardingComplete {
            return "Your onboarding is complete. Keep adding verified career milestones to strengthen your Passport."
        }

        return "Keep adding verified profile details to make your Trust Passport more complete."
    }

    private static func taskTitle(for code: String) -> String {
        switch code {
        case "headline":
            return "Add your professional headline"
        case "employment", "employment_history":
            return "Add your employment history"
        case "education":
            return "Add your education"
        case "certification", "certifications":
            return "Add your certifications"
        case "project", "projects":
            return "Add your projects"
        case "skills":
            return "Add your skills"
        case "current_role":
            return "Add your current role"
        case "location", "location_city", "location_country":
            return "Add your location"
        case "verify_email", "email_verified":
            return "Verify your email"
        case "verify_phone", "phone_verified":
            return "Verify your mobile number"
        case "verify_identity":
            return "Finish identity verification"
        case "passport_ready":
            return "Activate your Trust Passport"
        default:
            return humanized(code)
        }
    }

    private static func taskValueStatement(for code: String) -> String {
        switch destinationTab(for: code) {
        case .verify:
            return "This step can strengthen your Trust Passport with a reusable trust signal."
        case .career:
            return "This step can make your professional history more useful across Kairo."
        case .passport, .home, .more:
            return "This step can strengthen your Trust Passport."
        }
    }

    private static func iconName(for code: String) -> String {
        switch code {
        case "headline", "current_role":
            return "person.text.rectangle"
        case "employment", "employment_history":
            return "briefcase"
        case "education":
            return "graduationcap"
        case "certification", "certifications":
            return "checkmark.seal"
        case "project", "projects":
            return "hammer"
        case "skills":
            return "sparkles"
        case "verify_email":
            return "envelope.badge"
        case "verify_phone":
            return "phone.badge.checkmark"
        case "verify_identity", "passport_ready":
            return "checkmark.shield"
        default:
            return "circle.grid.2x2"
        }
    }

    private static func destinationTab(for code: String) -> CandidateTab {
        switch code {
        case "verify_identity", "verify_email", "email_verified", "verify_phone", "phone_verified":
            return .verify
        default:
            return .career
        }
    }

    private static func relativeTimeString(for date: Date?) -> String {
        guard let date else {
            return "Recently"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func passportViewTitle(label: String?, totalViews: Int) -> String {
        let descriptor = totalViews == 1 ? "1 view" : "\(totalViews) views"

        if let label, !label.isEmpty {
            return "\(label) • \(descriptor)"
        }

        return "\(descriptor) on your Trust Passport"
    }

    private static func humanizedAction(_ value: String) -> String {
        humanized(value)
    }

    private static func humanized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
