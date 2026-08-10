import Foundation

enum MoreOverviewFixtureKind: String, CaseIterable, Equatable, Sendable {
    case populated
    case loading
    case error
}

struct MoreOverviewState: Equatable, Sendable {
    var accountSummary: MoreAccountSummary
    var preferences: MorePreferenceValues
    var phase: MoreOverviewPhase

    static func `default`(isDemoMode: Bool) -> MoreOverviewState {
        populatedFixture(dataSourceLabel: isDemoMode ? "Demo data" : "Preview data")
    }

    static func populatedFixture(dataSourceLabel: String = "Demo data") -> MoreOverviewState {
        let fixturePreferences = MorePreferenceValues.fixture
        return MoreOverviewState(
            accountSummary: .fixture,
            preferences: fixturePreferences,
            phase: .populated(
                MoreOverviewContent.fixture(
                    dataSourceLabel: dataSourceLabel,
                    preferences: fixturePreferences
                )
            )
        )
    }

    static func loadingFixture() -> MoreOverviewState {
        let fixturePreferences = MorePreferenceValues.fixture
        return MoreOverviewState(
            accountSummary: .fixture,
            preferences: fixturePreferences,
            phase: .loading
        )
    }

    static func errorFixture() -> MoreOverviewState {
        let fixturePreferences = MorePreferenceValues.fixture
        return MoreOverviewState(
            accountSummary: .fixture,
            preferences: fixturePreferences,
            phase: .error(
                MoreOverviewErrorState(
                    title: "More unavailable",
                    message: "Kairo could not prepare your account and settings preview. Try again when local fixture data is available."
                )
            )
        )
    }

    static func loading(accountSummary: MoreAccountSummary) -> MoreOverviewState {
        MoreOverviewState(
            accountSummary: accountSummary,
            preferences: .empty,
            phase: .loading
        )
    }

    mutating func setNotification(id: String, isEnabled: Bool) {
        preferences.setNotification(id: id, isEnabled: isEnabled)

        guard case .populated(var content) = phase else {
            return
        }

        content.notificationPreferences = preferences.notifications
        phase = .populated(content)
    }

    mutating func replaceNotificationPreferences(_ values: [MoreNotificationPreferenceItem]) {
        preferences.notifications = values

        guard case .populated(var content) = phase else {
            return
        }

        content.notificationPreferences = values
        phase = .populated(content)
    }

    mutating func selectAppearance(_ appearance: MoreAppearanceOption) {
        preferences.appearance = appearance
    }

    mutating func apply(overview: MoreOverview, destinations: MoreExternalDestinations) {
        let currentAppearance = preferences.appearance
        let currentLanguage = preferences.language
        let mappedState = MoreOverviewMapper.map(overview, destinations: destinations)
        accountSummary = mappedState.accountSummary
        preferences = mappedState.preferences
        preferences.appearance = currentAppearance
        preferences.language = currentLanguage

        if case .populated(let content) = mappedState.phase {
            phase = .populated(
                MoreOverviewContent(
                    dataSourceLabel: content.dataSourceLabel,
                    user: content.user,
                    trustScoreConsent: content.trustScoreConsent,
                    notificationPreferences: content.notificationPreferences,
                    accountRows: content.accountRows,
                    privacyRows: content.privacyRows,
                    supportRows: content.supportRows,
                    aboutRows: content.aboutRows,
                    appVersion: content.appVersion,
                    backendAppVersion: content.backendAppVersion,
                    apiVersion: content.apiVersion,
                    trustScoreVersion: content.trustScoreVersion,
                    supportEmailAddress: content.supportEmailAddress,
                    helpCenterURL: content.helpCenterURL,
                    termsOfServiceURL: content.termsOfServiceURL,
                    privacyPolicyURL: content.privacyPolicyURL,
                    cookiePolicyURL: content.cookiePolicyURL
                )
            )
        } else {
            phase = mappedState.phase
        }
    }
}

enum MoreOverviewPhase: Equatable, Sendable {
    case loading
    case populated(MoreOverviewContent)
    case error(MoreOverviewErrorState)
}

enum MoreOverviewSection: String, CaseIterable, Equatable, Sendable {
    case account
    case preferences
    case privacyData
    case helpSupport
    case about

    var title: String {
        switch self {
        case .account:
            "Account"
        case .preferences:
            "Preferences"
        case .privacyData:
            "Privacy & data"
        case .helpSupport:
            "Help & support"
        case .about:
            "About Kairo"
        }
    }
}

