import SwiftUI

struct MoreOverviewScreenView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var currentState: MoreOverviewState
    @State private var presentedModal: MorePresentedModal?

    init(state: MoreOverviewState) {
        _currentState = State(initialValue: state)
    }

    var body: some View {
        KairoScreenContainer(
            title: "More",
            subtitle: "Manage your account, preferences, and support.",
            titleAccessibilityIdentifier: CandidateTab.more.titleAccessibilityIdentifier
        ) {
            accountSummaryCard
            phaseContent
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.moreScreen)
        .sheet(item: $presentedModal) { modal in
            modalView(for: modal)
        }
    }

    private var accountSummaryCard: some View {
        KairoCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: KairoSpacing.medium) {
                    profilePlaceholder
                    accountCopy
                    Spacer(minLength: KairoSpacing.small)
                    MoreStatusBadge(title: currentState.accountSummary.trustPassportStatus)
                }

                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    HStack(alignment: .center, spacing: KairoSpacing.medium) {
                        profilePlaceholder
                        accountCopy
                    }

                    MoreStatusBadge(title: currentState.accountSummary.trustPassportStatus)
                }
            }

            Text(currentState.accountSummary.supportingCopy)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            KairoSecondaryButton(
                title: "View profile",
                accessibilityIdentifier: KairoAccessibilityID.moreViewProfile,
                action: { router.selectTab(.passport) }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.moreAccountSummary)
    }

    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(KairoColors.surfaceMuted)

            Text(currentState.accountSummary.initials)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
        }
        .frame(width: 64, height: 64)
        .overlay(
            Circle()
                .stroke(KairoColors.border, lineWidth: 1)
        )
        .accessibilityElement()
        .accessibilityLabel("Profile photo placeholder for \(currentState.accountSummary.name)")
    }

    private var accountCopy: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(currentState.accountSummary.name)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(currentState.accountSummary.emailAddress)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Trust Passport")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch currentState.phase {
        case .loading:
            KairoLoadingStateView(
                title: "Preparing your account hub",
                message: "Kairo is assembling your local settings, support, and legal preview."
            )
        case .error(let errorState):
            KairoErrorStateView(
                title: errorState.title,
                message: errorState.message
            )
        case .populated(let content):
            populatedContent(content)
        }
    }

    private func populatedContent(_ content: MoreOverviewContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xLarge) {
            buttonSection(
                title: MoreOverviewSection.account.title,
                sectionAccessibilityIdentifier: KairoAccessibilityID.moreAccountSection,
                rows: content.accountRows,
                action: handleAccountRow
            )
            preferencesSection
            buttonSection(
                title: MoreOverviewSection.privacyData.title,
                sectionAccessibilityIdentifier: KairoAccessibilityID.morePrivacyDataSection,
                rows: content.privacyRows,
                action: handlePrivacyRow
            )
            buttonSection(
                title: MoreOverviewSection.helpSupport.title,
                sectionAccessibilityIdentifier: KairoAccessibilityID.moreHelpSupportSection,
                rows: content.supportRows,
                action: handleSupportRow
            )
            aboutSection(content)
            signOutSection
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            MoreSectionTitle(
                title: MoreOverviewSection.preferences.title,
                accessibilityIdentifier: KairoAccessibilityID.morePreferencesSection
            )

            KairoCard {
                MorePreferenceGroup(title: "Notifications", systemImage: "bell.badge") {
                    VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                        Toggle(
                            isOn: Binding(
                                get: { currentState.preferences.notifications.verificationUpdates },
                                set: { currentState.setNotification(.verificationUpdates, isEnabled: $0) }
                            )
                        ) {
                            MoreToggleLabel(
                                title: MoreNotificationPreference.verificationUpdates.title,
                                subtitle: MoreNotificationPreference.verificationUpdates.subtitle
                            )
                        }
                        .tint(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.moreNotificationsVerificationUpdates)

                        Toggle(
                            isOn: Binding(
                                get: { currentState.preferences.notifications.passportViews },
                                set: { currentState.setNotification(.passportViews, isEnabled: $0) }
                            )
                        ) {
                            MoreToggleLabel(
                                title: MoreNotificationPreference.passportViews.title,
                                subtitle: MoreNotificationPreference.passportViews.subtitle
                            )
                        }
                        .tint(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.moreNotificationsPassportViews)

                        Toggle(
                            isOn: Binding(
                                get: { currentState.preferences.notifications.productUpdates },
                                set: { currentState.setNotification(.productUpdates, isEnabled: $0) }
                            )
                        ) {
                            MoreToggleLabel(
                                title: MoreNotificationPreference.productUpdates.title,
                                subtitle: MoreNotificationPreference.productUpdates.subtitle
                            )
                        }
                        .tint(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.moreNotificationsProductUpdates)
                    }
                }

                Divider()

                MorePreferenceGroup(title: "Appearance", systemImage: "circle.lefthalf.filled") {
                    VStack(alignment: .leading, spacing: KairoSpacing.small) {
                        Text("Set a local-only appearance preference for this session.")
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: KairoSpacing.small) {
                                ForEach(MoreAppearanceOption.allCases) { appearance in
                                    appearanceButton(appearance)
                                }
                            }

                            VStack(spacing: KairoSpacing.small) {
                                ForEach(MoreAppearanceOption.allCases) { appearance in
                                    appearanceButton(appearance)
                                }
                            }
                        }
                        .accessibilityIdentifier(KairoAccessibilityID.moreAppearanceSelection)
                    }
                }

                Divider()

                MoreStaticRow(
                    title: "Language",
                    subtitle: "English is the only available language in this milestone.",
                    value: currentState.preferences.language,
                    systemImage: "globe"
                )

                Divider()

                MoreNavigationRow(
                    item: MoreRowItem(
                        id: "accessibility",
                        title: "Accessibility",
                        subtitle: "Reduce Motion, Larger Text, and VoiceOver guidance.",
                        systemImage: "figure.wave"
                    ),
                    action: {
                        presentedModal = .detail(.accessibility)
                    }
                )
            }
        }
    }

    private func appearanceButton(_ appearance: MoreAppearanceOption) -> some View {
        let isSelected = currentState.preferences.appearance == appearance

        return Button {
            currentState.selectAppearance(appearance)
        } label: {
            VStack(alignment: .center, spacing: KairoSpacing.xxSmall) {
                Text(appearance.title)
                    .font(KairoTypography.headline)
                    .multilineTextAlignment(.center)

                Text(appearance.supportingCopy)
                    .font(KairoTypography.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? Color.white : KairoColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.medium)
            .background(
                isSelected ? KairoColors.brandPrimary : KairoColors.surfaceMuted,
                in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    .stroke(isSelected ? KairoColors.brandPrimary : KairoColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier(for: appearance))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func buttonSection(
        title: String,
        sectionAccessibilityIdentifier: String,
        rows: [MoreRowItem],
        action: @escaping (MoreRowItem) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            MoreSectionTitle(
                title: title,
                accessibilityIdentifier: sectionAccessibilityIdentifier
            )

            KairoCard {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider()
                    }

                    MoreNavigationRow(
                        item: row,
                        accessibilityIdentifier: accessibilityIdentifier(for: row),
                        action: { action(row) }
                    )
                }
            }
        }
    }

    private func aboutSection(_ content: MoreOverviewContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            MoreSectionTitle(
                title: MoreOverviewSection.about.title,
                accessibilityIdentifier: KairoAccessibilityID.moreAboutSection
            )

            KairoCard {
                ForEach(Array(content.aboutRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider()
                    }

                    MoreNavigationRow(
                        item: row,
                        accessibilityIdentifier: accessibilityIdentifier(for: row),
                        action: { handleAboutRow(row) }
                    )
                }

                Divider()

                MoreStaticRow(
                    title: "App version",
                    subtitle: "Read-only app build information.",
                    value: content.appVersion,
                    systemImage: "number"
                )
            }
        }
    }

    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            KairoCard {
                Text("Sign out")
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("Return to the local sign-in placeholder without changing any backend session or account data.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    currentState.presentConfirmation(.signOut)
                    presentedModal = .confirmation(.signOut)
                } label: {
                    HStack(spacing: KairoSpacing.small) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Sign Out")
                            .font(KairoTypography.headline)
                        Spacer(minLength: KairoSpacing.small)
                    }
                    .foregroundStyle(KairoColors.danger)
                    .padding(.horizontal, KairoSpacing.medium)
                    .padding(.vertical, KairoSpacing.medium)
                    .background(
                        KairoColors.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                            .stroke(KairoColors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(KairoAccessibilityID.moreSignOut)
            }
        }
    }

    @ViewBuilder
    private func modalView(for modal: MorePresentedModal) -> some View {
        switch modal {
        case .detail(let destination):
            MoreDetailSheetView(destination: destination)
        case .confirmation(let confirmation):
            MoreConfirmationSheetView(
                confirmation: confirmation,
                onCancel: {
                    currentState.dismissConfirmation()
                    presentedModal = nil
                },
                onConfirm: {
                    currentState.confirmPendingAction()
                    presentedModal = nil

                    if currentState.signOutResult == .signedOutLocally {
                        router.showLoginPlaceholder()
                    }
                }
            )
        }
    }

    private func handleAccountRow(_ row: MoreRowItem) {
        switch row.id {
        case "personalInformation":
            presentedModal = .detail(.personalInformation)
        case "loginSecurity":
            presentedModal = .detail(.loginSecurity)
        case "connectedAccounts":
            presentedModal = .detail(.connectedAccounts)
        case "sessionsDevices":
            presentedModal = .detail(.sessionsDevices)
        default:
            break
        }
    }

    private func handlePrivacyRow(_ row: MoreRowItem) {
        switch row.id {
        case "privacySettings":
            presentedModal = .detail(.privacySettings)
        case "manageConsent":
            presentedModal = .detail(.manageConsent)
        case "downloadMyData":
            currentState.presentConfirmation(.downloadMyData)
            presentedModal = .confirmation(.downloadMyData)
        case "deleteAccount":
            currentState.presentConfirmation(.deleteAccount)
            presentedModal = .confirmation(.deleteAccount)
        default:
            break
        }
    }

    private func handleSupportRow(_ row: MoreRowItem) {
        switch row.id {
        case "helpCentre":
            presentedModal = .detail(.helpCentre)
        case "contactSupport":
            presentedModal = .detail(.contactSupport)
        case "reportProblem":
            presentedModal = .detail(.reportProblem)
        case "giveFeedback":
            presentedModal = .detail(.giveFeedback)
        default:
            break
        }
    }

    private func handleAboutRow(_ row: MoreRowItem) {
        switch row.id {
        case "aboutKairo":
            presentedModal = .detail(.aboutKairo)
        case "termsOfService":
            presentedModal = .detail(.termsOfService)
        case "privacyPolicy":
            presentedModal = .detail(.privacyPolicy)
        case "cookiePolicy":
            presentedModal = .detail(.cookiePolicy)
        case "openSourceLicences":
            presentedModal = .detail(.openSourceLicences)
        default:
            break
        }
    }

    private func accessibilityIdentifier(for appearance: MoreAppearanceOption) -> String {
        switch appearance {
        case .system:
            KairoAccessibilityID.moreAppearanceSystem
        case .light:
            KairoAccessibilityID.moreAppearanceLight
        case .dark:
            KairoAccessibilityID.moreAppearanceDark
        }
    }

    private func accessibilityIdentifier(for row: MoreRowItem) -> String? {
        switch row.id {
        case "contactSupport":
            KairoAccessibilityID.moreContactSupport
        case "deleteAccount":
            KairoAccessibilityID.moreDeleteAccount
        case "termsOfService":
            KairoAccessibilityID.moreTermsOfService
        case "privacyPolicy":
            KairoAccessibilityID.morePrivacyPolicy
        case "cookiePolicy":
            KairoAccessibilityID.moreCookiePolicy
        default:
            nil
        }
    }
}

