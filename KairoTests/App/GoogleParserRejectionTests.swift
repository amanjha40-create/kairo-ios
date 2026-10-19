import XCTest
@testable import Kairo

@MainActor
final class GoogleParserRejectionTests: XCTestCase {
    private let base = "https://api.kairoid.com/auth/google/complete"
    private let syntheticCode = String(repeating: "a", count: 43)
    private var configuration: AppConfiguration {
        AppConfiguration(buildConfiguration: .production, environment: .production,
            isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .production),
            keychainService: "synthetic.parser.never.used")
    }

    private func check(_ url: URL, _ expected: AppLinkParser.DiagnosticReason,
                       file: StaticString = #filePath, line: UInt = #line) {
        var reasons: [AppLinkParser.DiagnosticReason] = []
        let destination = AppLinkParser.parse(url, configuration: configuration) { reasons.append($0) }
        XCTAssertEqual(reasons, [expected], file: file, line: line)
        XCTAssertEqual(destination != nil, expected == .accepted, file: file, line: line)
        XCTAssertTrue(destination == expectedWithGoogleFragmentPolicy(url), file: file, line: line)
    }

    private func expectedWithGoogleFragmentPolicy(_ url: URL) -> AppLinkDestination? {
        var reference = url
        if configuration.googleHandoffHosts.contains(url.host?.lowercased() ?? ""),
           url.path == "/auth/google/complete" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.fragment = nil
            reference = components.url!
        }
        return Build2ParserOracle.parse(reference, configuration: configuration)
    }

    private func query(_ suffix: String) -> URL { URL(string: base + suffix)! }

    func test_nonHTTPS() { check(URL(string: "http://api.kairoid.com/auth/google/complete?code=\(syntheticCode)")!, .nonHTTPSScheme) }
    func test_userInfo() { check(URL(string: "https://synthetic@api.kairoid.com/auth/google/complete?code=\(syntheticCode)")!, .userInfoPresent) }
    func test_explicitPort() { check(URL(string: "https://api.kairoid.com:443/auth/google/complete?code=\(syntheticCode)")!, .explicitPortPresent) }
    func test_fragment() { check(query("?code=\(syntheticCode)#synthetic"), .accepted) }
    func test_emptyFragment() { check(query("?code=\(syntheticCode)#"), .accepted) }
    func test_wrongHost() { check(URL(string: "https://untrusted.invalid/auth/google/complete?code=\(syntheticCode)")!, .hostMismatch) }
    func test_wrongPath() { check(URL(string: "https://api.kairoid.com/other?code=\(syntheticCode)")!, .pathMismatch) }
    func test_zeroQueryItems() { check(query(""), .queryCountInvalid) }
    func test_emptyQuery() { check(query("?"), .queryCountInvalid) }
    func test_duplicateQueryItems() { check(query("?code=\(syntheticCode)&code=\(syntheticCode)"), .queryCountInvalid) }
    func test_additionalQueryItems() { check(query("?code=\(syntheticCode)&state=synthetic"), .queryCountInvalid) }
    func test_wrongQueryName() { check(query("?Code=\(syntheticCode)"), .queryNameInvalid) }
    func test_missingValue() { check(query("?code"), .codeMissing) }
    func test_blankCode() { check(query("?code="), .codeEmpty) }
    func test_shortCode() { check(query("?code=short"), .codeTooShort) }
    func test_longCode() { check(query("?code=\(String(repeating: "a", count: 513))"), .codeTooLong) }
    func test_whitespaceCode() { check(query("?code=\(syntheticCode)%20"), .codeWhitespaceOrControl) }
    func test_controlCode() { check(query("?code=\(syntheticCode)%00"), .codeWhitespaceOrControl) }
    func test_validBackendShapeAccepted() { check(query("?code=\(syntheticCode)"), .accepted) }

    func test_reasonPrecedenceRetainsOriginalGuardOrder() {
        check(URL(string: "http://synthetic@untrusted.invalid:443/other?code=#fragment")!, .nonHTTPSScheme)
        check(query("?wrong=short#fragment"), .queryNameInvalid)
        check(query("?wrong=short&code=short"), .queryCountInvalid)
        check(query("?wrong=short"), .queryNameInvalid)
        check(query("?code=%20"), .codeTooShort)
    }

    func test_reasonRecordCannotContainURLOrCredentialValues() {
        let id = UUID()
        for reason in AppLinkParser.DiagnosticReason.allCases {
            let record = GoogleReturnDiagnostics.parserMessage(reason, deliveryID: id)
            XCTAssertEqual(record, "IOS_OAUTH_PARSER_RESULT reason=\(reason.rawValue) deliveryAttemptID=\(id.uuidString)")
            XCTAssertEqual(GoogleReturnDiagnostics.parserMessage(reason, deliveryID: nil),
                           "IOS_OAUTH_PARSER_RESULT reason=\(reason.rawValue)")
        }
    }

    func test_frozenBuild2EquivalenceExceptApprovedGoogleFragmentPolicy() {
        let prefixes = [base, base + "/", "HTTPS://API.KAIROID.COM/auth/google/complete",
            "https://api.kairoid.com/auth/google/%63omplete", "https://api.kairoid.com/Auth/google/complete",
            "https://app.kairoid.com/reset-password-confirm", "https://api.kairoid.com:443/auth/google/complete",
            "https://synthetic:synthetic@api.kairoid.com/auth/google/complete", "http://api.kairoid.com/auth/google/complete",
            "https://untrusted.invalid/auth/google/complete", "https:/auth/google/complete"]
        let values = ["", "a", String(repeating: "a", count: 19), String(repeating: "a", count: 20),
            syntheticCode, String(repeating: "a", count: 512), String(repeating: "a", count: 513),
            syntheticCode + "%20", syntheticCode + "%0A", syntheticCode + "%00",
            syntheticCode + "%2B", syntheticCode + "+", "%61" + syntheticCode,
            String(repeating: "%F0%9F%98%80", count: 20)]
        for prefix in prefixes {
            for name in ["code", "%63ode", "Code", "token", "other"] {
                for value in values {
                    for ending in ["", "#", "#synthetic", "&other=synthetic", "&code=synthetic"] {
                        guard let url = URL(string: "\(prefix)?\(name)=\(value)\(ending)") else { continue }
                        var reasons: [AppLinkParser.DiagnosticReason] = []
                        let actual = AppLinkParser.parse(url, configuration: configuration) { reasons.append($0) }
                        // Boolean comparison avoids printing even synthetic credential-bearing destinations.
                        XCTAssertTrue(actual == expectedWithGoogleFragmentPolicy(url))
                        XCTAssertEqual(reasons.count, 1)
                        XCTAssertEqual(reasons.first == .accepted, actual != nil)
                    }
                }
            }
        }
    }

    func test_fragmentCannotSupplyOrReplaceCode() {
        check(query("#code=\(syntheticCode)"), .queryCountInvalid)
        check(query("?code=short#code=\(syntheticCode)"), .codeTooShort)
        let destination = AppLinkParser.parse(query("?code=\(syntheticCode)#code=other&state=ignored"), configuration: configuration)
        XCTAssertTrue(destination == .googleHandoff(code: syntheticCode))
    }

    func test_invalidGoogleContractRemainsInvalidWithFragments() {
        let invalid = [
            "http://api.kairoid.com/auth/google/complete?code=\(syntheticCode)",
            "https://untrusted.invalid/auth/google/complete?code=\(syntheticCode)",
            "https://api.kairoid.com/other?code=\(syntheticCode)",
            base + "?code=\(syntheticCode)&extra=synthetic",
            base + "?code=\(syntheticCode)&code=\(syntheticCode)",
            base, base + "?code", base + "?code=", base + "?code=short",
            base + "?code=" + String(repeating: "a", count: 513),
            base + "?code=\(syntheticCode)%20", base + "?code=\(syntheticCode)%00",
            "https://api.kairoid.com:443/auth/google/complete?code=\(syntheticCode)",
            "https://synthetic@api.kairoid.com/auth/google/complete?code=\(syntheticCode)"
        ]
        for value in invalid {
            for fragment in ["#", "#non-auth", "#code=\(syntheticCode)&state=synthetic"] {
                XCTAssertNil(AppLinkParser.parse(URL(string: value + fragment)!, configuration: configuration))
            }
        }
    }

    func test_passwordResetFragmentPolicyUnchanged() {
        let reset = "https://app.kairoid.com/reset-password-confirm?token=\(syntheticCode)"
        check(URL(string: reset)!, .accepted)
        check(URL(string: reset + "#")!, .fragmentPresent)
        check(URL(string: reset + "#code=synthetic")!, .fragmentPresent)
    }
}

// Frozen acceptance oracle from 93b5dcf9f41d616f02942eb2bd9d58ead73bdd3a.
// Do not update it to match future parser behavior.
private enum Build2ParserOracle {
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
