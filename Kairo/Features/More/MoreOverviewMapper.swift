import Foundation

enum MoreOverviewMapper {
    nonisolated static func map(
        _ overview: MoreOverview,
        destinations: MoreExternalDestinations
    ) -> MoreOverviewState {
        let notificationPreferences = overview.notificationPreferences.map(notificationPreferenceItem)
        let preferences = MorePreferenceValues(
            notifications: notificationPreferences,
            appearance: .system,
            language: "English"
        )

        return MoreOverviewState(
            accountSummary: accountSummary(from: overview.user),
            preferences: preferences,
            phase: .populated(
                MoreOverviewContent(
                    dataSourceLabel: "Live data",
                    user: overview.user,
                    trustScoreConsent: overview.trustScoreConsent,
                    notificationPreferences: notificationPreferences,
                    accountRows: makeAccountRows(from: overview.user),
                    privacyRows: makePrivacyRows(from: overview.trustScoreConsent),
                    supportRows: makeSupportRows(helpCenterURL: destinations.helpCenterURL),
                    aboutRows: makeAboutRows(destinations: destinations),
                    appVersion: overview.bundleAppVersion,
                    backendAppVersion: overview.backendAppVersion,
                    apiVersion: overview.apiVersion,
                    trustScoreVersion: overview.trustScoreVersion,
                    supportEmailAddress: destinations.supportEmailAddress,
                    helpCenterURL: destinations.helpCenterURL,
                    termsOfServiceURL: destinations.termsOfServiceURL,
                    privacyPolicyURL: destinations.privacyPolicyURL,
                    cookiePolicyURL: destinations.cookiePolicyURL
                )
            )
        )
    }