private enum MorePresentedModal: Identifiable {
    case detail(MoreDetailDestination)
    case confirmation(MorePendingConfirmation)

    var id: String {
        switch self {
        case .detail(let destination):
            "detail.\(destination.id)"
        case .confirmation(let confirmation):
            "confirmation.\(confirmation.id)"
        }
    }
}

private enum MoreDetailDestination: String, Identifiable, Equatable {
    case personalInformation
    case loginSecurity
    case connectedAccounts
    case sessionsDevices
    case accessibility
    case privacySettings
    case manageConsent
    case helpCentre
    case contactSupport
    case reportProblem
    case giveFeedback
    case aboutKairo
    case termsOfService
    case privacyPolicy
    case cookiePolicy
    case openSourceLicences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personalInformation:
            "Personal information"
        case .loginSecurity:
            "Login & security"
        case .connectedAccounts:
            "Connected accounts"
        case .sessionsDevices:
            "Sessions & devices"
        case .accessibility:
            "Accessibility"
        case .privacySettings:
            "Privacy settings"
        case .manageConsent:
            "Manage consent"
        case .helpCentre:
            "Help centre"
        case .contactSupport:
            "Contact support"
        case .reportProblem:
            "Report a problem"
        case .giveFeedback:
            "Give feedback"
        case .aboutKairo:
            "About Kairo"
        case .termsOfService:
            "Terms of Service"
        case .privacyPolicy:
            "Privacy Policy"
        case .cookiePolicy:
            "Cookie Policy"
        case .openSourceLicences:
            "Open-source licences"
        }
    }

    var subtitle: String {
        switch self {
        case .personalInformation:
            "Review your account basics."
        case .loginSecurity:
            "Future sign-in protection controls."
        case .connectedAccounts:
            "Future account-linking controls."
        case .sessionsDevices:
            "Future device and session visibility."
        case .accessibility:
            "Helpful guidance for your device settings."
        case .privacySettings:
            "How Kairo will handle professional trust sharing."
        case .manageConsent:
            "Future controls for who can verify or view your history."
        case .helpCentre:
            "Support guidance and common questions."
        case .contactSupport:
            "Reach the Kairo team."
        case .reportProblem:
            "A future structured issue report."
        case .giveFeedback:
            "Share product feedback and ideas."
        case .aboutKairo:
            "Why portable professional trust matters."
        case .termsOfService, .privacyPolicy, .cookiePolicy:
            "Local placeholder legal content."
        case .openSourceLicences:
            "Future licence disclosures."
        }
    }
}

