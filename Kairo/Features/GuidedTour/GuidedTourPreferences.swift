import CryptoKit
import Foundation

nonisolated enum GuidedTourAccountStatus: String, Equatable, Sendable {
    case pending
    case completed
}

@MainActor
protocol GuidedTourPreferenceStoring: AnyObject {
    func status(for accountID: String) -> GuidedTourAccountStatus?
    func markPendingIfEligible(for accountID: String)
    func markCompleted(for accountID: String)
    func clearPendingStates()
    func removeState(for accountID: String)
}

@MainActor
final class GuidedTourPreferences: GuidedTourPreferenceStoring {
    static let keyPrefix = "kairo.guidedTour.v1."

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func status(for accountID: String) -> GuidedTourAccountStatus? {
        guard let key = key(for: accountID),
              let rawValue = defaults.string(forKey: key) else {
            return nil
        }
        return GuidedTourAccountStatus(rawValue: rawValue)
    }

    func markPendingIfEligible(for accountID: String) {
        guard let key = key(for: accountID), status(for: accountID) != .completed else {
            return
        }
        defaults.set(GuidedTourAccountStatus.pending.rawValue, forKey: key)
    }

    func markCompleted(for accountID: String) {
        guard let key = key(for: accountID), status(for: accountID) != .completed else {
            return
        }
        defaults.set(GuidedTourAccountStatus.completed.rawValue, forKey: key)
    }

    func clearPendingStates() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) {
            if defaults.string(forKey: key) == GuidedTourAccountStatus.pending.rawValue {
                defaults.removeObject(forKey: key)
            }
        }
    }

    func removeState(for accountID: String) {
        guard let key = key(for: accountID) else { return }
        defaults.removeObject(forKey: key)
    }

    private func key(for accountID: String) -> String? {
        let normalized = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return Self.keyPrefix + digest.map { String(format: "%02x", $0) }.joined()
    }
}
