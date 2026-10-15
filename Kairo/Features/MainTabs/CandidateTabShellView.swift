import SwiftUI

struct CandidateTabShellView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var guidedTourCoordinator: GuidedTourCoordinator
    @Environment(\.appConfiguration) private var appConfiguration
    @State private var tabFrames: [GuidedTourTarget: CGRect] = [:]
    @State private var homeVisibleWindowFrame: CGRect = .zero
    @State private var isTourOverlayVisible = false
    @State private var motionEntries: [CandidateTab: Int] = [:]
    @State private var motionIdentityRevision = 0
    private let uiTestHomeConfiguration: UITestHomeConfiguration
    private let uiTestCareerConfiguration: UITestCareerConfiguration
    private let uiTestVerifyConfiguration: UITestVerifyConfiguration
    private let uiTestPassportConfiguration: UITestPassportConfiguration
    private let uiTestMoreConfiguration: UITestMoreConfiguration

    init() {
        uiTestHomeConfiguration = UITestHomeConfiguration.current()
        uiTestCareerConfiguration = UITestCareerConfiguration.current()
        uiTestVerifyConfiguration = UITestVerifyConfiguration.current()
        uiTestPassportConfiguration = UITestPassportConfiguration.current()
        uiTestMoreConfiguration = UITestMoreConfiguration.current()
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(CandidateTab.allCases) { tab in
                destinationView(for: tab)
                    .environment(\.kairoMotionEntry, KairoMotionEntry(
                        generation: motionEntries[tab, default: 0], active: router.selectedTab == tab,
                        identityRevision: motionIdentityRevision))
                    .tabItem {
                        Label {
                            Text(tab.title)
                        } icon: {
                            Image(systemName: tab.systemImage)
                                .symbolVariant(router.selectedTab == tab ? .fill : .none)
                        }
                    }
                    .tag(tab)
            }
        }
        .tint(KairoColors.accent)
        .toolbarBackground(Color(hex: 0x07122B), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .accessibilityIdentifier(KairoAccessibilityID.candidateTabShell)
        .accessibilityHidden(isTourOverlayVisible)
        .allowsHitTesting(!isTourOverlayVisible)
        .background(
            GuidedTourTabFrameReader { frames, homeFrame in
                tabFrames = frames
                homeVisibleWindowFrame = homeFrame
            }
        )
        .overlayPreferenceValue(GuidedTourAnchorPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                let homeFrames = anchors.mapValues { proxy[$0] }
                let localTabFrames = tabFrames.mapValues {
                    GuidedTourTargetResolver.overlayFrame(
                        windowFrame: $0, overlayOrigin: proxy.frame(in: .global).origin
                    )
                }
                let viewport = CGRect(origin: .zero, size: proxy.size)
                let homeVisibleFrame = GuidedTourTargetResolver.overlayFrame(
                    windowFrame: homeVisibleWindowFrame,
                    overlayOrigin: proxy.frame(in: .global).origin
                ).intersection(viewport)
                if let step = guidedTourCoordinator.currentStep,
                   step.target != guidedTourCoordinator.unavailableTargetForTesting,
                   let targetFrame = GuidedTourTargetResolver.frame(
                       for: step.target,
                       homeFrames: homeFrames,
                       tabFrames: localTabFrames
                   ),
                   viewport.width > 24,
                   viewport.height > 24,
                   !homeVisibleFrame.isNull,
                   homeVisibleFrame.height > 24,
                   !targetFrame.isNull,
                   !targetFrame.isInfinite,
                   targetFrame.width > 0,
                   targetFrame.height > 0,
                   targetFrame.intersects(viewport) {
                    GuidedTourOverlayView(
                        step: step,
                        targetFrame: targetFrame,
                        homeVisibleFrame: homeVisibleFrame,
                        targetWindowFrame: targetFrame.offsetBy(
                            dx: proxy.frame(in: .global).minX,
                            dy: proxy.frame(in: .global).minY
                        ),
                        nextAction: guidedTourCoordinator.advance,
                        backAction: guidedTourCoordinator.moveBack,
                        skipAction: guidedTourCoordinator.skip
                    )
                    .zIndex(100)
                    .onAppear { isTourOverlayVisible = true }
                    .onDisappear { isTourOverlayVisible = false }
                }
            }
            // Resolve anchors and draw the overlay in this SAME full-screen space.
            // Expanding only the child overlay rebases every spotlight by safe area.
            .ignoresSafeArea()
        }
        .onAppear(perform: updateGuidedTourContext)
        .onChange(of: router.selectedTab) { old, next in
            if old != next { motionEntries[next, default: 0] += 1 }
            updateGuidedTourContext()
        }
        .onChange(of: sessionStore.currentUser?.id) { _, _ in
            motionEntries = [:]; motionIdentityRevision += 1; updateGuidedTourContext()
        }
        .onChange(of: sessionStore.currentUser?.role) { _, _ in updateGuidedTourContext() }
    }

    private func updateGuidedTourContext() {
        guidedTourCoordinator.updateContext(
            accountID: sessionStore.currentUser?.id,
            role: sessionStore.currentUser?.role,
            isHomeSelected: router.selectedTab == .home
        )
    }

    @ViewBuilder
    private func destinationView(for tab: CandidateTab) -> some View {
        switch tab {
        case .home:
            if let uiTestState = uiTestHomeConfiguration.state {
                HomeOverviewScreenView(state: uiTestState)
            } else if appConfiguration.isDemoModeEnabled {
                HomeOverviewScreenView(state: .default(isDemoMode: true))
            } else {
                HomeOverviewContainerView()
            }
        case .career:
            if appConfiguration.buildConfiguration == .staging,
               appConfiguration.environment == .staging,
               UITestLaunchConfiguration.current().validated(for: appConfiguration).isEnabled,
               ProcessInfo.processInfo.environment["KAIRO_UI_TEST_BATCH2"] == "1" {
                Batch2EvidenceFixtureView()
            } else if uiTestCareerConfiguration.showsAttachedCertificationEditor {
                AttachedCertificationFixtureHostView()
            } else if uiTestCareerConfiguration.showsHierarchyFixture, let state = uiTestCareerConfiguration.state {
                CareerHierarchyFixtureHostView(state: state)
            } else if let uiTestState = uiTestCareerConfiguration.state {
                CareerOverviewScreenView(state: uiTestState)
            } else if appConfiguration.isDemoModeEnabled {
                CareerOverviewScreenView(state: .default(isDemoMode: true))
            } else {
                CareerOverviewContainerView()
            }
        case .verify:
            if uiTestVerifyConfiguration.showsNavigationRecovery {
                VerifyNavigationFixtureHostView()
            } else if uiTestVerifyConfiguration.showsHierarchy, let state = uiTestVerifyConfiguration.state {
                VerifyHierarchyFixtureHostView(state: state)
            } else if let uiTestState = uiTestVerifyConfiguration.state {
                VerifyOverviewFixtureHostView(state: uiTestState)
            } else if appConfiguration.isDemoModeEnabled {
                VerifyOverviewFixtureHostView(state: .default(isDemoMode: true))
            } else {
                VerifyOverviewContainerView()
            }
        case .passport:
            if let uiTestState = uiTestPassportConfiguration.state {
                PassportOverviewScreenView(state: uiTestState)
            } else if appConfiguration.isDemoModeEnabled {
                PassportOverviewScreenView(state: .default(isDemoMode: true))
            } else {
                PassportOverviewContainerView()
            }
        case .more:
            if let uiTestState = uiTestMoreConfiguration.state {
                MoreOverviewFixtureHostView(state: uiTestState)
            } else if appConfiguration.isDemoModeEnabled {
                MoreOverviewFixtureHostView(state: .default(isDemoMode: true))
            } else {
                MoreOverviewContainerView()
            }
        }
    }
}
