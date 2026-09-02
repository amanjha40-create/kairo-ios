import SwiftUI
import UIKit

struct MoreOverviewScreenView: View {
    @Environment(\.appConfiguration) private var appConfiguration
    @Environment(\.moreOverviewService) private var moreOverviewService
    @Environment(\.passportPDFExportService) private var passportPDFExportService
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var candidateDataRefreshStore: CandidateDataRefreshStore

    @Binding private var state: MoreOverviewState
    private let isLiveMode: Bool
    private let retryAction: (() -> Void)?
    private let reloadAction: (() async -> Void)?

    @State private var presentedModal: MorePresentedModal?
    @State private var notificationsErrorMessage: String?
    @State private var actionStatusMessage: String?
    @State private var mutatingNotificationIDs: Set<String> = []
    @State private var isSigningOut = false

    init(
        state: Binding<MoreOverviewState>,
        isLiveMode: Bool,
        retryAction: (() -> Void)? = nil,
        reloadAction: (() async -> Void)? = nil
    ) {
        _state = state
        self.isLiveMode = isLiveMode
        self.retryAction = retryAction
        self.reloadAction = reloadAction
    }

    var body: some View {
        KairoScreenContainer(
            title: "More",
            subtitle: "Manage your account, preferences, and support.",
            titleAccessibilityIdentifier: CandidateTab.more.titleAccessibilityIdentifier
        ) {
            accountSummaryCard
            if let actionStatusMessage {
                successCard(message: actionStatusMessage)
            }
            phaseContent
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.moreScreen)
        .sheet(item: $presentedModal) { modal in
            modalView(for: modal)
        }
    }

    private var destinations: MoreExternalDestinations {
        MoreExternalDestinations(
            supportEmailAddress: appConfiguration.supportEmailAddress,
            helpCenterURL: appConfiguration.helpCenterURL,
            termsOfServiceURL: appConfiguration.termsOfServiceURL,
            privacyPolicyURL: appConfiguration.privacyPolicyURL,
            cookiePolicyURL: appConfiguration.cookiePolicyURL
        )
    }

    private var accountSummaryCard: some View {
        KairoCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: KairoSpacing.medium) {
                    profilePlaceholder
                    accountCopy
                    Spacer(minLength: KairoSpacing.small)
                    MoreStatusBadge(title: state.accountSummary.trustPassportStatus)
                }

                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    HStack(alignment: .center, spacing: KairoSpacing.medium) {
                        profilePlaceholder
                        accountCopy
                    }

