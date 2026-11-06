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

actor KairoAnalytics {
    static let shared = KairoAnalytics()

    private nonisolated static let bootstrap: Void = {
        FirebaseApp.configure()
        Analytics.setConsent([
            .analyticsStorage: .granted,
            .adStorage: .denied,
            .adUserData: .denied,
            .adPersonalization: .denied
        ])
        Analytics.setAnalyticsCollectionEnabled(true)
        Analytics.setUserID(nil)
    }()

    nonisolated static func configure() {
        _ = bootstrap
    }

    nonisolated static func isValidInternalUserID(_ value: String?) -> Bool {
        guard let value, let uuid = UUID(uuidString: value) else { return false }
        return uuid.uuidString.caseInsensitiveCompare(value) == .orderedSame
    }

    func log(_ event: KairoAnalyticsEvent) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event.rawValue, parameters: nil)
    }

    func logOnce(_ event: KairoAnalyticsEvent, occurrenceID: String) {
        guard !occurrenceID.isEmpty else { return }
        let key = "kairoid.analytics.once.\(event.rawValue).\(occurrenceID)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        log(event)
    }

    func setAnonymousUserID(_ userID: String?) {
        guard FirebaseApp.app() != nil else { return }
        guard Self.isValidInternalUserID(userID) else {
            Analytics.setUserID(nil)
            return
        }
        Analytics.setUserID(userID)
    }
}
