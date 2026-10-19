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
    enum DiagnosticReason: String, Sendable, CaseIterable {
        case accepted = "ACCEPTED"
        case nonHTTPSScheme = "NON_HTTPS_SCHEME"
        case userInfoPresent = "USER_INFO_PRESENT"
        case explicitPortPresent = "EXPLICIT_PORT_PRESENT"
        case fragmentPresent = "FRAGMENT_PRESENT"
        case hostMismatch = "HOST_MISMATCH"
        case pathMismatch = "PATH_MISMATCH"
        case queryCountInvalid = "QUERY_COUNT_INVALID"
        case queryNameInvalid = "QUERY_NAME_INVALID"
        case codeMissing = "CODE_MISSING"
        case codeEmpty = "CODE_EMPTY"
        case codeTooShort = "CODE_TOO_SHORT"
        case codeTooLong = "CODE_TOO_LONG"
        case codeWhitespaceOrControl = "CODE_WHITESPACE_OR_CONTROL"
    }

    private static let privateValueLength = 20 ... 512

    static func parse(
        _ url: URL, configuration: AppConfiguration,
        diagnostic: ((DiagnosticReason) -> Void)? = nil
    ) -> AppLinkDestination? {
        // Only Google handoffs ignore fragments; query decoding remains unchanged.
        guard url.scheme?.lowercased() == "https" else { diagnostic?(.nonHTTPSScheme); return nil }
        guard url.user == nil, url.password == nil else { diagnostic?(.userInfoPresent); return nil }
        guard url.port == nil else { diagnostic?(.explicitPortPresent); return nil }
        guard let host = url.host?.lowercased() else { diagnostic?(.hostMismatch); return nil }

        if configuration.googleHandoffHosts.contains(host), url.path == "/auth/google/complete" {
            return privateQueryValue(named: "code", from: url, diagnostic: diagnostic).map(AppLinkDestination.googleHandoff)
        }

        guard url.fragment == nil else { diagnostic?(.fragmentPresent); return nil }
        if configuration.candidateAppLinkHosts.contains(host), url.path == "/reset-password-confirm" {
            return privateQueryValue(named: "token", from: url, diagnostic: diagnostic).map(AppLinkDestination.passwordReset)
        }

        diagnostic?(configuration.googleHandoffHosts.contains(host) || configuration.candidateAppLinkHosts.contains(host)
            ? .pathMismatch : .hostMismatch)
        return nil
    }

    private static func privateQueryValue(
        named name: String, from url: URL, diagnostic: ((DiagnosticReason) -> Void)?
    ) -> String? {
        guard
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            queryItems.count == 1
        else {
            diagnostic?(.queryCountInvalid)
            return nil
        }
        guard queryItems[0].name == name else { diagnostic?(.queryNameInvalid); return nil }
        guard let value = queryItems[0].value else { diagnostic?(.codeMissing); return nil }
        guard !value.isEmpty else { diagnostic?(.codeEmpty); return nil }
        guard value.count >= privateValueLength.lowerBound else { diagnostic?(.codeTooShort); return nil }
        guard value.count <= privateValueLength.upperBound else { diagnostic?(.codeTooLong); return nil }
        guard value.unicodeScalars.allSatisfy({ scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar) &&
            !CharacterSet.controlCharacters.contains(scalar)
        }) else { diagnostic?(.codeWhitespaceOrControl); return nil }
        diagnostic?(.accepted)
        return value
    }
}

struct GoogleAuthenticationPresentation: Identifiable, Equatable, CustomStringConvertible {
    let id: UUID
    let handoffCode: String
    let diagnosticDeliveryID: UUID?

    init(id: UUID = UUID(), handoffCode: String, diagnosticDeliveryID: UUID? = nil) {
        self.id = id
        self.handoffCode = handoffCode
        self.diagnosticDeliveryID = diagnosticDeliveryID
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.handoffCode == rhs.handoffCode
    }

    var description: String {
        "GoogleAuthenticationPresentation(handoffCode: <redacted>)"
    }
}
