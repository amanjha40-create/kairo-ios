import Foundation

nonisolated enum PublicPassportLinkError: Error, Equatable, Sendable {
    case unsupportedScheme
    case unsupportedHost
    case malformedPath
    case invalidToken
}

nonisolated struct PublicPassportDestination: Equatable, Sendable, CustomStringConvertible {
    let url: URL

    var description: String {
        "PublicPassportDestination(url: <redacted>)"
    }
}

nonisolated enum PublicPassportLinkParser {
    private static let tokenLength = 43
    private static let tokenCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    )

    static func parse(
        _ url: URL,
        allowedHosts: Set<String>
    ) -> Result<PublicPassportDestination, PublicPassportLinkError> {
        guard url.scheme?.lowercased() == "https" else {
            return .failure(.unsupportedScheme)
        }

        guard let host = url.host?.lowercased(), allowedHosts.contains(host) else {
            return .failure(.unsupportedHost)
        }

        guard
            url.user == nil,
            url.password == nil,
            url.port == nil,
            url.query == nil,
            url.fragment == nil
        else {
            return .failure(.malformedPath)
        }

        let components = url.path.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count == 2, components[0] == "passport" else {
            return .failure(.malformedPath)
        }

        let token = String(components[1])
        let percentEncodedPath = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.percentEncodedPath ?? ""
        guard
            token.count == tokenLength,
            token.unicodeScalars.allSatisfy(tokenCharacters.contains),
            !percentEncodedPath.contains("%")
        else {
            return .failure(.invalidToken)
        }

        return .success(PublicPassportDestination(url: url))
    }

    static func targetsExpectedHost(_ url: URL, allowedHosts: Set<String>) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return allowedHosts.contains(host)
    }
}

nonisolated struct PublicPassportPresentation: Identifiable, Equatable, Sendable, CustomStringConvertible {
    enum Content: Equatable, Sendable {
        case handoff(PublicPassportDestination)
        case unavailable
    }

    let id: UUID
    let content: Content

    init(id: UUID = UUID(), content: Content) {
        self.id = id
        self.content = content
    }

    var description: String {
        switch content {
        case .handoff:
            "PublicPassportPresentation.handoff(url: <redacted>)"
        case .unavailable:
            "PublicPassportPresentation.unavailable"
        }
    }
}
