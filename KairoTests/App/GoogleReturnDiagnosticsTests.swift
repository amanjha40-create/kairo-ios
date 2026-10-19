import XCTest
@testable import Kairo

@MainActor
final class GoogleReturnDiagnosticsTests: XCTestCase {
    func test_linkMetadataNeverRetainsQueryCredentialsOrUnapprovedHostPath() {
        let secret = "SENSITIVE_SENTINEL_abcdefghijklmnopqrstuvwxyz"
        let url = URL(string: "https://\(secret):\(secret)@untrusted.example/\(secret)?code=\(secret)&state=\(secret)#\(secret)")!
        let record = GoogleReturnDiagnostics.message(.openURLReceived, link: .init(url))
        XCTAssertEqual(record, "IOS_OAUTH_OPENURL_RECEIVED host=other path=other hasCode=true")
        XCTAssertFalse(record.contains(secret))
        XCTAssertFalse(record.contains("untrusted"))
    }

    func test_canonicalLinkHasOnlyAllowlistedMetadata() {
        let url = URL(string: "https://api.kairoid.com/auth/google/complete?code=synthetic_private_code_123456789")!
        let record = GoogleReturnDiagnostics.message(.linkValidated, state: .accepted, link: .init(url))
        XCTAssertEqual(record, "IOS_OAUTH_LINK_VALIDATED state=accepted host=api.kairoid.com path=/auth/google/complete hasCode=true")
        XCTAssertFalse(record.contains("synthetic"))
        XCTAssertFalse(GoogleReturnDiagnostics.LinkMetadata(nil).hasCode)
    }

    func test_deliveryCorrelationIsTaskLocalAndDoesNotEscapeItsScope() async {
        let first = UUID()
        let second = UUID()
        XCTAssertNil(GoogleReturnDiagnostics.deliveryAttemptID)
        await GoogleReturnDiagnostics.$deliveryAttemptID.withValue(first) {
            await Task.yield()
            XCTAssertTrue(GoogleReturnDiagnostics.message(.exchangeStarted).contains(first.uuidString))
            GoogleReturnDiagnostics.$deliveryAttemptID.withValue(second) {
                XCTAssertTrue(GoogleReturnDiagnostics.message(.exchangeResponse).contains(second.uuidString))
            }
            XCTAssertEqual(GoogleReturnDiagnostics.deliveryAttemptID, first)
        }
        XCTAssertNil(GoogleReturnDiagnostics.deliveryAttemptID)
    }

    func test_presentationCarriesDiagnosticIDWithoutChangingIdentityOrCode() {
        let router = AppRouter()
        let config = AppConfiguration(buildConfiguration: .production, environment: .production,
            isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .production),
            keychainService: "synthetic.diagnostics.never.used")
        let id = UUID()
        let code = "synthetic_private_code_123456789"
        XCTAssertTrue(router.handleIncomingURL(URL(string: "https://api.kairoid.com/auth/google/complete?code=\(code)")!, configuration: config, diagnosticDeliveryID: id))
        XCTAssertEqual(router.googleAuthenticationPresentation?.diagnosticDeliveryID, id)
        XCTAssertEqual(router.googleAuthenticationPresentation?.handoffCode, code)
        let identity = UUID()
        XCTAssertEqual(GoogleAuthenticationPresentation(id: identity, handoffCode: code, diagnosticDeliveryID: id), GoogleAuthenticationPresentation(id: identity, handoffCode: code))
    }

    func test_rootEnumsNeverIncludeAssociatedPrivateValues() {
        let router = AppRouter()
        XCTAssertEqual(router.diagnosticAuthRoot, .welcome)
        router.showLogin()
        XCTAssertEqual(router.diagnosticAuthRoot, .login)
        router.showForgotPassword(initialEmail: "private@example.invalid")
        XCTAssertEqual(router.diagnosticAuthRoot, .login)
        router.showPasswordReset(token: "private-reset-value")
        XCTAssertEqual(router.diagnosticAuthRoot, .login)
        router.showGooglePhoneCompletion()
        XCTAssertEqual(router.diagnosticAuthRoot, .onboarding)
        router.enterMainTabs()
        XCTAssertEqual(router.diagnosticAuthRoot, .mainTabs)
    }

    func test_httpMetadataIsBoundedAndIDsAreTypedUUIDs() {
        let id = UUID()
        let record = GoogleReturnDiagnostics.message(.exchangeResponse, httpStatus: 200, requestID: id)
        XCTAssertTrue(record.contains("httpStatus=200"))
        XCTAssertTrue(record.contains(id.uuidString))
        XCTAssertFalse(GoogleReturnDiagnostics.message(.exchangeResponse, httpStatus: 999).contains("httpStatus"))
    }
}