                    MoreStatusBadge(title: state.accountSummary.trustPassportStatus)
                }
            }

            Text(state.accountSummary.supportingCopy)
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

            Text(state.accountSummary.initials)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
        }
        .frame(width: 64, height: 64)
        .overlay(
            Circle()
                .stroke(KairoColors.border, lineWidth: 1)
        )
        .accessibilityElement()
        .accessibilityLabel("Profile placeholder for \(state.accountSummary.name)")
    }

    private var accountCopy: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(state.accountSummary.name)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(state.accountSummary.emailAddress)
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
        switch state.phase {
        case .loading:
            KairoLoadingStateView(
                title: "Preparing your account hub",
                message: "Kairo is loading your live account settings."
            )
        case .error(let errorState):
            KairoErrorStateView(
                title: errorState.title,
                message: errorState.message,
                retryAction: retryAction
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
            preferencesSection(content)
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

    private func preferencesSection(_ content: MoreOverviewContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            MoreSectionTitle(
                title: MoreOverviewSection.preferences.title,
                accessibilityIdentifier: KairoAccessibilityID.morePreferencesSection
            )

            KairoCard {
                MorePreferenceGroup(title: "Notifications", systemImage: "bell.badge") {
                    if content.notificationPreferences.isEmpty {
                        KairoEmptyStateView(
                            title: "No notification preferences available",
                            message: "Kairo did not return any candidate notification preferences for this account.",
                            systemImage: "bell.slash"
                        )
                    } else {
                        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                            ForEach(content.notificationPreferences) { preference in
                                Toggle(
                                    isOn: Binding(
                                        get: { preferenceState(for: preference.id)?.isEnabled ?? preference.isEnabled },
                                        set: { handleNotificationToggle(id: preference.id, isEnabled: $0) }
                                    )
                                ) {
                                    MoreToggleLabel(
                                        title: preference.title,
                                        subtitle: preference.subtitle
                                    )
                                }
                                .tint(KairoColors.brandPrimary)
                                .disabled(mutatingNotificationIDs.contains(preference.id))
                                .accessibilityIdentifier(accessibilityIdentifier(for: preference))

                                if preference.id != content.notificationPreferences.last?.id {
                                    Divider()
                                }
                            }

                            if let notificationsErrorMessage {
                                Text(notificationsErrorMessage)
                                    .font(KairoTypography.footnote)
                                    .foregroundStyle(KairoColors.danger)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                Divider()

                MorePreferenceGroup(title: "Appearance", systemImage: "circle.lefthalf.filled") {
                    VStack(alignment: .leading, spacing: KairoSpacing.small) {
                        Text("Appearance remains a local preference on this device.")
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
                    value: state.preferences.language,
                    systemImage: "globe"
                )

                Divider()

                MoreNavigationRow(
                    item: MoreRowItem(
                        id: "accessibility",
                        title: "Accessibility",
                        subtitle: "VoiceOver, Dynamic Type, Dark Mode, and Reduce Motion guidance.",
                        systemImage: "figure.wave"
                    ),
                    action: {
                        presentedModal = .information(
                            MoreInformationSheetModel(
                                title: "Accessibility",
                                subtitle: "Helpful guidance for your device settings.",
                                primaryMessage: "Kairo already respects your iPhone's VoiceOver, Dynamic Type, Dark Mode, and Reduce Motion settings. Larger Text and Reduce Motion can be adjusted in the iOS Settings app."
                            )
                        )
                    }
                )
            }
        }
    }

    private func appearanceButton(_ appearance: MoreAppearanceOption) -> some View {
        let isSelected = state.preferences.appearance == appearance

        return Button {
            state.selectAppearance(appearance)
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
                    subtitle: "Read-only build information from this app bundle.",
                    value: content.appVersion,
                    systemImage: "number"
                )

                if appConfiguration.environment != .production {
                    Divider()

                    MoreStaticRow(
                        title: "Environment",
                        subtitle: "Internal QA build marker.",
                        value: appConfiguration.environment.displayName,
                        systemImage: "circle.hexagongrid"
                    )
                }
            }
        }
    }

    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            KairoCard {
                Text("Sign out")
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)

                Text(
                    isLiveMode
                        ? "Securely sign out of Kairo on this device. Kairo will revoke the stored refresh session when the backend accepts the logout request."
                        : "Return to the local sign-in preview without contacting the backend."
                )
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                Button {
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
                .disabled(isSigningOut)
                .accessibilityIdentifier(KairoAccessibilityID.moreSignOut)
            }
        }
    }

    @ViewBuilder
    private func modalView(for modal: MorePresentedModal) -> some View {
        switch modal {
        case .profile:
            if case .populated(let content) = state.phase {
                MoreProfileSheetView(
                    initialDraft: MoreProfileDraft(user: content.user),
                    user: content.user,
                    onSave: saveProfile
                )
            }
        case .password:
            MoreChangePasswordSheetView(onSubmit: changePassword)
        case .sessions:
            MoreSessionsSheetView()
        case .consent:
            if case .populated(let content) = state.phase {
                MoreConsentManagementSheetView(
                    consent: content.trustScoreConsent,
                    onWithdraw: withdrawConsent
                )
            }
        case .deleteAccount:
            MoreDeleteAccountSheetView(
                onDelete: deleteAccount
            )
        case .information(let model):
            MoreInformationSheetView(model: model)
        case .confirmation(let confirmation):
            MoreConfirmationSheetView(
                confirmation: confirmation,
                onCancel: {
                    presentedModal = nil
                },
                onConfirm: {
                    presentedModal = nil
                    Task {
                        await confirm(confirmation)
                    }
                }
            )
        }
    }

    private func handleAccountRow(_ row: MoreRowItem) {
        switch row.id {
        case "personalInformation":
            presentedModal = .profile
        case "loginSecurity":
            presentedModal = .password
        case "connectedAccounts":
            presentedModal = .information(
                MoreInformationSheetModel(
                    title: "Connected accounts",
                    subtitle: "Connected-account controls",
                    primaryMessage: "Connected accounts are not supported by the candidate backend yet. Kairo does not currently offer social sign-in or account linking from this screen."
                )
            )
        case "sessionsDevices":
            presentedModal = .sessions
        default:
            break
        }
    }

    private func handlePrivacyRow(_ row: MoreRowItem) {
        switch row.id {
        case "privacySettings":
            presentedModal = .information(
                MoreInformationSheetModel(
                    title: "Privacy settings",
                    subtitle: "Privacy controls",
                    primaryMessage: "The candidate backend does not currently expose additional account-level privacy settings beyond trust-score consent. Kairo will add truthful controls here when those routes exist."
                )
            )
        case "manageConsent":
            presentedModal = .consent
        case "downloadMyData":
            presentedModal = .confirmation(.downloadMyData)
        case "deleteAccount":
            if isLiveMode {
                presentedModal = .deleteAccount
            } else {
                presentedModal = .information(
                    MoreInformationSheetModel(
                        title: "Delete account",
                        subtitle: "Demo Mode",
                        primaryMessage: "Demo Mode never deletes a Staging or Production account. Sign in to a live environment to use the real self-service deletion flow."
                    )
                )
            }
        default:
            break
        }
    }

    private func handleSupportRow(_ row: MoreRowItem) {
        switch row.id {
        case "helpCentre":
            if let helpCenterURL = appConfiguration.helpCenterURL {
                openExternal(
                    helpCenterURL,
                    fallback: MoreInformationSheetModel(
                        title: "Help centre unavailable",
                        subtitle: "Help & support",
                        primaryMessage: "Kairo couldn't open the configured Help centre on this device.",
                        supportEmailAddress: appConfiguration.supportEmailAddress
                    )
                )
            } else {
                presentedModal = .information(
                    MoreInformationSheetModel(
                        title: "Help centre unavailable",
                        subtitle: "Help & support",
                        primaryMessage: "A Help centre destination is not configured for this build yet. Contact support directly if you need help.",
                        supportEmailAddress: appConfiguration.supportEmailAddress
                    )
                )
            }
        case "contactSupport":
            openSupportEmail(
                subject: "Kairo Support Request",
                fallbackTitle: "Contact support"
            )
        case "reportProblem":
            openSupportEmail(
                subject: "Kairo Problem Report",
                fallbackTitle: "Report a problem"
            )
        case "giveFeedback":
            openSupportEmail(
                subject: "Kairo Product Feedback",
                fallbackTitle: "Give feedback"
            )
        default:
            break
        }
    }

    private func handleAboutRow(_ row: MoreRowItem) {
        switch row.id {
        case "aboutKairo":
            if case .populated(let content) = state.phase {
                presentedModal = .information(
                    MoreInformationSheetModel(
                        title: "About Kairo",
                        subtitle: "Why portable professional trust matters.",
                        primaryMessage: "Kairo is building portable professional trust so your verified identity, roles, and achievements can move with you.",
                        metadataRows: [
                            MoreMetadataRow(title: "App version", value: content.appVersion),
                            MoreMetadataRow(title: "Backend app version", value: content.backendAppVersion),
                            MoreMetadataRow(title: "API version", value: content.apiVersion),
                            MoreMetadataRow(title: "Trust Score version", value: content.trustScoreVersion)
                        ]
                    )
                )
            }
        case "termsOfService":
            handleLegalDestination(
                appConfiguration.termsOfServiceURL,
                title: "Terms of Service"
            )
        case "privacyPolicy":
            handleLegalDestination(
                appConfiguration.privacyPolicyURL,
                title: "Privacy Policy"
            )
        case "cookiePolicy":
            handleLegalDestination(
                appConfiguration.cookiePolicyURL,
                title: "Cookie Policy"
            )
        case "openSourceLicences":
            presentedModal = .information(
                MoreInformationSheetModel(
                    title: "Open-source licences",
                    subtitle: "Package acknowledgements",
                    primaryMessage: "A browsable open-source licence screen is not bundled yet in this build. Kairo should add that before release."
                )
            )
        default:
            break
        }
    }

    private func handleLegalDestination(_ destinationURL: URL?, title: String) {
        guard let destinationURL else {
            presentedModal = .information(
                MoreInformationSheetModel(
                    title: title,
                    subtitle: "Legal document",
                    primaryMessage: "This build does not yet contain a configured destination for \(title)."
                )
            )
            return
        }

        openExternal(
            destinationURL,
            fallback: MoreInformationSheetModel(
                title: title,
                subtitle: "Legal document",
                primaryMessage: "Kairo couldn't open the configured \(title) destination on this device."
            )
        )
    }

    private func openSupportEmail(subject: String, fallbackTitle: String) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let value = "mailto:\(appConfiguration.supportEmailAddress)?subject=\(encodedSubject)"

        guard let url = URL(string: value) else {
            presentedModal = .information(
                MoreInformationSheetModel(
                    title: fallbackTitle,
                    subtitle: "Support email",
                    primaryMessage: "Kairo couldn't prepare the support email destination.",
                    supportEmailAddress: appConfiguration.supportEmailAddress
                )
            )
            return
        }

        openExternal(
            url,
            fallback: MoreInformationSheetModel(
                title: fallbackTitle,
                subtitle: "Support email",
                primaryMessage: "This device couldn't open a mail draft automatically.",
                supportEmailAddress: appConfiguration.supportEmailAddress
            )
        )
    }

    private func openExternal(
        _ url: URL,
        fallback: MoreInformationSheetModel
    ) {
        openURL(url) { accepted in
            if !accepted {
                presentedModal = .information(fallback)
            }
        }
    }

    private func saveProfile(_ draft: MoreProfileDraft) async throws -> String {
        let overview = try await moreOverviewService.updateProfile(draft)
        await MainActor.run {
            sessionStore.replaceCurrentUser(overview.user)
            state.apply(overview: overview, destinations: destinations)
            actionStatusMessage = "Your profile settings were updated."
        }
        return "Saved"
    }

    private func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> String {
        let message = try await moreOverviewService.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
            confirmPassword: confirmPassword
        )
        await MainActor.run {
            actionStatusMessage = message
        }
        return message
    }

    private func withdrawConsent() async throws -> String {
        let overview = try await moreOverviewService.withdrawTrustScoreConsent()
        await MainActor.run {
            sessionStore.replaceCurrentUser(overview.user)
            state.apply(overview: overview, destinations: destinations)
            actionStatusMessage = "Trust Score consent was updated."
        }
        return "Trust Score consent was updated."
    }

    private func deleteAccount(confirm: String, currentPassword: String?) async throws {
        guard isLiveMode else {
            throw NetworkError.unavailableInDemoMode
        }

        try await moreOverviewService.deleteAccount(
            confirm: confirm,
            currentPassword: currentPassword
        )
        await passportPDFExportService.removeAllArtifacts()
        clearKairoOwnedPassportClipboardIfNeeded()
        candidateDataRefreshStore.resetAfterAccountDeletion()
        await sessionStore.completeAccountDeletion()
    }

    private func clearKairoOwnedPassportClipboardIfNeeded() {
        guard let url = UIPasteboard.general.url,
              let host = url.host?.lowercased(),
              appConfiguration.publicPassportHosts.contains(host),
              url.pathComponents.count == 3,
              url.pathComponents[1] == "passport" else {
            return
        }

        UIPasteboard.general.items = []
    }

    private func handleNotificationToggle(id: String, isEnabled: Bool) {
        notificationsErrorMessage = nil
        let previousPreferences = state.preferences.notifications
        state.setNotification(id: id, isEnabled: isEnabled)

        guard isLiveMode else {
            return
        }

        mutatingNotificationIDs.insert(id)

        Task {
            do {
                let overview = try await moreOverviewService.updateNotificationPreference(
                    id: id,
                    enabled: isEnabled,
                    existingPreferences: previousPreferences
                )
                await MainActor.run {
                    sessionStore.replaceCurrentUser(overview.user)
                    state.apply(overview: overview, destinations: destinations)
                    mutatingNotificationIDs.remove(id)
                    actionStatusMessage = "Notification preferences updated."
                }
            } catch {
                await MainActor.run {
                    state.replaceNotificationPreferences(previousPreferences)
                    mutatingNotificationIDs.remove(id)
                    notificationsErrorMessage = message(for: error)
                }
            }
        }
    }

    private func confirm(_ confirmation: MorePendingConfirmation) async {
        switch confirmation {
        case .downloadMyData:
            await MainActor.run {
                presentedModal = .information(
                    MoreInformationSheetModel(
                        title: "Download my data",
                        subtitle: "Backend gap",
                        primaryMessage: "The candidate backend does not currently support a self-service data export route."
                    )
                )
            }
        case .signOut:
            await MainActor.run {
                isSigningOut = true
            }
            await sessionStore.signOut()
            await MainActor.run {
                isSigningOut = false
            }
        case .withdrawConsent, .revokeSession:
            break
        }
    }

    private func message(for error: Error) -> String {
        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .api(let apiError):
                return apiError.message
            case .transport:
                return "Kairo couldn't reach the network. Check your connection and try again."
            case .invalidResponse:
                return "Kairo received an unexpected response. Please try again."
            case .invalidURL:
                return "Kairo's settings configuration is invalid."
            case .unavailableInDemoMode:
                return "Demo Mode keeps account settings local."
            }
        case let sessionError as SessionServiceError:
            return sessionError.errorDescription ?? "Kairo couldn't complete this account action."
        default:
            return error.localizedDescription
        }
    }

    private func successCard(message: String) -> some View {
        KairoCard {
            Text(message)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.success)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func preferenceState(for id: String) -> MoreNotificationPreferenceItem? {
        state.preferences.notifications.first(where: { $0.id == id })
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

    private func accessibilityIdentifier(for preference: MoreNotificationPreferenceItem) -> String {
        switch preference.eventType.lowercased() {
        case "verification_updates", "verification_update", "verification_status":
            return KairoAccessibilityID.moreNotificationsVerificationUpdates
        case "passport_views", "passport_view", "passport_shares":
            return KairoAccessibilityID.moreNotificationsPassportViews
        case "product_updates", "product_update", "marketing_updates":
            return KairoAccessibilityID.moreNotificationsProductUpdates
        default:
            return "candidate.more.notifications.\(preference.id)"
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
    case profile
    case password
    case sessions
    case consent
    case deleteAccount
    case information(MoreInformationSheetModel)
    case confirmation(MorePendingConfirmation)

    var id: String {
        switch self {
        case .profile:
            "profile"
        case .password:
            "password"
        case .sessions:
            "sessions"
        case .consent:
            "consent"
        case .deleteAccount:
            "deleteAccount"
        case .information(let model):
            "info.\(model.id)"
        case .confirmation(let confirmation):
            "confirmation.\(confirmation.id)"
        }
    }
}

private struct MoreInformationSheetModel: Identifiable {
    let id = UUID().uuidString
    let title: String
    let subtitle: String
    let primaryMessage: String
    var supportEmailAddress: String? = nil
    var metadataRows: [MoreMetadataRow] = []
}

private struct MoreMetadataRow: Identifiable {
    let id = UUID().uuidString
    let title: String
    let value: String
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

private struct MoreProfileSheetView: View {
    let initialDraft: MoreProfileDraft
    let user: AppUser
    let onSave: (MoreProfileDraft) async throws -> String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: ProfileField?

    @State private var draft: MoreProfileDraft
    @State private var isSaving = false
    @State private var serverErrorMessage: String?
    @State private var fieldErrors: [ProfileField: String] = [:]

    init(
        initialDraft: MoreProfileDraft,
        user: AppUser,
        onSave: @escaping (MoreProfileDraft) async throws -> String
    ) {
        self.initialDraft = initialDraft
        self.user = user
        self.onSave = onSave
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoCard {
                        MoreStaticRow(
                            title: "Email",
                            subtitle: verificationMessage(isVerified: user.emailVerifiedAt != nil),
                            value: user.email,
                            systemImage: "envelope"
                        )

                        Divider()

                        MoreStaticRow(
                            title: "Mobile",
                            subtitle: verificationMessage(isVerified: user.phoneVerifiedAt != nil),
                            value: user.phone ?? "Not added",
                            systemImage: "phone"
                        )
                    }

                    KairoCard {
                        VStack(spacing: KairoSpacing.medium) {
                            KairoTextField(
                                title: "Full Name",
                                prompt: "Enter your full name",
                                text: $draft.fullName,
                                errorMessage: fieldErrors[.fullName],
                                textContentType: .name,
                                focus: $focusedField,
                                focusedField: .fullName,
                                onSubmit: { focusedField = .headline }
                            )

                            KairoTextField(
                                title: "Professional Headline",
                                prompt: "Enter a headline",
                                text: $draft.professionalHeadline,
                                errorMessage: fieldErrors[.headline],
                                textInputAutocapitalization: .words,
                                focus: $focusedField,
                                focusedField: .headline,
                                onSubmit: { focusedField = .currentRole }
                            )

                            KairoTextField(
                                title: "Current Role",
                                prompt: "Enter your current role",
                                text: $draft.currentRole,
                                errorMessage: fieldErrors[.currentRole],
                                textInputAutocapitalization: .words,
                                focus: $focusedField,
                                focusedField: .currentRole,
                                onSubmit: { focusedField = .industry }
                            )

                            KairoTextField(
                                title: "Industry",
                                prompt: "Enter your industry",
                                text: $draft.industry,
                                errorMessage: fieldErrors[.industry],
                                textInputAutocapitalization: .words,
                                focus: $focusedField,
                                focusedField: .industry,
                                onSubmit: { focusedField = .yearsOfExperience }
                            )

                            KairoTextField(
                                title: "Years of Experience",
                                prompt: "Enter whole years",
                                text: $draft.yearsOfExperience,
                                errorMessage: fieldErrors[.yearsOfExperience],
                                keyboardType: .numberPad,
                                focus: $focusedField,
                                focusedField: .yearsOfExperience,
                                onSubmit: { focusedField = .currentCity }
                            )

                            KairoTextField(
                                title: "Current City",
                                prompt: "Enter your city",
                                text: $draft.currentCity,
                                errorMessage: fieldErrors[.currentCity],
                                textInputAutocapitalization: .words,
                                focus: $focusedField,
                                focusedField: .currentCity,
                                onSubmit: { focusedField = .currentCountry }
                            )

                            KairoTextField(
                                title: "Current Country",
                                prompt: "Enter your country",
                                text: $draft.currentCountry,
                                errorMessage: fieldErrors[.currentCountry],
                                textInputAutocapitalization: .words,
                                submitLabel: .done,
                                focus: $focusedField,
                                focusedField: .currentCountry,
                                onSubmit: submit
                            )
                        }
                    }

                    if let serverErrorMessage {
                        Text(serverErrorMessage)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: KairoSpacing.medium) {
                        KairoPrimaryButton(
                            title: "Save changes",
                            isLoading: isSaving,
                            action: submit
                        )
                        .disabled(isSaving)

                        KairoSecondaryButton(title: "Cancel") {
                            dismiss()
                        }
                        .disabled(isSaving)
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
            .navigationTitle("Personal information")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func submit() {
        fieldErrors = validate(draft)
        serverErrorMessage = nil

        guard fieldErrors.isEmpty, !isSaving else {
            return
        }

        isSaving = true
        let submissionDraft = draft

        Task {
            do {
                _ = try await onSave(submissionDraft)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    apply(error)
                }
            }
        }
    }

    private func validate(_ draft: MoreProfileDraft) -> [ProfileField: String] {
        var errors: [ProfileField: String] = [:]

        if ManualProfileNormalization.normalized(draft.fullName).isEmpty {
            errors[.fullName] = "Enter your full name."
        }

        let yearsValue = ManualProfileNormalization.normalized(draft.yearsOfExperience)
        if !yearsValue.isEmpty,
           ManualProfileValidation.normalizedYearsOfExperience(yearsValue) == nil {
            errors[.yearsOfExperience] = "Enter valid whole years of experience."
        }

        return errors
    }

    private func apply(_ error: Error) {
        switch error {
        case let networkError as NetworkError:
            if case .api(let apiError) = networkError {
                fieldErrors = [
                    .fullName: apiError.fieldErrors["full_name"]?.first,
                    .headline: apiError.fieldErrors["headline"]?.first,
                    .currentRole: apiError.fieldErrors["current_role"]?.first,
                    .industry: apiError.fieldErrors["industry"]?.first,
                    .yearsOfExperience: apiError.fieldErrors["years_of_experience"]?.first,
                    .currentCity: apiError.fieldErrors["location_city"]?.first,
                    .currentCountry: apiError.fieldErrors["location_country"]?.first
                ].compactMapValues { $0 }
                serverErrorMessage = apiError.message
                return
            }
            serverErrorMessage = error.localizedDescription
        default:
            serverErrorMessage = error.localizedDescription
        }
    }

    private func verificationMessage(isVerified: Bool) -> String {
        isVerified ? "Verified on your account" : "Not verified on your account"
    }

    private enum ProfileField: Hashable {
        case fullName
        case headline
        case currentRole
        case industry
        case yearsOfExperience
        case currentCity
        case currentCountry
    }
}

private struct MoreChangePasswordSheetView: View {
    let onSubmit: (String, String, String) async throws -> String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: PasswordField?

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var fieldErrors: [PasswordField: String] = [:]
    @State private var serverErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoCard {
                        VStack(spacing: KairoSpacing.medium) {
                            KairoTextField(
                                title: "Current Password",
                                prompt: "Enter your current password",
                                text: $currentPassword,
                                errorMessage: fieldErrors[.currentPassword],
                                textContentType: .password,
                                textInputAutocapitalization: .never,
                                isSecure: true,
                                submitLabel: .next,
                                focus: $focusedField,
                                focusedField: .currentPassword,
                                onSubmit: { focusedField = .newPassword }
                            )

                            KairoTextField(
                                title: "New Password",
                                prompt: "Enter a new password",
                                text: $newPassword,
                                errorMessage: fieldErrors[.newPassword],
                                textContentType: .newPassword,
                                textInputAutocapitalization: .never,
                                isSecure: true,
                                submitLabel: .next,
                                focus: $focusedField,
                                focusedField: .newPassword,
                                onSubmit: { focusedField = .confirmPassword }
                            )

                            KairoTextField(
                                title: "Confirm Password",
                                prompt: "Re-enter your new password",
                                text: $confirmPassword,
                                errorMessage: fieldErrors[.confirmPassword],
                                textContentType: .newPassword,
                                textInputAutocapitalization: .never,
                                isSecure: true,
                                submitLabel: .done,
                                focus: $focusedField,
                                focusedField: .confirmPassword,
                                onSubmit: submit
                            )
                        }
                    }

                    if let serverErrorMessage {
                        Text(serverErrorMessage)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: KairoSpacing.medium) {
                        KairoPrimaryButton(
                            title: "Change password",
                            isLoading: isSubmitting,
                            action: submit
                        )
                        .disabled(isSubmitting)

                        KairoSecondaryButton(title: "Cancel") {
                            dismiss()
                        }
                        .disabled(isSubmitting)
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
            .navigationTitle("Login & security")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func submit() {
        fieldErrors = validate()
        serverErrorMessage = nil

        guard fieldErrors.isEmpty, !isSubmitting else {
            return
        }

        isSubmitting = true
        let currentPassword = currentPassword
        let newPassword = newPassword
        let confirmPassword = confirmPassword

        Task {
            do {
                _ = try await onSubmit(currentPassword, newPassword, confirmPassword)
                await MainActor.run {
                    isSubmitting = false
                    self.currentPassword = ""
                    self.newPassword = ""
                    self.confirmPassword = ""
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    apply(error)
                }
            }
        }
    }

    private func validate() -> [PasswordField: String] {
        var errors: [PasswordField: String] = [:]

        if currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors[.currentPassword] = "Enter your current password."
        }

        if newPassword.count < 12 {
            errors[.newPassword] = "Use at least 12 characters."
        }

        if confirmPassword != newPassword {
            errors[.confirmPassword] = "Passwords do not match."
        }

        return errors
    }

    private func apply(_ error: Error) {
        switch error {
        case let networkError as NetworkError:
            if case .api(let apiError) = networkError {
                fieldErrors = [
                    .currentPassword: apiError.fieldErrors["current_password"]?.first,
                    .newPassword: apiError.fieldErrors["new_password"]?.first,
                    .confirmPassword: apiError.fieldErrors["confirm_password"]?.first
                ].compactMapValues { $0 }
                serverErrorMessage = apiError.message
                return
            }
            serverErrorMessage = error.localizedDescription
        default:
            serverErrorMessage = error.localizedDescription
        }
    }

    private enum PasswordField: Hashable {
        case currentPassword
        case newPassword
        case confirmPassword
    }
}

private struct MoreSessionsSheetView: View {
    @Environment(\.moreOverviewService) private var moreOverviewService
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [MoreSessionRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var revokingIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    if isLoading {
                        KairoLoadingStateView(
                            title: "Loading sessions",
                            message: "Kairo is preparing your active account sessions."
                        )
                    } else if let errorMessage {
                        KairoErrorStateView(
                            title: "Sessions unavailable",
                            message: errorMessage,
                            retryAction: load
                        )
                    } else if sessions.isEmpty {
                        KairoEmptyStateView(
                            title: "No sessions returned",
                            message: "Kairo did not return any active sessions for this account.",
                            systemImage: "desktopcomputer.trianglebadge.exclamationmark"
                        )
                    } else {
                        KairoCard {
                            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                                ForEach(sessions) { session in
                                    VStack(alignment: .leading, spacing: KairoSpacing.small) {
                                        HStack(alignment: .center, spacing: KairoSpacing.small) {
                                            Text(session.isCurrent ? "Current session" : "Active session")
                                                .font(KairoTypography.headline)
                                                .foregroundStyle(KairoColors.textPrimary)

                                            if session.isCurrent {
                                                MoreStatusBadge(title: "Current")
                                            }
                                        }

                                        Text("Last active \(relativeDate(session.lastActiveAt))")
                                            .font(KairoTypography.body)
                                            .foregroundStyle(KairoColors.textSecondary)

                                        Text("Created \(absoluteDate(session.createdAt)) • Expires \(absoluteDate(session.expiresAt))")
                                            .font(KairoTypography.footnote)
                                            .foregroundStyle(KairoColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if !session.isCurrent {
                                            KairoSecondaryButton(
                                                title: revokingIDs.contains(session.id) ? "Revoking…" : "Revoke session",
                                                action: {
                                                    revoke(session)
                                                }
                                            )
                                            .disabled(revokingIDs.contains(session.id))
                                        }
                                    }

                                    if session.id != sessions.last?.id {
                                        Divider()
                                    }
                                }
                            }
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
            .navigationTitle("Sessions & devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                load()
            }
        }
    }

    private func load() {
        guard !isLoading || (sessions.isEmpty && errorMessage == nil) else {
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loadedSessions = try await moreOverviewService.loadSessions()
                await MainActor.run {
                    isLoading = false
                    sessions = loadedSessions.sorted { lhs, rhs in
                        if lhs.isCurrent != rhs.isCurrent {
                            return lhs.isCurrent && !rhs.isCurrent
                        }
                        return lhs.lastActiveAt > rhs.lastActiveAt
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func revoke(_ session: MoreSessionRecord) {
        revokingIDs.insert(session.id)

        Task {
            do {
                try await moreOverviewService.revokeSession(id: session.id)
                let refreshed = try await moreOverviewService.loadSessions()
                await MainActor.run {
                    revokingIDs.remove(session.id)
                    sessions = refreshed.sorted { lhs, rhs in
                        if lhs.isCurrent != rhs.isCurrent {
                            return lhs.isCurrent && !rhs.isCurrent
                        }
                        return lhs.lastActiveAt > rhs.lastActiveAt
                    }
                }
            } catch {
                await MainActor.run {
                    revokingIDs.remove(session.id)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func absoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func relativeDate(_ date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}

private struct MoreConsentManagementSheetView: View {
    let consent: MoreTrustScoreConsent
    let onWithdraw: () async throws -> String

    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var serverErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoCard {
                        MoreStaticRow(
                            title: "Trust Score consent",
                            subtitle: "Current backend consent status.",
                            value: prettified(consent.status),
                            systemImage: "checkmark.shield"
                        )

                        if let version = consent.version {
                            Divider()
                            MoreStaticRow(
                                title: "Consent version",
                                subtitle: "Version recorded by the backend.",
                                value: version,
                                systemImage: "number"
                            )
                        }

                        if let consentedAt = consent.consentedAt {
                            Divider()
                            MoreStaticRow(
                                title: "Consented at",
                                subtitle: "When Kairo recorded your consent.",
                                value: absoluteDate(consentedAt),
                                systemImage: "calendar"
                            )
                        }
                    }

                    if let serverErrorMessage {
                        Text(serverErrorMessage)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if canWithdraw {
                        KairoPrimaryButton(
                            title: "Withdraw consent",
                            isLoading: isSubmitting,
                            action: withdraw
                        )
                        .disabled(isSubmitting)
                    } else {
                        KairoCard {
                            Text("No additional consent action is available for the current backend state.")
                                .font(KairoTypography.body)
                                .foregroundStyle(KairoColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    KairoSecondaryButton(title: "Done") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
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
            .navigationTitle("Manage consent")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var canWithdraw: Bool {
        let normalized = consent.status.lowercased()
        return normalized == "active" || normalized == "granted" || normalized == "consented"
    }

    private func withdraw() {
        guard !isSubmitting else {
            return
        }

        serverErrorMessage = nil
        isSubmitting = true

        Task {
            do {
                _ = try await onWithdraw()
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    serverErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func absoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func prettified(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }
}

private struct MoreInformationSheetView: View {
    let model: MoreInformationSheetModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoCard {
                        Text(model.primaryMessage)
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let supportEmailAddress = model.supportEmailAddress {
                        KairoCard {
                            Text("Support email")
                                .font(KairoTypography.headline)
                                .foregroundStyle(KairoColors.textPrimary)

                            Text(supportEmailAddress)
                                .font(KairoTypography.title2)
                                .foregroundStyle(KairoColors.brandPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !model.metadataRows.isEmpty {
                        KairoCard {
                            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                                ForEach(Array(model.metadataRows.enumerated()), id: \.element.id) { index, row in
                                    if index > 0 {
                                        Divider()
                                    }

                                    MoreStaticRow(
                                        title: row.title,
                                        subtitle: "Read-only",
                                        value: row.value,
                                        systemImage: "number"
                                    )
                                }
                            }
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
            .navigationTitle(model.title)
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
}

private struct MoreDeleteAccountSheetView: View {
    let onDelete: (_ confirm: String, _ currentPassword: String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var confirmationText = ""
    @State private var currentPassword = ""
    @State private var isSubmitting = false
    @State private var currentPasswordError: String?
    @State private var serverErrorMessage: String?
    @State private var didSucceed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoCard {
                        Label("Permanent account deletion", systemImage: "exclamationmark.triangle.fill")
                            .font(KairoTypography.title2)
                            .foregroundStyle(KairoColors.danger)

                        Text("This permanently deletes your Candidate account and eligible Kairo data. Some completed verification records may be retained only in anonymised form when the backend must preserve shared audit integrity.")
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("This action cannot be undone.")
                            .font(KairoTypography.bodyStrong)
                            .foregroundStyle(KairoColors.danger)
                    }

                    KairoCard {
                        KairoTextField(
                            title: "Type DELETE to confirm",
                            prompt: "DELETE",
                            text: $confirmationText,
                            errorMessage: confirmationError,
                            accessibilityIdentifier: KairoAccessibilityID.moreDeleteAccountConfirmationInput,
                            accessibilityLabel: "Account deletion confirmation",
                            accessibilityHint: "Type DELETE in capital letters to enable permanent account deletion.",
                            textInputAutocapitalization: .characters,
                            submitLabel: .next,
                            focus: $focusedField,
                            focusedField: .confirmation,
                            onSubmit: { focusedField = .password }
                        )

                        KairoTextField(
                            title: "Current password",
                            prompt: "Required for password-based accounts",
                            text: $currentPassword,
                            errorMessage: currentPasswordError,
                            accessibilityIdentifier: KairoAccessibilityID.moreDeleteAccountCurrentPassword,
                            accessibilityLabel: "Current password",
                            accessibilityHint: "Enter your current password. Accounts without a local password may leave this blank.",
                            textContentType: .password,
                            textInputAutocapitalization: .never,
                            isSecure: true,
                            submitLabel: .done,
                            focus: $focusedField,
                            focusedField: .password,
                            onSubmit: submit
                        )

                        Text("Kairo sends this password only to the authenticated deletion endpoint. It is not stored on this device.")
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if didSucceed {
                        Text("Account deleted. Clearing this device session…")
                            .font(KairoTypography.bodyStrong)
                            .foregroundStyle(KairoColors.success)
                            .accessibilityIdentifier(KairoAccessibilityID.moreDeleteAccountSuccess)
                    }

                    if let serverErrorMessage {
                        Text(serverErrorMessage)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(KairoAccessibilityID.moreDeleteAccountError)
                    }

                    VStack(spacing: KairoSpacing.medium) {
                        Button(role: .destructive, action: submit) {
                            HStack(spacing: KairoSpacing.small) {
                                if isSubmitting {
                                    ProgressView()
                                }
                                Text(isSubmitting ? "Deleting account…" : "Permanently Delete Account")
                                    .font(KairoTypography.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KairoSpacing.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(KairoColors.danger)
                        .disabled(!canSubmit)
                        .accessibilityIdentifier(KairoAccessibilityID.moreDeleteAccountFinalButton)
                        .accessibilityLabel("Permanently delete account")
                        .accessibilityHint("Deletes this Candidate account and signs out this device. This cannot be undone.")

                        KairoSecondaryButton(title: "Cancel") {
                            dismiss()
                        }
                        .disabled(isSubmitting)
                    }
                }
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier(KairoAccessibilityID.moreDeleteAccountConfirmation)
        }
    }

    private var confirmationError: String? {
        guard !confirmationText.isEmpty, confirmationText != "DELETE" else {
            return nil
        }
        return "Type DELETE exactly to continue."
    }

    private var canSubmit: Bool {
        confirmationText == "DELETE" && !isSubmitting
    }

    private func submit() {
        guard canSubmit else {
            return
        }

        isSubmitting = true
        currentPasswordError = nil
        serverErrorMessage = nil
        let password = currentPassword.isEmpty ? nil : currentPassword

        Task {
            do {
                try await onDelete("DELETE", password)
                await MainActor.run {
                    isSubmitting = false
                    didSucceed = true
                    currentPassword = ""
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    apply(error)
                }
            }
        }
    }

    private func apply(_ error: Error) {
        let failure = MoreAccountDeletionErrorMapper.map(error)
        currentPasswordError = failure.currentPasswordError
        serverErrorMessage = failure.message
    }

    private enum Field: Hashable {
        case confirmation
        case password
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
                    Text(message)
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
                        Text(confirmTitle)
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier(confirmationAccessibilityIdentifier)
        }
    }

    private var confirmationAccessibilityIdentifier: String {
        switch confirmation {
        case .downloadMyData:
            KairoAccessibilityID.moreDownloadMyDataConfirmation
        case .signOut:
            KairoAccessibilityID.moreSignOutConfirmation
        case .withdrawConsent:
            "candidate.more.withdrawConsent.confirmation"
        case .revokeSession:
            "candidate.more.revokeSession.confirmation"
        }
    }

    private var title: String {
        switch confirmation {
        case .downloadMyData:
            "Download my data"
        case .signOut:
            "Sign Out"
        case .withdrawConsent:
            "Withdraw consent"
        case .revokeSession:
            "Revoke session"
        }
    }

    private var message: String {
        switch confirmation {
        case .downloadMyData:
            "Data export is not supported by the candidate backend yet. Kairo won't generate or send an export file from this build."
        case .signOut:
            "Kairo will clear your local authenticated state on this device and attempt backend logout before returning you to the unauthenticated flow."
        case .withdrawConsent:
            "Kairo will update your Trust Score consent using the backend's current account-settings contract."
        case .revokeSession:
            "Kairo will revoke this account session."
        }
    }

    private var confirmTitle: String {
        switch confirmation {
        case .downloadMyData:
            "Understood"
        case .signOut:
            "Sign Out"
        case .withdrawConsent:
            "Withdraw"
        case .revokeSession:
            "Revoke"
        }
    }
}