private struct MoreSectionTitle: View {
    let title: String
    let accessibilityIdentifier: String

    var body: some View {
        Text(title)
            .font(KairoTypography.title2)
            .foregroundStyle(KairoColors.textPrimary)
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct MoreStatusBadge: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(KairoTypography.caption)
            .foregroundStyle(KairoColors.success)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xSmall)
            .background(
                KairoColors.success.opacity(0.12),
                in: Capsule()
            )
    }
}

private struct MorePreferenceGroup<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            Label(title, systemImage: systemImage)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)

            content
        }
    }
}

private struct MoreToggleLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(title)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MoreNavigationRow: View {
    let item: MoreRowItem
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KairoColors.brandPrimary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(item.title)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.subtitle)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: KairoSpacing.small)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KairoColors.textSecondary)
                    .padding(.top, KairoSpacing.xxSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? item.id)
    }
}

private struct MoreStaticRow: View {
    let title: String
    let subtitle: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: KairoSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(KairoColors.brandPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                Text(title)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: KairoSpacing.small)

            Text(value)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MoreDetailSheetView: View {
    let destination: MoreDetailDestination

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoCard {
                        Text(primaryMessage)
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let secondaryCardTitle {
                        KairoCard {
                            Text(secondaryCardTitle)
                                .font(KairoTypography.headline)
                                .foregroundStyle(KairoColors.textPrimary)

                            Text(secondaryMessage)
                                .font(KairoTypography.body)
                                .foregroundStyle(KairoColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if destination == .contactSupport {
                        KairoCard {
                            Text("Support inbox")
                                .font(KairoTypography.headline)
                                .foregroundStyle(KairoColors.textPrimary)

                            Text("contact@kairoid.com")
                                .font(KairoTypography.title2)
                                .foregroundStyle(KairoColors.brandPrimary)

                            Text("Support submissions are not connected in this milestone. Use this address as the future support contact point.")
                                .font(KairoTypography.body)
                                .foregroundStyle(KairoColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
            }
            .background(
                LinearGradient(
                    colors: [KairoColors.background, KairoColors.surfaceMuted.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var primaryMessage: String {
        switch destination {
        case .personalInformation:
            "Personal-information editing will arrive in a later milestone. For now, this sheet confirms where your account basics will be managed."
        case .loginSecurity:
            "Password changes, stronger authentication, and account-protection controls are intentionally deferred until backend integration is available."
        case .connectedAccounts:
            "Connected-account management is intentionally deferred. Social sign-in and account linking are not active in this milestone."
        case .sessionsDevices:
            "Session visibility and device management will be connected later. This build does not expose live session or device data."
        case .accessibility:
            "Kairo already respects your iPhone's VoiceOver, Dynamic Type, Dark Mode, and Reduce Motion settings. Larger Text and Reduce Motion can be adjusted in the iOS Settings app."
        case .privacySettings:
            "Privacy settings will become the place where you decide how your Trust Passport is shared with organisations and verifiers."
        case .manageConsent:
            "Consent controls will later let you review and adjust which organisations can access your professional trust information."
        case .helpCentre:
            "The Help centre will grow into a searchable support library for using your Trust Passport with confidence."
        case .contactSupport:
            "Use the support inbox below when the full support workflow is connected in a later milestone."
        case .reportProblem:
            "This local placeholder marks the future problem-reporting flow. No issue submission happens in this build."
        case .giveFeedback:
            "This local placeholder marks the future feedback flow. No feedback submission happens in this build."
        case .aboutKairo:
            "Kairo is building portable professional trust so your verified identity, roles, and achievements can move with you."
        case .termsOfService:
            "Terms of Service content is intentionally local-only in this milestone. Remote legal content is not yet connected."
        case .privacyPolicy:
            "Privacy Policy content is intentionally local-only in this milestone. Remote legal content is not yet connected."
        case .cookiePolicy:
            "Cookie Policy content is intentionally local-only in this milestone. Remote legal content is not yet connected."
        case .openSourceLicences:
            "Open-source licence disclosures will appear here in a later milestone when the app is ready to present them cleanly."
        }
    }

    private var secondaryCardTitle: String? {
        switch destination {
        case .reportProblem:
            "Placeholder form"
        case .giveFeedback:
            "Placeholder form"
        case .accessibility:
            "What Kairo already supports"
        case .aboutKairo:
            "Kairo direction"
        default:
            nil
        }
    }

    private var secondaryMessage: String {
        switch destination {
        case .reportProblem:
            "A future form will collect issue details, screenshots, and context before sending anything to Kairo support."
        case .giveFeedback:
            "A future form will collect product ideas and qualitative feedback without leaving the app."
        case .accessibility:
            "VoiceOver labels, Dynamic Type, Dark Mode, landscape layouts, and Reduce Motion support are already built into the current Kairo candidate experience."
        case .aboutKairo:
            "Trust should not be trapped in a single employer or platform. Kairo is designed so verified professional history becomes reusable, portable, and owned by the candidate."
        default:
            ""
        }
    }
}

private struct MoreConfirmationSheetView: View {
    let confirmation: MorePendingConfirmation
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                KairoCard {
                    Text(confirmation.message)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: KairoSpacing.small) {
                    KairoSecondaryButton(title: "Cancel") {
                        dismiss()
                        onCancel()
                    }

                    Button {
                        dismiss()
                        onConfirm()
                    } label: {
                        Text(confirmation.confirmTitle)
                            .font(KairoTypography.headline)
                            .foregroundStyle(confirmation == .signOut ? KairoColors.danger : KairoColors.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KairoSpacing.medium)
                            .background(
                                KairoColors.surface,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(KairoColors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, KairoSpacing.large)
            .padding(.vertical, KairoSpacing.xLarge)
            .background(
                LinearGradient(
                    colors: [KairoColors.background, KairoColors.surfaceMuted.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(confirmation.title)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier(
                confirmation == .signOut
                    ? KairoAccessibilityID.moreSignOutConfirmation
                    : KairoAccessibilityID.moreDeleteAccountConfirmation
            )
        }
    }
}
