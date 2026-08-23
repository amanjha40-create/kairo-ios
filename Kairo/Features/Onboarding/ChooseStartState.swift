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
            "Build your profile manually"
        }
    }

    var supportingCopy: String {
        switch self {
        case .importResume:
            "Import your resume and review each claim before it joins your Trust Passport."
        case .buildProfileManually:
            "Add your experience step by step and build your profile at your own pace."
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
