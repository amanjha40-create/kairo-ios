import Combine
import Foundation
import SwiftUI

nonisolated enum AnalyticsConsentDecision: String, Codable, Sendable {
    case allowed
    case denied
}

/// Versioned, account-scoped consent storage. The first-install choice is
/// transferred to the first account only; later accounts on a shared device
/// must make their own choice.
final class AnalyticsConsentPreferences: @unchecked Sendable {
    nonisolated static let currentVersion = 1

    private let defaults: UserDefaults
    private let namespace: String
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard, namespace: String = "kairoid.analytics.consent") {
        self.defaults = defaults
        self.namespace = namespace
    }

    func installationPromptCompleted() -> Bool {
        lock.withLock { defaults.bool(forKey: installationPromptCompletedKey) }
    }

    func installationDecision() -> AnalyticsConsentDecision? {
        lock.withLock { decision(forKey: installationDecisionKey) }
    }

    func setInstallationDecision(_ decision: AnalyticsConsentDecision) {
        lock.withLock {
            defaults.set(true, forKey: installationPromptCompletedKey)
            defaults.set(decision.rawValue, forKey: installationDecisionKey)
        }
    }

    func consumeInstallationDecision(for accountID: String) -> AnalyticsConsentDecision? {
        lock.withLock {
            guard let value = decision(forKey: installationDecisionKey) else { return nil }
            defaults.set(value.rawValue, forKey: accountKey(accountID))
            defaults.removeObject(forKey: installationDecisionKey)
            return value
        }
    }

    func decision(for accountID: String) -> AnalyticsConsentDecision? {
        lock.withLock { decision(forKey: accountKey(accountID)) }
    }

    func setDecision(_ decision: AnalyticsConsentDecision, for accountID: String) {
        lock.withLock { defaults.set(decision.rawValue, forKey: accountKey(accountID)) }
    }

    func removeDecision(for accountID: String) {
        lock.withLock { defaults.removeObject(forKey: accountKey(accountID)) }
    }

    private var versionPrefix: String { "\(namespace).v\(Self.currentVersion)" }
    private var installationPromptCompletedKey: String { "\(versionPrefix).installationPromptCompleted" }
    private var installationDecisionKey: String { "\(versionPrefix).installationDecision" }
    private func accountKey(_ accountID: String) -> String { "\(versionPrefix).account.\(accountID)" }

    private func decision(forKey key: String) -> AnalyticsConsentDecision? {
        guard let rawValue = defaults.string(forKey: key) else { return nil }
        return AnalyticsConsentDecision(rawValue: rawValue)
    }
}

@MainActor
final class AnalyticsConsentController: ObservableObject {
    @Published private(set) var currentAccountID: String?
    @Published private(set) var decision: AnalyticsConsentDecision?

    private let preferences: AnalyticsConsentPreferences
    private let analytics: KairoAnalytics
    private let presentationEnabled: Bool
    private var synchronizationTask: Task<Void, Never>?

    init(
        preferences: AnalyticsConsentPreferences,
        analytics: KairoAnalytics = .shared,
        presentationEnabled: Bool = true
    ) {
        self.preferences = preferences
        self.analytics = analytics
        self.presentationEnabled = presentationEnabled
    }

    var shouldPresentPrompt: Bool {
        guard presentationEnabled else { return false }
        if currentAccountID != nil { return decision == nil }
        return !preferences.installationPromptCompleted()
    }

    var isUsageAnalyticsEnabled: Bool { decision == .allowed }

    func updateAccount(_ accountID: String?) {
        currentAccountID = accountID

        if let accountID {
            var storedDecision = preferences.decision(for: accountID)
            if storedDecision == nil {
                storedDecision = preferences.consumeInstallationDecision(for: accountID)
            }
            decision = storedDecision
        } else {
            decision = nil
        }

        synchronizeAnalytics()
    }

    func choose(_ newDecision: AnalyticsConsentDecision) {
        if let currentAccountID {
            preferences.setDecision(newDecision, for: currentAccountID)
        } else {
            preferences.setInstallationDecision(newDecision)
        }
        decision = newDecision
        synchronizeAnalytics()
    }

    func setUsageAnalyticsEnabled(_ enabled: Bool) {
        choose(enabled ? .allowed : .denied)
    }

    func removeCurrentAccountDecision() {
        if let currentAccountID {
            preferences.removeDecision(for: currentAccountID)
        }
        decision = nil
        synchronizeAnalytics()
    }

    private func synchronizeAnalytics() {
        let accountID = currentAccountID
        let decision = decision
        synchronizationTask?.cancel()
        synchronizationTask = Task { [analytics] in
            guard !Task.isCancelled else { return }
            await analytics.apply(accountID: accountID, decision: decision)
        }
    }
}

struct AnalyticsConsentPromptView: View {
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(KairoColors.brandPrimary)
                        .accessibilityHidden(true)

                    Text("Help improve KairoID")
                        .font(KairoTypography.title)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text("With your permission, KairoID uses Firebase Analytics to measure app opens and a small allowlist of product actions so we can understand and improve the experience.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)

                    Text("When you are signed in, these measurements are linked to your internal KairoID account ID. We do not include your name, email, phone number, document details, or advertising identifier, and we do not use this data to track you across other companies' apps or websites.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)

                    Text("Analytics is optional. Your choice does not affect any feature, and you can change it later in Settings → Privacy → Share usage analytics.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textPrimary)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: KairoSpacing.medium) { consentButtons }
                        VStack(spacing: KairoSpacing.medium) { consentButtons }
                    }
                }
                .padding(KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Usage analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .accessibilityIdentifier(KairoAccessibilityID.analyticsConsentPrompt)
    }

    @ViewBuilder
    private var consentButtons: some View {
        consentButton(title: "Not now", identifier: KairoAccessibilityID.analyticsConsentDeny, action: onDeny)
        consentButton(title: "Allow Analytics", identifier: KairoAccessibilityID.analyticsConsentAllow, action: onAllow)
    }

    private func consentButton(title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KairoTypography.action)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(KairoColors.brandPrimary)
        .background(KairoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                .stroke(KairoColors.brandPrimary, lineWidth: 1.5)
        }
        .accessibilityIdentifier(identifier)
    }
}