struct MoreOverviewContent: Equatable, Sendable {
    let dataSourceLabel: String
    let user: AppUser
    let trustScoreConsent: MoreTrustScoreConsent
    var notificationPreferences: [MoreNotificationPreferenceItem]
    let accountRows: [MoreRowItem]
    let privacyRows: [MoreRowItem]
    let supportRows: [MoreRowItem]
    let aboutRows: [MoreRowItem]
    let appVersion: String
    let backendAppVersion: String
    let apiVersion: String
    let trustScoreVersion: String
    let supportEmailAddress: String
    let helpCenterURL: URL?
    let termsOfServiceURL: URL?
    let privacyPolicyURL: URL?
    let cookiePolicyURL: URL?

    let visibleSections: [MoreOverviewSection] = [
        .account,
        .preferences,
        .privacyData,
        .helpSupport,
        .about
    ]

    static func fixture(
        dataSourceLabel: String = "Demo data",
        preferences: MorePreferenceValues = .fixture
    ) -> MoreOverviewContent {
        let user = AppUser(
            id: "user_fixture",
            email: "aarav@example.com",
            fullName: "Aarav Mehta",
            profileSlug: "aarav-mehta",
            phone: "+919876543210",
            currentRole: "Product Operations Manager",
            industry: "Technology",
            yearsOfExperience: 6,
            location: "Bengaluru, India",
            locationCity: "Bengaluru",
            locationRegion: "Karnataka",
            locationCountry: "India",
            headline: "Product Operations Manager",
            bio: nil,
            dateOfBirth: nil,
            avatarURL: nil,
            role: "candidate",
            isActive: true,
            phoneVerifiedAt: ISO8601DateFormatter().date(from: "2026-08-01T10:15:30Z"),
            emailVerifiedAt: ISO8601DateFormatter().date(from: "2026-08-01T10:14:10Z"),
            employmentOnboardingCompletedAt: ISO8601DateFormatter().date(from: "2026-08-01T10:20:00Z"),
            languages: [],
            professionalLinks: [],
            profileCompletionPercentage: 100,
            createdAt: ISO8601DateFormatter().date(from: "2026-07-30T08:00:00Z") ?? .distantPast
        )

        return MoreOverviewContent(
            dataSourceLabel: dataSourceLabel,
            user: user,
            trustScoreConsent: MoreTrustScoreConsent(
                status: "active",
                version: "v1",
                consentedAt: ISO8601DateFormatter().date(from: "2026-08-01T10:20:00Z")
            ),
            notificationPreferences: preferences.notifications,
            accountRows: [
                MoreRowItem(
                    id: "personalInformation",
                    title: "Personal information",
                    subtitle: "Review the basics of your Kairo identity.",
                    systemImage: "person.text.rectangle"
                ),
                MoreRowItem(
                    id: "loginSecurity",
                    title: "Login & security",
                    subtitle: "Password, sign-in, and account protection.",
                    systemImage: "lock.shield"
                ),
                MoreRowItem(
                    id: "connectedAccounts",
                    title: "Connected accounts",
                    subtitle: "Future sign-in and account-linking controls.",
                    systemImage: "link"
                ),
                MoreRowItem(
                    id: "sessionsDevices",
                    title: "Sessions & devices",
                    subtitle: "Review active devices and sessions later.",
                    systemImage: "desktopcomputer"
                )
            ],
            privacyRows: [
                MoreRowItem(
                    id: "privacySettings",
                    title: "Privacy settings",
                    subtitle: "Understand how your Trust Passport is shared.",
                    systemImage: "hand.raised"
                ),
                MoreRowItem(
                    id: "manageConsent",
                    title: "Manage consent",
                    subtitle: "Future controls for employer and verifier access.",
                    systemImage: "checkmark.shield"
                ),
                MoreRowItem(
                    id: "downloadMyData",
                    title: "Download my data",
                    subtitle: "Local export guidance only for this milestone.",
                    systemImage: "arrow.down.doc"
                ),
                MoreRowItem(
                    id: "deleteAccount",
                    title: "Delete account",
                    subtitle: "Understand the future deletion flow before it ships.",
                    systemImage: "trash"
                )
            ],
            supportRows: [
                MoreRowItem(
                    id: "helpCentre",
                    title: "Help centre",
                    subtitle: "Browse future guidance and common questions.",
                    systemImage: "book.closed"
                ),
                MoreRowItem(
                    id: "contactSupport",
                    title: "Contact support",
                    subtitle: "Reach the Kairo team through the support inbox.",
                    systemImage: "envelope.open"
                ),
                MoreRowItem(
                    id: "reportProblem",
                    title: "Report a problem",
                    subtitle: "Share an issue through a future support form.",
                    systemImage: "exclamationmark.bubble"
                ),
                MoreRowItem(
                    id: "giveFeedback",
                    title: "Give feedback",
                    subtitle: "Help shape the next Kairo candidate experience.",
                    systemImage: "bubble.left.and.text.bubble.right"
                )
            ],
            aboutRows: [
                MoreRowItem(
                    id: "aboutKairo",
                    title: "About Kairo",
                    subtitle: "Why portable professional trust matters.",
                    systemImage: "sparkles"
                ),
                MoreRowItem(
                    id: "termsOfService",
                    title: "Terms of Service",
                    subtitle: "Open the current Kairo terms when configured.",
                    systemImage: "doc.text"
                ),
                MoreRowItem(
                    id: "privacyPolicy",
                    title: "Privacy Policy",
                    subtitle: "Open the current Kairo privacy policy when configured.",
                    systemImage: "lock.doc"
                ),
                MoreRowItem(
                    id: "cookiePolicy",
                    title: "Cookie Policy",
                    subtitle: "Open the current Kairo cookie policy when configured.",
                    systemImage: "circle.hexagongrid"
                ),
                MoreRowItem(
                    id: "openSourceLicences",
                    title: "Open-source licences",
                    subtitle: "Review package acknowledgements used by this app.",
                    systemImage: "curlybraces.square"
                )
            ],
            appVersion: "1.0.0 (1)",
            backendAppVersion: "fixture",
            apiVersion: "fixture",
            trustScoreVersion: "fixture",
            supportEmailAddress: "support@kairoid.com",
            helpCenterURL: nil,
            termsOfServiceURL: nil,
            privacyPolicyURL: nil,
            cookiePolicyURL: nil
        )
    }
}

