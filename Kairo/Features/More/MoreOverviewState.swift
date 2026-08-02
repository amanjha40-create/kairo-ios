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
    var pendingConfirmation: MorePendingConfirmation?
    var signOutResult: MoreLocalSignOutResult?

    static func `default`(isDemoMode: Bool) -> MoreOverviewState {
        populatedFixture()
    }

    static func populatedFixture() -> MoreOverviewState {
        MoreOverviewState(
            accountSummary: .fixture,
            preferences: .fixture,
            phase: .populated(.fixture),
            pendingConfirmation: nil,
            signOutResult: nil
        )
    }

    static func loadingFixture() -> MoreOverviewState {
        MoreOverviewState(
            accountSummary: .fixture,
            preferences: .fixture,
            phase: .loading,
            pendingConfirmation: nil,
            signOutResult: nil
        )
    }

    static func errorFixture() -> MoreOverviewState {
        MoreOverviewState(
            accountSummary: .fixture,
            preferences: .fixture,
            phase: .error(
                MoreOverviewErrorState(
                    title: "More unavailable",
                    message: "Kairo could not prepare your account and support preview. Try again when local fixture data is available."
                )
            ),
            pendingConfirmation: nil,
            signOutResult: nil
        )
    }

    mutating func setNotification(_ preference: MoreNotificationPreference, isEnabled: Bool) {
        switch preference {
        case .verificationUpdates:
            preferences.notifications.verificationUpdates = isEnabled
        case .passportViews:
            preferences.notifications.passportViews = isEnabled
        case .productUpdates:
            preferences.notifications.productUpdates = isEnabled
        }
    }

    mutating func selectAppearance(_ appearance: MoreAppearanceOption) {
        preferences.appearance = appearance
    }

    mutating func presentConfirmation(_ confirmation: MorePendingConfirmation) {
        pendingConfirmation = confirmation
    }

    mutating func dismissConfirmation() {
        pendingConfirmation = nil
    }

    mutating func confirmPendingAction() {
        guard let pendingConfirmation else { return }

        self.pendingConfirmation = nil

        switch pendingConfirmation {
        case .downloadMyData, .deleteAccount:
            break
        case .signOut:
            signOutResult = .signedOutLocally
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
    let accountRows: [MoreRowItem]
    let privacyRows: [MoreRowItem]
    let supportRows: [MoreRowItem]
    let aboutRows: [MoreRowItem]
    let appVersion: String
    let supportEmailAddress: String

    let visibleSections: [MoreOverviewSection] = [
        .account,
        .preferences,
        .privacyData,
        .helpSupport,
        .about
    ]

    static let fixture = MoreOverviewContent(
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
                subtitle: "Local placeholder legal copy.",
                systemImage: "doc.text"
            ),
            MoreRowItem(
                id: "privacyPolicy",
                title: "Privacy Policy",
                subtitle: "Local placeholder privacy information.",
                systemImage: "lock.doc"
            ),
            MoreRowItem(
                id: "cookiePolicy",
                title: "Cookie Policy",
                subtitle: "Local placeholder cookie information.",
                systemImage: "circle.hexagongrid"
            ),
            MoreRowItem(
                id: "openSourceLicences",
                title: "Open-source licences",
                subtitle: "Future licence disclosures will appear here.",
                systemImage: "curlybraces.square"
            )
        ],
        appVersion: "1.0.0 (1)",
        supportEmailAddress: "contact@kairoid.com"
    )
}

struct MoreAccountSummary: Equatable, Sendable {
    let initials: String
    let name: String
    let emailAddress: String
    let trustPassportStatus: String
    let supportingCopy: String

    static let fixture = MoreAccountSummary(
        initials: "AM",
        name: "Aarav Mehta",
        emailAddress: "aarav@example.com",
        trustPassportStatus: "Active",
        supportingCopy: "Your Trust Passport is ready to keep growing with every verification you add."
    )
}

struct MorePreferenceValues: Equatable, Sendable {
    var notifications: MoreNotificationSettings
    var appearance: MoreAppearanceOption
    var language: String

    static let fixture = MorePreferenceValues(
        notifications: .fixture,
        appearance: .system,
        language: "English"
    )
}

struct MoreNotificationSettings: Equatable, Sendable {
    var verificationUpdates: Bool
    var passportViews: Bool
    var productUpdates: Bool

    static let fixture = MoreNotificationSettings(
        verificationUpdates: true,
        passportViews: true,
        productUpdates: false
    )
}

enum MoreNotificationPreference: String, CaseIterable, Equatable, Sendable {
    case verificationUpdates
    case passportViews
    case productUpdates

    var title: String {
        switch self {
        case .verificationUpdates:
            "Verification updates"
        case .passportViews:
            "Passport views"
        case .productUpdates:
            "Product updates"
        }
    }

    var subtitle: String {
        switch self {
        case .verificationUpdates:
            "Receive local reminders when your verification status changes."
        case .passportViews:
            "Be notified when organisations view your Trust Passport."
        case .productUpdates:
            "Hear about calm, helpful improvements to Kairo."
        }
    }
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloadMyData:
            "Download my data"
        case .deleteAccount:
            "Delete account"
        case .signOut:
            "Sign Out"
        }
    }

    var message: String {
        switch self {
        case .downloadMyData:
            "Data export is not connected in this milestone. This build will not generate or send a file."
        case .deleteAccount:
            "Account deletion is not available in this milestone. No account or Trust Passport data will be removed from this local build."
        case .signOut:
            "You'll return to the local sign-in placeholder. No backend session or token revocation happens in this milestone."
        }
    }

    var confirmTitle: String {
        switch self {
        case .downloadMyData, .deleteAccount:
            "Understood"
        case .signOut:
            "Sign Out"
        }
    }
}

enum MoreLocalSignOutResult: Equatable, Sendable {
    case signedOutLocally
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
