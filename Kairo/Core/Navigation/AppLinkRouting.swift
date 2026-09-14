import Foundation

nonisolated enum AppLinkDestination: Equatable, Sendable, CustomStringConvertible {
    case googleHandoff(code: String)
    case passwordReset(token: String)

    var description: String {
        switch self {
        case .googleHandoff:
            "AppLinkDestination.googleHandoff(code: <redacted>)"
        case .passwordReset:
            "AppLinkDestination.passwordReset(token: <redacted>)"
        }
    }
}

nonisolated enum AppLinkParser {
    private static let privateValueLength = 20 ... 512

    static func parse(_ url: URL, configuration: AppConfiguration) -> AppLinkDestination? {
        guard
            url.scheme?.lowercased() == "https",
            url.user == nil,
            url.password == nil,
            url.port == nil,
            url.fragment == nil,
            let host = url.host?.lowercased()
        else {
            return nil
        }

        if configuration.googleHandoffHosts.contains(host), url.path == "/auth/google/complete" {
            return privateQueryValue(named: "code", from: url).map(AppLinkDestination.googleHandoff)
        }

        if configuration.candidateAppLinkHosts.contains(host), url.path == "/reset-password-confirm" {
            return privateQueryValue(named: "token", from: url).map(AppLinkDestination.passwordReset)
        }

        return nil
    }

    private static func privateQueryValue(named name: String, from url: URL) -> String? {
        guard
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            queryItems.count == 1,
            queryItems[0].name == name,
            let value = queryItems[0].value,
            privateValueLength.contains(value.count),
            value.unicodeScalars.allSatisfy({ scalar in
                !CharacterSet.whitespacesAndNewlines.contains(scalar) &&
                !CharacterSet.controlCharacters.contains(scalar)
            })
        else {
            return nil
        }

        return value
    }
}

struct GoogleAuthenticationPresentation: Identifiable, Equatable, CustomStringConvertible {
    let id: UUID
    let handoffCode: String

    init(id: UUID = UUID(), handoffCode: String) {
        self.id = id
        self.handoffCode = handoffCode
    }

    var description: String {
        "GoogleAuthenticationPresentation(handoffCode: <redacted>)"
    }
}
