import Foundation

nonisolated enum GuidedTourTarget: String, CaseIterable, Hashable, Sendable {
    case trustScore
    case passport
    case career
    case verify
    case more
}

nonisolated enum GuidedTourStep: Int, CaseIterable, Identifiable, Sendable {
    case trustScore
    case passport
    case career
    case verify
    case more

    var id: Int { rawValue }

    var target: GuidedTourTarget {
        switch self {
        case .trustScore: .trustScore
        case .passport: .passport
        case .career: .career
        case .verify: .verify
        case .more: .more
        }
    }

    var title: String {
        switch self {
        case .trustScore: "Your Trust Score"
        case .passport: "Your Trust Passport"
        case .career: "Build your career record"
        case .verify: "Get important records verified"
        case .more: "Everything else is here"
        }
    }

    var body: String {
        switch self {
        case .trustScore:
            "See how strong your verified professional signals are and what needs attention."
        case .passport:
            "Bring your professional information and verification signals together in one trusted view."
        case .career:
            "Add your work, education, skills and supporting evidence here."
        case .verify:
            "Request and track verification of supported professional information."
        case .more:
            "Access your Vault, settings, Help Center and other KairoID tools from More."
        }
    }

    var progressText: String {
        "\(rawValue + 1) of \(Self.allCases.count)"
    }

    var next: GuidedTourStep? {
        Self(rawValue: rawValue + 1)
    }

    var previous: GuidedTourStep? {
        Self(rawValue: rawValue - 1)
    }

    var primaryActionTitle: String {
        next == nil ? "Got it" : "Next"
    }
}
