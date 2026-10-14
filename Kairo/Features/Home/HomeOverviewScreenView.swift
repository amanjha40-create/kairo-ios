import SwiftUI

struct HomeOverviewScreenView: View {
    let state: HomeOverviewState
    var retryAction: (() -> Void)?
    var refreshAction: (() async -> Void)?

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var notificationStore: CandidateNotificationStore
    @EnvironmentObject private var digiLockerStore: DigiLockerStore
    @EnvironmentObject private var guidedTourCoordinator: GuidedTourCoordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize = 46.0
    @State private var showsDocuments = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    header
                    content
                    PermanentAddressEntry()
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.top, KairoSpacing.medium)
                .padding(.bottom, KairoSpacing.xxLarge)
                .kairoPageEntrance()
            }
            .onChange(of: guidedTourCoordinator.currentStep) { _, step in
                guard let step, step.target == .trustScore || step.target == .passport else { return }
                let scroll = { proxy.scrollTo(step.target, anchor: .center) }
                if reduceMotion { scroll() }
                else { withAnimation(.easeInOut(duration: 0.25), scroll) }
            }
        }
        .refreshableIfAvailable(action: refreshAction)
        .background(KairoColors.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.homeScreen)
        .task {
            async let notifications: Void = notificationStore.refreshUnreadCount()
            async let digiLocker: Void = digiLockerStore.loadSummaryIfNeeded()
            _ = await (notifications, digiLocker)
        }
        .onAppear { updateGuidedTourReadiness() }
        .onChange(of: state.phase) { _, _ in updateGuidedTourReadiness() }
        .onDisappear { guidedTourCoordinator.setHomeReady(false) }
        .sheet(isPresented: $showsDocuments) { DocumentsHubView() }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .loading:
            KairoLoadingStateView(title: "Preparing your Home overview",
                                  message: "KairoID is assembling your latest trust snapshot.")
        case .error(let error):
            KairoErrorStateView(title: error.title, message: error.message, retryAction: retryAction)
        case .populated(let content):
            dashboard(content, isEmpty: false)
        case .empty(let content):
            dashboard(content, isEmpty: true)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: KairoSpacing.small) {
            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                Text(ProductBrand.name)
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                Text("\(state.header.greeting) \(state.header.firstName)")
                    .font(KairoTypography.screenTitle)
                    .foregroundStyle(KairoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("candidate.home.greeting")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: { router.showNotificationCenter() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(KairoColors.surfaceMuted, in: Circle())
                    if let badge = notificationStore.unreadBadgeText {
                        Text(badge)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(KairoColors.danger, in: Capsule())
                            .accessibilityIdentifier(KairoAccessibilityID.notificationsUnreadBadge)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(KairoAccessibilityID.homeNotificationsButton)
            .accessibilityLabel(notificationBellAccessibilityLabel)
            .accessibilityHint("Opens Notifications.")
        }
    }

    private var adaptiveLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: KairoSpacing.small))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: KairoSpacing.small))
    }

    private var notificationBellAccessibilityLabel: String {
        guard let count = notificationStore.unreadCount, count > 0 else { return "Notifications" }
        return "Notifications, \(count) unread"
    }

    @ViewBuilder
    private func dashboard(_ content: HomeOverviewContent, isEmpty: Bool) -> some View {
        trustScoreCard(content.trustScore, dataSourceLabel: content.dataSourceLabel)
            .id(GuidedTourTarget.trustScore)
            .guidedTourTarget(.trustScore)
        KairoCompactDestinationRow(
            title: "Passport", metadata: "View your Trust Passport",
            systemImage: "person.text.rectangle",
            accessibilityIdentifier: KairoAccessibilityID.homeViewTrustPassport,
            action: { router.selectTab(.passport) }
        )
        .id(GuidedTourTarget.passport)
        .guidedTourTarget(.passport)
        DigiLockerHomeCard()
        verificationRequestsSection(content.verificationRequests, available: content.verificationRequestsAvailable)
        careerSection(content, isEmpty: isEmpty)
        recentActivitySection(content.recentActivity)
        KairoCompactDestinationRow(
            title: "Documents", metadata: "Career attachments and private documents",
            systemImage: "doc.on.doc", accessibilityIdentifier: "candidate.home.documents",
            action: { showsDocuments = true }
        )
        recentPassportViewsSection(content.recentPassportViews)
    }

    private func trustScoreCard(_ trustScore: HomeTrustScore, dataSourceLabel: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            HStack {
                Text("TRUST SCORE")
                    .font(KairoTypography.caption)
                    .accessibilityLabel("Trust Score")
                Spacer()
                Text(dataSourceLabel).font(KairoTypography.caption)
            }
            .foregroundStyle(.white.opacity(0.74))
            adaptiveLayout {
                HStack(alignment: .lastTextBaseline, spacing: KairoSpacing.xSmall) {
                    Text(trustScore.score.map(String.init) ?? "Unavailable")
                        .font(.system(size: trustScore.score == nil ? scoreSize * 0.5 : scoreSize, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    if trustScore.score != nil {
                        Text("/ 100").font(KairoTypography.body).foregroundStyle(.white.opacity(0.74))
                    }
                }
                .foregroundStyle(.white)
                Text(trustScore.status)
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(trustScore.supportingCopy)
                .font(KairoTypography.footnote)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            if let progress = trustScore.progress {
                ProgressView(value: progress).tint(KairoColors.accent)
            }
            Button("View score details") { router.showTrustScoreDetails() }
                .buttonStyle(.plain)
                .font(KairoTypography.action)
                .foregroundStyle(.white)
                .frame(minHeight: 44)
                .accessibilityIdentifier(KairoAccessibilityID.homeTrustScoreDetails)
        }
        .modifier(KairoTrustSurface())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.homeTrustScoreCard)
    }

    private func updateGuidedTourReadiness() {
        switch state.phase {
        case .populated, .empty:
            guidedTourCoordinator.setHomeReady(true)
        case .loading, .error:
            guidedTourCoordinator.setHomeReady(false)
        }
    }

    @ViewBuilder
    private func verificationRequestsSection(_ requests: [HomeVerificationRequest], available: Bool) -> some View {
        if !available {
            KairoSection(compact: true) {
                KairoSectionHeading(title: "Verification status unavailable")
                Text("Pull to refresh to check your current verification requests.")
                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
            }
        } else if requests.isEmpty {
            KairoSection(compact: true) {
                Label("No active verification requests", systemImage: "tray")
                    .font(KairoTypography.recordTitle).foregroundStyle(KairoColors.textSecondary)
            }
            .accessibilityIdentifier(KairoAccessibilityID.homeVerificationRequest)
        } else {
            requestGroup(requests.filter(\.needsAttention), title: "Needs your attention")
            requestGroup(requests.filter { !$0.needsAttention }, title: "In progress")
        }
    }

    @ViewBuilder
    private func requestGroup(_ requests: [HomeVerificationRequest], title: String) -> some View {
        if !requests.isEmpty {
            KairoSection(compact: true) {
                KairoSectionHeading(title: title)
                ForEach(Array(requests.prefix(3))) { request in
                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                        KairoCompactDestinationRow(
                            title: request.title,
                            metadata: "\(request.organization) · \(request.status)",
                            systemImage: request.needsAttention ? "exclamationmark.circle" : "clock",
                            accessibilityIdentifier: KairoAccessibilityID.homeVerificationRequestAction,
                            action: {
                                if let identifier = request.authoritativeDestinationID {
                                    refreshStore.focusVerificationRequest(identifier: identifier)
                                }
                                router.selectTab(request.destinationTab)
                            }
                        )
                        .accessibilityHint("View request")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(KairoAccessibilityID.homeVerificationRequest)
                }
                if requests.count > 3 {
                    Button("View all \(requests.count) requests") { router.selectTab(.verify) }
                        .buttonStyle(KairoActionStyle())
                }
            }
        }
    }

    private func careerSection(_ content: HomeOverviewContent, isEmpty: Bool) -> some View {
        KairoSection(compact: true) {
            KairoSectionHeading(title: "Build Your Trust")
                .accessibilityIdentifier("candidate.home.career")
            if isEmpty {
                Text("Your Home is ready to grow")
                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
            }
            if let summary = content.careerSummary {
                Text(summary)
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
                    .accessibilityIdentifier("candidate.home.career.counts")
            }
            VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                Text("\(content.profileCompletion.percentage)% profile complete")
                    .font(KairoTypography.metadata).foregroundStyle(KairoColors.textSecondary)
                ProgressView(value: content.profileCompletion.progress).tint(KairoColors.accent)
            }
            .accessibilityIdentifier(KairoAccessibilityID.homeProfileCompletion)

            KairoCompactDestinationRow(
                title: content.recommendation.title,
                metadata: content.recommendation.supportingCopy,
                systemImage: "arrow.right.circle",
                accessibilityIdentifier: content.recommendation.destinationTab == .career
                    ? KairoAccessibilityID.homeContinueProfile : KairoAccessibilityID.homeStartVerification,
                action: { router.selectTab(content.recommendation.destinationTab) }
            )
            .accessibilityHint(content.recommendation.actionTitle)

            // Keep distinct useful task metadata, without another button for the same destination.
            ForEach(content.compactTrustTasks) { task in
                adaptiveLayout {
                    Text(task.title).font(KairoTypography.metadata)
                    Text(task.status.title).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            if content.recommendation.destinationTab != .career {
                Button("Continue profile") { router.selectTab(content.profileCompletion.destinationTab) }
                    .buttonStyle(KairoActionStyle())
                    .accessibilityIdentifier(KairoAccessibilityID.homeContinueProfile)
            }
        }
    }

    private func recentActivitySection(_ items: [HomeActivityItem]) -> some View {
        KairoSection(compact: true) {
            KairoSectionHeading(title: "Recent trust changes")
                .accessibilityIdentifier(KairoAccessibilityID.homeRecentActivity)
            if items.isEmpty {
                Text("No recent trust changes")
                    .font(KairoTypography.metadata).foregroundStyle(KairoColors.textSecondary)
            }
            ForEach(items) { item in
                HStack(alignment: .top, spacing: KairoSpacing.small) {
                    Image(systemName: "clock")
                        .foregroundStyle(KairoColors.textSecondary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                        Text(item.title).font(KairoTypography.metadata).foregroundStyle(KairoColors.textPrimary)
                        Text(item.relativeTime).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func recentPassportViewsSection(_ items: [HomePassportViewItem]) -> some View {
        KairoSection(compact: true) {
            KairoSectionHeading(title: "Recent Passport views")
                .accessibilityIdentifier(KairoAccessibilityID.homeRecentPassportViews)
            KairoCompactDestinationRow(
                title: items.first?.title ?? "No recent Passport views yet",
                metadata: items.first?.relativeTime ?? "Open Views & Share Activity",
                systemImage: "eye",
                accessibilityIdentifier: KairoAccessibilityID.homeRecentPassportViewsOpen,
                action: { router.showPassportActivity() }
            )
            .accessibilityHint("Opens the authoritative Passport view and share history")
        }
    }
}

private extension View {
    @ViewBuilder
    func refreshableIfAvailable(action: (() async -> Void)?) -> some View {
        if let action { refreshable { await action() } }
        else { self }
    }
}
