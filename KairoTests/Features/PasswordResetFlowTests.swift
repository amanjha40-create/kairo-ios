import XCTest
@testable import Kairo

@MainActor
final class PasswordResetFlowTests: XCTestCase {
    func test_invalidEmailIsRejected() {
        XCTAssertNotNil(PasswordResetValidation.emailMessage("aman@"))
        XCTAssertNil(PasswordResetValidation.emailMessage("aman@example.com"))
    }

    func test_passwordPolicyMatchesBackendLengthRange() {
        XCTAssertNotNil(PasswordResetValidation.newPasswordMessage("short"))
        XCTAssertNil(PasswordResetValidation.newPasswordMessage(String(repeating: "a", count: 12)))
        XCTAssertNil(PasswordResetValidation.newPasswordMessage(String(repeating: "a", count: 128)))
        XCTAssertNotNil(PasswordResetValidation.newPasswordMessage(String(repeating: "a", count: 129)))
    }

    func test_passwordConfirmationMustMatch() {
        XCTAssertEqual(
            PasswordResetValidation.confirmationMessage(
                password: "a-valid-password",
                confirmation: "a-different-password"
            ),
            "Passwords do not match."
        )
        XCTAssertNil(PasswordResetValidation.confirmationMessage(
            password: "a-valid-password",
            confirmation: "a-valid-password"
        ))
    }

    func test_tokenUsesBackendLengthBoundsWithoutTransformingValue() {
        XCTAssertNotNil(PasswordResetValidation.tokenMessage("short"))
        XCTAssertNil(PasswordResetValidation.tokenMessage(String(repeating: "t", count: 20)))
        XCTAssertNil(PasswordResetValidation.tokenMessage(String(repeating: "t", count: 512)))
        XCTAssertNotNil(PasswordResetValidation.tokenMessage(String(repeating: "t", count: 513)))
    }

    func test_sensitiveFieldsAreClearedAfterSuccess() {
        var state = PasswordResetFlowState(emailAddress: "aman@example.com")
        state.token = "private-token-value"
        state.newPassword = "private-password"
        state.confirmPassword = "private-password"

        state.showSuccess()

        XCTAssertEqual(state.phase, .success)
        XCTAssertEqual(state.emailAddress, "aman@example.com")
        XCTAssertTrue(state.token.isEmpty)
        XCTAssertTrue(state.newPassword.isEmpty)
        XCTAssertTrue(state.confirmPassword.isEmpty)
    }

    func test_requestNewResetClearsSensitiveFields() {
        var state = PasswordResetFlowState(emailAddress: "aman@example.com")
        state.showResetForm()
        state.token = "private-token-value"
        state.newPassword = "private-password"
        state.confirmPassword = "private-password"

        state.requestNewReset()

        XCTAssertEqual(state.phase, .request)
        XCTAssertTrue(state.token.isEmpty)
        XCTAssertTrue(state.newPassword.isEmpty)
        XCTAssertTrue(state.confirmPassword.isEmpty)
    }

    func test_invalidTokenShowsLifecycleSafeMessageAndRecoveryAction() {
        assertTokenLifecycleFailurePresentation()
    }

    func test_expiredTokenShowsLifecycleSafeMessageAndRecoveryAction() {
        assertTokenLifecycleFailurePresentation()
    }

    func test_consumedTokenShowsLifecycleSafeMessageAndRecoveryAction() {
        assertTokenLifecycleFailurePresentation()
    }

    func test_rateLimitHasSpecificMessage() {
        let presentation = PasswordResetErrorPresentation.resolve(
            apiError(statusCode: 429, code: .rateLimited, message: "rate limited"),
            context: .requestEmail
        )

        XCTAssertEqual(presentation.message, "Too many reset attempts. Please wait and try again.")
        XCTAssertFalse(presentation.offersNewReset)
    }

    func test_backendValidationUsesFieldMessage() {
        let error = NetworkError.api(APIError(
            statusCode: 422,
            code: .validationError,
            message: "Request validation failed",
            fieldErrors: ["new_password": ["Password must be at least 12 characters"]],
            globalErrors: [],
            validationDetails: []
        ))

        let presentation = PasswordResetErrorPresentation.resolve(error, context: .submitReset)

        XCTAssertEqual(presentation.message, "Password must be at least 12 characters")
    }

    func test_backend5xxHasServiceMessage() {
        let presentation = PasswordResetErrorPresentation.resolve(
            apiError(statusCode: 500, code: .internalError, message: "internal"),
            context: .submitReset
        )

        XCTAssertEqual(presentation.message, "Kairo is temporarily unavailable. Please try again.")
    }

    func test_transportFailureIsDistinctFromBackendFailure() {
        let presentation = PasswordResetErrorPresentation.resolve(
            NetworkError.transport("timed out"),
            context: .submitReset
        )

        XCTAssertEqual(
            presentation.message,
            "Kairo couldn't reach the network. Check your connection and try again."
        )
    }

    func test_demoResetIsDeterministicAndDoesNotCreateAuthenticatedSession() async throws {
        let tokenStore = InMemoryTokenStore()
        let configuration = AppConfiguration(
            buildConfiguration: .demo,
            environment: .development,
            isDemoModeEnabled: true,
            apiBaseURL: APIConfiguration.baseURL(for: .development),
            keychainService: "com.kairoid.Kairo.tests.password-reset-demo"
        )
        let sessionService = SessionService(
            configuration: configuration,
            networkClient: DemoNetworkClient(),
            tokenStore: tokenStore
        )
        let service = DemoAuthService(sessionService: sessionService)

        let requestResponse = try await service.requestPasswordReset(email: "nobody@example.com")
        let resetResponse = try await service.resetPassword(
            token: String(repeating: "t", count: 20),
            newPassword: "a-valid-password",
            confirmPassword: "a-valid-password"
        )

        XCTAssertEqual(
            requestResponse.message,
            "If an account exists for that email, a password reset email has been sent."
        )
        XCTAssertEqual(resetResponse.message, "Password reset successful.")
        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        XCTAssertNil(accessToken)
        XCTAssertNil(refreshToken)
    }

    private func assertTokenLifecycleFailurePresentation() {
        let presentation = PasswordResetErrorPresentation.resolve(
            apiError(
                statusCode: 401,
                code: .unauthorized,
                message: "Invalid or expired password reset token"
            ),
            context: .submitReset
        )

        XCTAssertEqual(
            presentation.message,
            "This reset token is invalid, expired, or already used."
        )
        XCTAssertTrue(presentation.offersNewReset)
    }

    private func apiError(
        statusCode: Int,
        code: APIErrorCode,
        message: String
    ) -> NetworkError {
        NetworkError.api(APIError(
            statusCode: statusCode,
            code: code,
            message: message,
            fieldErrors: [:],
            globalErrors: [],
            validationDetails: []
        ))
    }
}
