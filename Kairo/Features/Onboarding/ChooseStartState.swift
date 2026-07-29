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
            "Import your resume and let Kairo organise your professional history.\nYou'll review everything before it becomes part of your Trust Passport."
        case .buildProfileManually:
            "Prefer to start from scratch?\nAdd your experience step by step and build your profile at your own pace."
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

    var placeholderTitle: String {
        switch self {
        case .importResume:
            "Import your resume"
        case .buildProfileManually:
            "Build your profile manually"
        }
    }

    var placeholderSubtitle: String {
        switch self {
        case .importResume:
            "Resume import will connect in a later milestone. This placeholder keeps the approved onboarding branch ready without changing the locked flow."
        case .buildProfileManually:
            "Manual profile creation will connect in a later milestone. This placeholder keeps the approved onboarding branch ready without changing the locked flow."
        }
    }

    var placeholderTitleAccessibilityIdentifier: String {
        switch self {
        case .importResume:
            KairoAccessibilityID.resumeImportPlaceholderTitle
        case .buildProfileManually:
            KairoAccessibilityID.manualProfilePlaceholderTitle
        }
    }

    var placeholderMessage: String {
        switch self {
        case .importResume:
            "Kairo will add secure resume upload, parsing, and review in a later milestone. Your selection is preserved here so the onboarding sequence can remain fully testable."
        case .buildProfileManually:
            "Kairo will add the step-by-step manual profile builder in a later milestone. Your selection is preserved here so the onboarding sequence can remain fully testable."
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
