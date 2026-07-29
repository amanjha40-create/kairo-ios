import Foundation

enum RootDestination: Equatable {
    case onboarding
    case mainTabs
}

enum OnboardingDestination: Hashable, Identifiable {
    case step(OnboardingStep)
    case loginPlaceholder

    var id: String {
        switch self {
        case .step(let step):
            "step.\(step.rawValue)"
        case .loginPlaceholder:
            "login.placeholder"
        }
    }
}

enum CandidateTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case career
    case verify
    case passport
    case more

    var id: String { rawValue }
}

enum OnboardingStep: String, CaseIterable, Hashable, Identifiable {
    case welcome
    case createAccount
    case verifyIdentity
    case chooseStart
    case resumeImportOrQuickProfile
    case passportCreated

    var id: String { rawValue }

    var next: OnboardingStep? {
        let allSteps = Self.allCases
        guard let index = allSteps.firstIndex(of: self), index < allSteps.index(before: allSteps.endIndex) else {
            return nil
        }

        return allSteps[allSteps.index(after: index)]
    }

    static func path(to step: OnboardingStep) -> [OnboardingStep] {
        guard let index = allCases.firstIndex(of: step) else {
            return [.welcome]
        }

        return Array(allCases[...index])
    }

    static func destinationPath(to step: OnboardingStep) -> [OnboardingDestination] {
        Array(path(to: step).dropFirst()).map(OnboardingDestination.step)
    }
}
