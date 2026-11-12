import FirebaseAnalytics
import FirebaseCore
import Foundation

nonisolated enum KairoAnalyticsEvent: String, CaseIterable, Sendable {
    case signUp = "sign_up"
    case profileCreated = "profile_created"
    case verificationStarted = "verification_started"
    case verificationCompleted = "verification_completed"
    case trustScoreViewed = "trust_score_viewed"
    case shareLinkCreated = "share_link_created"
}

nonisolated protocol KairoAnalyticsTransport: Sendable {
    func prepareForCollection()
    func setConsent(analyticsAllowed: Bool)
    func setCollectionEnabled(_ enabled: Bool)
    func setUserID(_ userID: String?)
    func resetAnalyticsData()
    func log(_ event: KairoAnalyticsEvent)
}

nonisolated struct FirebaseKairoAnalyticsTransport: KairoAnalyticsTransport {
    nonisolated init() {}

    func prepareForCollection() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    func setConsent(analyticsAllowed: Bool) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.setConsent([
            .analyticsStorage: analyticsAllowed ? .granted : .denied,
            .adStorage: .denied,
            .adUserData: .denied,
            .adPersonalization: .denied
        ])
    }

    func setCollectionEnabled(_ enabled: Bool) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    func setUserID(_ userID: String?) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.setUserID(userID)
    }

    func resetAnalyticsData() {
        guard FirebaseApp.app() != nil else { return }
        Analytics.resetAnalyticsData()
    }

    func log(_ event: KairoAnalyticsEvent) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event.rawValue, parameters: nil)
    }
}

actor KairoAnalytics {
    static let shared = KairoAnalytics()

    private let transport: any KairoAnalyticsTransport
    private let occurrenceDefaults: UserDefaults
    private var currentAccountID: String?
    private var analyticsAllowed = false

    init(
        transport: any KairoAnalyticsTransport = FirebaseKairoAnalyticsTransport(),
        occurrenceDefaults: UserDefaults = .standard
    ) {
        self.transport = transport
        self.occurrenceDefaults = occurrenceDefaults
    }

    nonisolated static func configure() {
        // Firebase Analytics is intentionally not initialized here. Startup
        // stays collection-free until an explicit, persisted opt-in is applied.
    }

    nonisolated static func isValidInternalUserID(_ value: String?) -> Bool {
        guard let value, let uuid = UUID(uuidString: value) else { return false }
        return uuid.uuidString.caseInsensitiveCompare(value) == .orderedSame
    }

    func apply(accountID: String?, decision: AnalyticsConsentDecision?) {
        let validAccountID = Self.isValidInternalUserID(accountID) ? accountID : nil
        let accountChanged = currentAccountID != validAccountID

        if decision != .allowed || accountChanged {
            disableAndReset()
        }

        currentAccountID = validAccountID
        guard decision == .allowed else { return }

        transport.prepareForCollection()
        transport.setConsent(analyticsAllowed: true)
        transport.setCollectionEnabled(true)
        transport.setUserID(validAccountID)
        analyticsAllowed = true
    }

    func log(_ event: KairoAnalyticsEvent) {
        guard analyticsAllowed else { return }
        transport.log(event)
    }

    func logOnce(_ event: KairoAnalyticsEvent, occurrenceID: String) {
        guard !occurrenceID.isEmpty else { return }
        let key = "kairoid.analytics.once.\(event.rawValue).\(occurrenceID)"
        guard !occurrenceDefaults.bool(forKey: key) else { return }

        // Mark the occurrence even when consent is absent. This deliberately
        // discards the action instead of retaining an app-managed replay queue.
        occurrenceDefaults.set(true, forKey: key)
        guard analyticsAllowed else { return }
        transport.log(event)
    }

    func stateForTesting() -> (allowed: Bool, accountID: String?) {
        (analyticsAllowed, currentAccountID)
    }

    private func disableAndReset() {
        transport.setCollectionEnabled(false)
        transport.setConsent(analyticsAllowed: false)
        transport.setUserID(nil)
        transport.resetAnalyticsData()
        analyticsAllowed = false
    }
}
