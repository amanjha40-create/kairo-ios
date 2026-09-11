import SwiftUI

struct HomeOverviewScreenView: View {
    let state: HomeOverviewState
    var retryAction: (() -> Void)?
    var refreshAction: (() async -> Void)?

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var notificationStore: CandidateNotificationStore
    @Environment(\.appConfiguration) private var appConfiguration

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    header
                    content
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.top, topContentPadding)
                .padding(.bottom, KairoSpacing.xxLarge)
            }
            .refreshableIfAvailable(action: refreshAction)
        }
        .background(
            RadialGradient(
                colors: [KairoColors.accent.opacity(0.09), KairoColors.background],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 430
            )
            .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.homeScreen)
        .task {
            await notificationStore.refreshUnreadCount()
        }
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
                    Image("KairoWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, alignment: .leading)
                        .accessibilityLabel("Kairo")

                    Text("Build trust with every verified record.")
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                }

                Spacer(minLength: KairoSpacing.medium)

                HStack(spacing: KairoSpacing.small) {
                    Button(action: { router.showNotificationCenter() }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 42, height: 42)
                                .foregroundStyle(KairoColors.textPrimary)
                                .background(KairoColors.surface, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(KairoColors.border, lineWidth: 1)
                                )

                            if let badge = notificationStore.unreadBadgeText {
                                Text(badge)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .padding(.horizontal, badge.count > 1 ? 2 : 0)
                                    .background(KairoColors.danger, in: Capsule())
                                    .offset(x: 3, y: -3)
                                    .accessibilityIdentifier(KairoAccessibilityID.notificationsUnreadBadge)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(KairoAccessibilityID.homeNotificationsButton)
                    .accessibilityLabel(notificationBellAccessibilityLabel)
                    .accessibilityHint("Opens Notifications.")

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

        }
    }

    private var notificationBellAccessibilityLabel: String {
        guard let count = notificationStore.unreadCount, count > 0 else {
            return "Notifications"
        }
        return "Notifications, \(count) unread"
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
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                    Text("TRUST SCORE")
                        .font(.system(.caption2, design: .default).weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.68))
                        .accessibilityLabel("Trust Score")

                    Text(dataSourceLabel)
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.accent)
                }

                Spacer(minLength: KairoSpacing.medium)

                Button("View Passport") {
                    router.selectTab(.passport)
                }
                .font(KairoTypography.caption)
                .foregroundStyle(Color(hex: 0x07122B))
                .padding(.horizontal, KairoSpacing.small)
                .padding(.vertical, KairoSpacing.xSmall)
                .background(.white, in: Capsule())
                .accessibilityIdentifier(KairoAccessibilityID.homeViewTrustPassport)
            }

            HStack(alignment: .lastTextBaseline, spacing: KairoSpacing.xSmall) {
                Text(trustScore.score.map(String.init) ?? "Unavailable")
                    .font(.system(size: trustScore.score == nil ? 28 : 48, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)

                if trustScore.score != nil {
                    Text("/ 100")
                        .font(KairoTypography.body)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            Text(trustScore.status)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.accent)
                .fixedSize(horizontal: false, vertical: true)

            Text(trustScore.supportingCopy)
                .font(KairoTypography.footnote)
                .foregroundStyle(.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            if let progress = trustScore.progress {
                ProgressView(value: progress)
                    .tint(KairoColors.accent)
                    .progressViewStyle(.linear)
            }

            Button("View score details") {
                router.showTrustScoreDetails()
            }
            .buttonStyle(.plain)
            .font(KairoTypography.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .accessibilityIdentifier(KairoAccessibilityID.homeTrustScoreDetails)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x07122B), Color(hex: 0x12355A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(KairoColors.accent.opacity(0.14))
                .frame(width: 160, height: 160)
                .blur(radius: 34)
                .offset(x: 44, y: -58)
                .allowsHitTesting(false)
        }
        .kairoShadow(KairoShadow.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.homeTrustScoreCard)
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
                        action: {
                            if let identifier = request.authoritativeDestinationID {
                                refreshStore.focusVerificationRequest(identifier: identifier)
                            }
                            router.selectTab(request.destinationTab)
                        }
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
        Button(action: { router.showPassportActivity() }) {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                HomeSectionHeader(
                    title: "Recent Passport views",
                    subtitle: "Open Views & Share Activity",
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
        .buttonStyle(.plain)
        .accessibilityIdentifier(KairoAccessibilityID.homeRecentPassportViewsOpen)
        .accessibilityHint("Opens the authoritative Passport view and share history")
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
