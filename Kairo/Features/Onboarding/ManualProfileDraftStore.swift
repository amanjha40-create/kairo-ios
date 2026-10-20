import Foundation

@MainActor
enum ManualProfileDraftStore {
    private static let storageKey = "com.kairoid.Kairo.manualProfileDraft.v1"
    private static var defaults: UserDefaults {
        LocalBatch1QA.isEnabled(configuration: AppConfiguration.resolve()) ? LocalBatch1QA.preferences : .standard
    }

    static func load() -> ManualProfileFlowState? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }

        return try? JSONDecoder().decode(ManualProfileFlowState.self, from: data)
    }

    static func save(_ state: ManualProfileFlowState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    static func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    static var hasSavedDraft: Bool {
        defaults.data(forKey: storageKey) != nil
    }
}
