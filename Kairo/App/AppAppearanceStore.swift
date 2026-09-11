import Combine
import SwiftUI

@MainActor
final class AppAppearanceStore: ObservableObject {
    static let preferenceKey = "kairo.appearance.preference"

    @Published private(set) var selection: MoreAppearanceOption

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: Self.preferenceKey)
            .flatMap(MoreAppearanceOption.init(rawValue:)) ?? .system
    }

    var preferredColorScheme: ColorScheme? {
        switch selection {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    func select(_ appearance: MoreAppearanceOption) {
        guard selection != appearance else { return }
        selection = appearance
        defaults.set(appearance.rawValue, forKey: Self.preferenceKey)
    }
}