    nonisolated static func errorState(
        for error: Error,
        accountSummary: MoreAccountSummary
    ) -> MoreOverviewState {
        if case .transport = (error as? NetworkError) {
            return MoreOverviewState(
                accountSummary: accountSummary,
                preferences: .empty,
                phase: .error(
                    MoreOverviewErrorState(
                        title: "You're offline",
                        message: "Kairo couldn't reach your account settings. Check your connection and try again."
                    )
                )
            )
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError):
                return MoreOverviewState(
                    accountSummary: accountSummary,
                    preferences: .empty,
                    phase: .error(
                        MoreOverviewErrorState(
                            title: "Account settings unavailable",
                            message: apiError.message
                        )
                    )
                )
            case .invalidResponse:
                return MoreOverviewState(
                    accountSummary: accountSummary,
                    preferences: .empty,
                    phase: .error(
                        MoreOverviewErrorState(
                            title: "Account settings unavailable",
                            message: "Kairo received an unexpected account-settings response. Please try again."
                        )
                    )
                )
            case .invalidURL:
                return MoreOverviewState(
                    accountSummary: accountSummary,
                    preferences: .empty,
                    phase: .error(
                        MoreOverviewErrorState(
                            title: "Account settings unavailable",
                            message: "Kairo's account-settings configuration is invalid."
                        )
                    )
                )
            case .transport, .unavailableInDemoMode:
                return MoreOverviewState(
                    accountSummary: accountSummary,
                    preferences: .empty,
                    phase: .error(
                        MoreOverviewErrorState(
                            title: "You're offline",
                            message: "Kairo couldn't reach your account settings. Check your connection and try again."
                        )
                    )
                )
            }
        }

        if error is DecodingError {
            return MoreOverviewState(
                accountSummary: accountSummary,
                preferences: .empty,
                phase: .error(
                    MoreOverviewErrorState(
                        title: "Account settings unavailable",
                        message: "Kairo received account data in an unexpected format. Please try again."
                    )
                )
            )
        }

        return MoreOverviewState(
            accountSummary: accountSummary,
            preferences: .empty,
            phase: .error(
                MoreOverviewErrorState(
                    title: "Account settings unavailable",
                    message: error.localizedDescription
                )
            )
        )
    }

    nonisolated static func requiresSessionRecovery(for error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            return true
        }

        return false
    }

    nonisolated static func cachedSummary(from user: AppUser?) -> MoreAccountSummary {
        guard let user else {
            return .fixture
        }

        return accountSummary(from: user)
    }

    nonisolated private static func accountSummary(from user: AppUser) -> MoreAccountSummary {
        MoreAccountSummary(
            initials: initials(from: user),
            name: displayName(from: user),
            emailAddress: user.email,
            trustPassportStatus: user.isActive ? "Active" : "Pending",
            supportingCopy: "Manage the live account and settings that support your Trust Passport."
        )
    }

    nonisolated private static func notificationPreferenceItem(
        from preference: MoreNotificationSetting
    ) -> MoreNotificationPreferenceItem {
        MoreNotificationPreferenceItem(
            id: preference.id,
            eventType: preference.eventType,
            title: notificationTitle(for: preference.eventType),
            subtitle: notificationSubtitle(for: preference.eventType),
            isEnabled: preference.enabled,
            preferredChannels: preference.preferredChannels,
            quietHours: preference.quietHours,
            metadata: preference.metadata
        )
    }

    nonisolated private static func makeAccountRows(from user: AppUser) -> [MoreRowItem] {
        [
            MoreRowItem(
                id: "personalInformation",
                title: "Personal information",
                subtitle: "\(verificationLabel(isVerified: user.emailVerifiedAt != nil, verifiedText: "Email verified", unverifiedText: "Email not verified")) • \(verificationLabel(isVerified: user.phoneVerifiedAt != nil, verifiedText: "Phone verified", unverifiedText: "Phone not verified"))",
                systemImage: "person.text.rectangle"
            ),
            MoreRowItem(
                id: "loginSecurity",
                title: "Login & security",
                subtitle: "Change your password and review account protection.",
                systemImage: "lock.shield"
            ),
            MoreRowItem(
                id: "connectedAccounts",
                title: "Connected accounts",
                subtitle: "Not available in this build.",
                systemImage: "link"
            ),
            MoreRowItem(
                id: "sessionsDevices",
                title: "Sessions & devices",
                subtitle: "Review your active account sessions.",
                systemImage: "desktopcomputer"
            )
        ]
    }

    nonisolated private static func makePrivacyRows(from consent: MoreTrustScoreConsent) -> [MoreRowItem] {
        [
            MoreRowItem(
                id: "privacySettings",
                title: "Privacy settings",
                subtitle: "Additional privacy controls are not configured yet.",
                systemImage: "hand.raised"
            ),
            MoreRowItem(
                id: "manageConsent",
                title: "Manage consent",
                subtitle: "Trust Score consent is currently \(consentStatusDisplay(consent.status)).",
                systemImage: "checkmark.shield"
            ),
            MoreRowItem(
                id: "downloadMyData",
                title: "Download my data",
                subtitle: "Data export is not available yet.",
                systemImage: "arrow.down.doc"
            ),
            MoreRowItem(
                id: "deleteAccount",
                title: "Delete account",
                subtitle: "Account deletion is not supported by the backend yet.",
                systemImage: "trash"
            )
        ]
    }

    nonisolated private static func makeSupportRows(helpCenterURL: URL?) -> [MoreRowItem] {
        [
            MoreRowItem(
                id: "helpCentre",
                title: "Help centre",
                subtitle: helpCenterURL == nil
                    ? "A help-centre link is not configured yet."
                    : "Open Kairo's help resources.",
                systemImage: "book.closed"
            ),
            MoreRowItem(
                id: "contactSupport",
                title: "Contact support",
                subtitle: "Email the Kairo support team.",
                systemImage: "envelope.open"
            ),
            MoreRowItem(
                id: "reportProblem",
                title: "Report a problem",
                subtitle: "Send an issue report by email.",
                systemImage: "exclamationmark.bubble"
            ),
            MoreRowItem(
                id: "giveFeedback",
                title: "Give feedback",
                subtitle: "Share product feedback by email.",
                systemImage: "bubble.left.and.text.bubble.right"
            )
        ]
    }

    nonisolated private static func makeAboutRows(destinations: MoreExternalDestinations) -> [MoreRowItem] {
        [
            MoreRowItem(
                id: "aboutKairo",
                title: "About Kairo",
                subtitle: "Why portable professional trust matters.",
                systemImage: "sparkles"
            ),
            MoreRowItem(
                id: "termsOfService",
                title: "Terms of Service",
                subtitle: legalSubtitle(isConfigured: destinations.termsOfServiceURL != nil),
                systemImage: "doc.text"
            ),
            MoreRowItem(
                id: "privacyPolicy",
                title: "Privacy Policy",
                subtitle: legalSubtitle(isConfigured: destinations.privacyPolicyURL != nil),
                systemImage: "lock.doc"
            ),
            MoreRowItem(
                id: "cookiePolicy",
                title: "Cookie Policy",
                subtitle: legalSubtitle(isConfigured: destinations.cookiePolicyURL != nil),
                systemImage: "circle.hexagongrid"
            ),
            MoreRowItem(
                id: "openSourceLicences",
                title: "Open-source licences",
                subtitle: "Review package acknowledgements used by this app.",
                systemImage: "curlybraces.square"
            )
        ]
    }

    nonisolated private static func displayName(from user: AppUser) -> String {
        let normalizedFullName = ManualProfileNormalization.normalized(user.fullName ?? "")
        return normalizedFullName.isEmpty ? user.email : normalizedFullName
    }

    nonisolated private static func initials(from user: AppUser) -> String {
        let parts = (user.fullName ?? user.email)
            .split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." || $0 == "_" })
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }

        let value = parts.joined()
        return value.isEmpty ? "KA" : value
    }

    nonisolated private static func notificationTitle(for eventType: String) -> String {
        let normalized = eventType.lowercased()

        switch normalized {
        case "verification_updates", "verification_update", "verification_status":
            return "Verification updates"
        case "passport_views", "passport_view", "passport_shares":
            return "Passport views"
        case "product_updates", "product_update", "marketing_updates":
            return "Product updates"
        default:
            return prettifiedLabel(from: eventType)
        }
    }

    nonisolated private static func notificationSubtitle(for eventType: String) -> String {
        let normalized = eventType.lowercased()

        if normalized.contains("verification") {
            return "Stay updated when your verification status changes."
        }

        if normalized.contains("passport") || normalized.contains("share") || normalized.contains("view") {
            return "Hear when organisations interact with your Trust Passport."
        }

        if normalized.contains("product") || normalized.contains("marketing") || normalized.contains("announcement") {
            return "Receive product updates from Kairo."
        }

        return "Control whether Kairo sends this notification."
    }

    nonisolated private static func prettifiedLabel(from value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }

    nonisolated private static func verificationLabel(
        isVerified: Bool,
        verifiedText: String,
        unverifiedText: String
    ) -> String {
        isVerified ? verifiedText : unverifiedText
    }

    nonisolated private static func legalSubtitle(isConfigured: Bool) -> String {
        isConfigured
            ? "Open the latest Kairo document."
            : "This legal destination is not configured yet."
    }

    nonisolated private static func consentStatusDisplay(_ status: String) -> String {
        prettifiedLabel(from: status)
    }
}