struct MoreAccountSummary: Equatable, Sendable {
    let initials: String
    let name: String
    let emailAddress: String
    let trustPassportStatus: String
    let supportingCopy: String

    nonisolated static let fixture = MoreAccountSummary(
        initials: "AM",
        name: "Aarav Mehta",
        emailAddress: "aarav@example.com",
        trustPassportStatus: "Active",
        supportingCopy: "Your Trust Passport is ready to keep growing with every verification you add."
    )
}

struct MorePreferenceValues: Equatable, Sendable {
    var notifications: [MoreNotificationPreferenceItem]
    var appearance: MoreAppearanceOption
    var language: String

    nonisolated static let fixture = MorePreferenceValues(
        notifications: [
            MoreNotificationPreferenceItem(
                id: "verificationUpdates",
                eventType: "verification_updates",
                title: "Verification updates",
                subtitle: "Receive reminders when your verification status changes.",
                isEnabled: true,
                preferredChannels: [],
                quietHours: [:],
                metadata: [:]
            ),
            MoreNotificationPreferenceItem(
                id: "passportViews",
                eventType: "passport_views",
                title: "Passport views",
                subtitle: "Be notified when organisations view your Trust Passport.",
                isEnabled: true,
                preferredChannels: [],
                quietHours: [:],
                metadata: [:]
            ),
            MoreNotificationPreferenceItem(
                id: "productUpdates",
                eventType: "product_updates",
                title: "Product updates",
                subtitle: "Hear about calm, helpful improvements to Kairo.",
                isEnabled: false,
                preferredChannels: [],
                quietHours: [:],
                metadata: [:]
            )
        ],
        appearance: .system,
        language: "English"
    )

    nonisolated static let empty = MorePreferenceValues(
        notifications: [],
        appearance: .system,
        language: "English"
    )

    mutating func setNotification(id: String, isEnabled: Bool) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else {
            return
        }

        notifications[index].isEnabled = isEnabled
    }
}

struct MoreNotificationPreferenceItem: Equatable, Identifiable, Sendable {
    let id: String
    let eventType: String
    let title: String
    let subtitle: String
    var isEnabled: Bool
    let preferredChannels: [String]
    let quietHours: [String: String]
    let metadata: [String: String]
}

enum MoreAppearanceOption: String, CaseIterable, Equatable, Sendable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var supportingCopy: String {
        switch self {
        case .system:
            "Match your iPhone appearance."
        case .light:
            "Always use the lighter Kairo palette."
        case .dark:
            "Always use the darker Kairo palette."
        }
    }
}

enum MorePendingConfirmation: String, Equatable, Sendable, Identifiable {
    case downloadMyData
    case deleteAccount
    case signOut
    case withdrawConsent
    case revokeSession

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloadMyData:
            "Download my data"
        case .deleteAccount:
            "Delete account"
        case .signOut:
            "Sign Out"
        case .withdrawConsent:
            "Withdraw consent"
        case .revokeSession:
            "Revoke session"
        }
    }
}

struct MoreOverviewErrorState: Equatable, Sendable {
    let title: String
    let message: String
}

struct MoreRowItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
}

struct MoreExternalDestinations: Equatable, Sendable {
    let supportEmailAddress: String
    let helpCenterURL: URL?
    let termsOfServiceURL: URL?
    let privacyPolicyURL: URL?
    let cookiePolicyURL: URL?
}
