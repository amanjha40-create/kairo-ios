import SwiftUI

struct HomeOverviewScreenView: View {
    let state: HomeOverviewState
    var retryAction: (() -> Void)?
    var refreshAction: (() async -> Void)?

    @EnvironmentObject private var router: AppRouter
    @Environment(\.appConfiguration) private var appConfiguration

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: KairoSpacing.large) {
                    header
                    content
                }
                .padding(.horizontal, KairoSpacing.large)
                .padding(.top, topContentPadding)
                .padding(.bottom, KairoSpacing.xxLarge)
            }
            .refreshableIfAvailable(action: refreshAction)
        }
        .background(
            LinearGradient(
                colors: [KairoColors.background, KairoColors.surfaceMuted.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.homeScreen)
    }

    private var topContentPadding: CGFloat {
        appConfiguration.isDemoModeEnabled ? 72 : KairoSpacing.large
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .loading:
            KairoLoadingStateView(
                title: "Preparing your Home overview",
                message: "Kairo is assembling your latest trust snapshot."
            )
        case .error(let errorState):
            KairoErrorStateView(
                title: errorState.title,
                message: errorState.message,
                retryAction: retryAction
            )
        case .populated(let content):
            populatedContent(content)
        case .empty(let content):
            emptyContent(content)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(state.header.greeting)
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textSecondary)

                    Text(state.header.firstName)
                        .font(KairoTypography.title)
                        .foregroundStyle(KairoColors.textPrimary)
                }

                Spacer(minLength: KairoSpacing.medium)

                HStack(spacing: KairoSpacing.small) {
                    Button(action: {}) {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(KairoColors.textPrimary)
                            .background(KairoColors.surface, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(KairoColors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(KairoAccessibilityID.homeNotificationsButton)
                    .accessibilityLabel("Notifications")
                    .accessibilityHint("Notifications will be added in a later milestone.")

                    ZStack {
                        Circle()
                            .fill(KairoColors.surface)

                        Text(state.header.initials)
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textPrimary)
                    }
                    .frame(width: 42, height: 42)
                    .overlay(
                        Circle()
                            .stroke(KairoColors.border, lineWidth: 1)
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Profile placeholder for \(state.header.firstName)")
                }
            }

            Text(state.header.supportingCopy)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }

    @ViewBuilder
    private func populatedContent(_ content: HomeOverviewContent) -> some View {
        trustScoreCard(content.trustScore, dataSourceLabel: content.dataSourceLabel)
        recommendationCard(content.recommendation)
        trustTasksSection(content.visibleTrustTasks)
        verificationRequestsSection(content.verificationRequests)
        profileCompletionCard(content.profileCompletion)
        recentActivitySection(content.recentActivity)
        recentPassportViewsSection(
            content.recentPassportViews,
            emptyMessage: "No Passport views yet. When organisations start reviewing your Trust Passport, you'll see a preview here."
        )
    }

    @ViewBuilder
    private func emptyContent(_ content: HomeOverviewContent) -> some View {
        trustScoreCard(content.trustScore, dataSourceLabel: content.dataSourceLabel)

        KairoEmptyStateView(
            title: "Your Home is ready to grow",
            message: "Kairo will keep turning your verified career milestones into reusable professional trust.",
            systemImage: "sparkles"
        )

        recommendationCard(content.recommendation)
        trustTasksSection(content.visibleTrustTasks)
        verificationRequestsSection(content.verificationRequests)
        profileCompletionCard(content.profileCompletion)
        recentActivitySection(content.recentActivity)
        recentPassportViewsSection(
            content.recentPassportViews,
            emptyMessage: "No Passport views yet. Once visibility insights are available, you'll see them here."
        )
    }

    private func trustScoreCard(_ trustScore: HomeTrustScore, dataSourceLabel: String) -> some View {
        KairoCard {
            trustScoreHeader(dataSourceLabel: dataSourceLabel)
            viewTrustPassportButton

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: KairoSpacing.large) {
                    trustScoreValue(trustScore)
                    trustScoreNarrative(trustScore)
                }

                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    trustScoreValue(trustScore)
                    trustScoreNarrative(trustScore)
                }
            }

            if let progress = trustScore.progress {
                ProgressView(value: progress)
                    .tint(KairoColors.brandPrimary)
                    .progressViewStyle(.linear)
                    .padding(.top, KairoSpacing.xxSmall)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.homeTrustScoreCard)
    }

    private func trustScoreHeader(dataSourceLabel: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text("Trust Score")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            HomeBadge(title: dataSourceLabel)
        }
    }

    private var viewTrustPassportButton: some View {
        KairoSecondaryButton(
            title: "View Trust Passport",
            accessibilityIdentifier: KairoAccessibilityID.homeViewTrustPassport,
            action: { router.selectTab(.passport) }
        )
    }

    private func trustScoreValue(_ trustScore: HomeTrustScore) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            if let score = trustScore.score {
                Text("\(score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(KairoColors.textPrimary)
                    .minimumScaleFactor(0.7)
            } else {
                Text("No score yet")
                    .font(KairoTypography.title)
                    .foregroundStyle(KairoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(trustScore.status)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trustScoreNarrative(_ trustScore: HomeTrustScore) -> some View {
        Text(trustScore.supportingCopy)
            .font(KairoTypography.body)
            .foregroundStyle(KairoColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func recommendationCard(_ recommendation: HomeRecommendation) -> some View {
        KairoCard {
            HomeSectionHeader(
                title: "Kairo recommends",
                accessibilityIdentifier: KairoAccessibilityID.homeRecommendation
            )

            Text(recommendation.title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Text(recommendation.supportingCopy)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HomeInlineButton(
                title: recommendation.actionTitle,
                accessibilityIdentifier: KairoAccessibilityID.homeStartVerification,
                action: { router.selectTab(recommendation.destinationTab) }
            )
        }
    }

    private func trustTasksSection(_ tasks: [HomeTrustTask]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            Text("Build your trust")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            KairoCard {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    if index > 0 {
                        Divider()
                    }

                    HStack(alignment: .top, spacing: KairoSpacing.medium) {
                        Image(systemName: task.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(KairoColors.brandPrimary)
                            .frame(width: 28, height: 28)
                            .background(KairoColors.surfaceMuted, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))

                        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                            HStack(alignment: .center, spacing: KairoSpacing.xSmall) {
                                Text(task.title)
                                    .font(KairoTypography.bodyStrong)
                                    .foregroundStyle(KairoColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                HomeStatusBadge(title: task.status.title)
                            }

                            Text(task.valueStatement)
                                .font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let destinationTab = task.destinationTab {
                                HomeInlineButton(
                                    title: "Open \(destinationTab.title)",
                                    action: { router.selectTab(destinationTab) }
                                )
                            } else {
                                Text("Available soon")
                                    .font(KairoTypography.caption)
                                    .foregroundStyle(KairoColors.textSecondary)
                                    .padding(.top, KairoSpacing.xxSmall)
                            }
                        }
                    }
                    .padding(.vertical, index == tasks.count - 1 ? 0 : KairoSpacing.xxSmall)
                }
            }
        }
    }

    private func verificationRequestsSection(_ requests: [HomeVerificationRequest]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            Text("Verification requests")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            if let request = requests.first {
                KairoCard {
                    HStack(alignment: .top, spacing: KairoSpacing.medium) {
                        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                            Text(request.title)
                                .font(KairoTypography.bodyStrong)
                                .foregroundStyle(KairoColors.textPrimary)

                            Text(request.organization)
                                .font(KairoTypography.body)
                                .foregroundStyle(KairoColors.textPrimary)

                            Text(request.status)
                                .font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.warning)
                        }

                        Spacer(minLength: KairoSpacing.medium)

                        HomeStatusBadge(title: "Awaiting approval")
                    }

                    KairoSecondaryButton(
                        title: "View request",
                        accessibilityIdentifier: KairoAccessibilityID.homeVerificationRequestAction,
                        action: { router.selectTab(request.destinationTab) }
                    )
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(KairoAccessibilityID.homeVerificationRequest)
            } else {
                HomeCompactEmptyCard(
                    systemImage: "tray",
                    title: "No verification requests yet",
                    message: "When organisations ask you to approve a verification, you'll see it here."
                )
                .accessibilityIdentifier(KairoAccessibilityID.homeVerificationRequest)
            }
        }
    }

    private func profileCompletionCard(_ profileCompletion: HomeProfileCompletion) -> some View {
        KairoCard {
            HomeSectionHeader(
                title: "Profile completion",
                accessibilityIdentifier: KairoAccessibilityID.homeProfileCompletion
            )

            Text("\(profileCompletion.percentage)% complete")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            ProgressView(value: profileCompletion.progress)
                .tint(KairoColors.accent)

            Text(profileCompletion.supportingCopy)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HomeInlineButton(
                title: "Continue profile",
                accessibilityIdentifier: KairoAccessibilityID.homeContinueProfile,
                action: { router.selectTab(profileCompletion.destinationTab) }
            )
        }
    }

    private func recentActivitySection(_ items: [HomeActivityItem]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            Text("Recent activity")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
                .accessibilityIdentifier(KairoAccessibilityID.homeRecentActivity)

            KairoCard {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                    }

                    HStack(alignment: .top, spacing: KairoSpacing.medium) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KairoColors.success)

                        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                            Text(item.title)
                                .font(KairoTypography.bodyStrong)
                                .foregroundStyle(KairoColors.textPrimary)

                            Text(item.relativeTime)
                                .font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.textSecondary)
                        }
                    }
                    .padding(.vertical, index == items.count - 1 ? 0 : KairoSpacing.xxSmall)
                }
            }
        }
    }

    private func recentPassportViewsSection(
        _ items: [HomePassportViewItem],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            HomeSectionHeader(
                title: "Recent Passport views",
                subtitle: "Visibility insights",
                accessibilityIdentifier: KairoAccessibilityID.homeRecentPassportViews
            )

            if let item = items.first {
                KairoCard {
                    Text(item.title)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.relativeTime)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
            } else {
                HomeCompactEmptyCard(
                    systemImage: "eye",
                    title: "No recent Passport views yet",
                    message: emptyMessage
                )
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func refreshableIfAvailable(action: (() async -> Void)?) -> some View {
        if let action {
            refreshable {
                await action()
            }
        } else {
            self
        }
    }
}

private struct HomeSectionHeader: View {
    let title: String
    var subtitle: String?
    var accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

private struct HomeBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(KairoTypography.caption)
            .foregroundStyle(KairoColors.brandPrimary)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xxSmall)
            .background(KairoColors.surfaceMuted, in: Capsule())
    }
}

private struct HomeStatusBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(KairoTypography.caption)
            .foregroundStyle(KairoColors.textSecondary)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xxSmall)
            .background(KairoColors.surfaceMuted.opacity(0.85), in: Capsule())
    }
}

private struct HomeInlineButton: View {
    let title: String
    var accessibilityIdentifier: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairoSpacing.xSmall) {
                Text(title)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .font(KairoTypography.headline)
            .foregroundStyle(KairoColors.brandPrimary)
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.small)
            .background(KairoColors.surface, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(KairoColors.border, lineWidth: 1)
            )
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
        .accessibilityRepresentation {
            Button(title, action: action)
                .accessibilityIdentifier(accessibilityIdentifier ?? title)
        }
    }
}

private struct HomeCompactEmptyCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        KairoCard {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KairoColors.accent)
                    .frame(width: 28, height: 28)
                    .background(KairoColors.surfaceMuted, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(title)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text(message)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
