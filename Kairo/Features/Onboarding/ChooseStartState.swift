import Foundation

enum ChooseStartOption: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case importResume
    case buildProfileManually

    var id: String { rawValue }

    var title: String {
        switch self {
        case .importResume:
            "Import your resume"
        case .buildProfileManually:
            "Fill a quick profile"
        }
    }

    var supportingCopy: String {
        switch self {
        case .importResume:
            "Review extracted experience before adding it to Kairo."
        case .buildProfileManually:
            "Answer four questions. Add records later from Career."
        }
    }

    var systemImage: String {
        switch self {
        case .importResume:
            "doc.text"
        case .buildProfileManually:
            "person.text.rectangle"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .importResume:
            KairoAccessibilityID.chooseStartResumeOption
        case .buildProfileManually:
            KairoAccessibilityID.chooseStartManualOption
        }
    }
}

struct ChooseStartState: Equatable, Sendable {
    var selection: ChooseStartOption?

    var canContinue: Bool {
        selection != nil
    }

    mutating func select(_ option: ChooseStartOption) {
        selection = option
    }
}
