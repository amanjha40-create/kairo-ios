import Foundation

@MainActor
enum ManualProfileDraftStore {
    private static let storageKey = "com.kairoid.Kairo.manualProfileDraft.v1"

    static func load() -> ManualProfileFlowState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        return try? JSONDecoder().decode(ManualProfileFlowState.self, from: data)
    }

    static func save(_ state: ManualProfileFlowState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static var hasSavedDraft: Bool {
        UserDefaults.standard.data(forKey: storageKey) != nil
    }
}
