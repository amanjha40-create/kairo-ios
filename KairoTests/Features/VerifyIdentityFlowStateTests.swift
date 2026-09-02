import XCTest
@testable import Kairo

final class VerifyIdentityFlowStateTests: XCTestCase {
    func test_preparePrefillsCreateAccountContactsWhenVerificationIsPristine() {
        var state = VerifyIdentityFlowState()

        state.prepare(using: CreateAccountDraft(
            firstName: "Aman",
            lastName: "Jha",
            emailAddress: "aman@example.com",
            mobileNumber: "98765 43210"
        ))

        XCTAssertEqual(state.email.contactValue, "aman@example.com")
        XCTAssertEqual(state.mobile.contactValue, "9876543210")
    }

    func test_recoveryUsesAuthoritativeMaskedContactsInsteadOfStaleDraftValues() {
        let now = Date(timeIntervalSince1970: 1_788_400_000)
        var state = VerifyIdentityFlowState()
        state.prepare(using: CreateAccountDraft(
            firstName: "Stale",
            lastName: "Draft",
            emailAddress: "stale@example.com",
            mobileNumber: "9876543210"
        ))

        state.applyRecovery(
            SignupSessionRecoveryResponseDTO(
                state: .valid,
                emailMasked: "am***@example.com",
                phoneMasked: "+91******9299",
                emailVerified: false,
                phoneVerified: false,
                nextStep: .verifyEmail,
                expiresAt: now.addingTimeInterval(900),
                emailResendAvailableAt: now.addingTimeInterval(41),
                phoneResendAvailableAt: nil
            ),
            now: now
        )

        XCTAssertEqual(state.phase, .email)
        XCTAssertEqual(state.email.contactValue, "am***@example.com")
        XCTAssertEqual(state.mobile.contactValue, "+91******9299")
        XCTAssertTrue(state.email.isAuthoritativeContact)
        XCTAssertTrue(state.mobile.isAuthoritativeContact)
        XCTAssertTrue(state.email.hasSentCode)
        XCTAssertEqual(state.email.countdownRemaining, 41)

        state.email.setContactValue("replacement@example.com")
        XCTAssertEqual(state.email.contactValue, "am***@example.com")
    }

    func test_recoveryResumesAtPhoneWithoutRequiringEmailAgain() {
        let now = Date(timeIntervalSince1970: 1_788_400_000)
        var state = VerifyIdentityFlowState()

        state.applyRecovery(
            SignupSessionRecoveryResponseDTO(
                state: .valid,
                emailMasked: "am***@example.com",
                phoneMasked: "+91******9299",
                emailVerified: true,
                phoneVerified: false,
                nextStep: .verifyPhone,
                expiresAt: now.addingTimeInterval(900),
                emailResendAvailableAt: nil,
                phoneResendAvailableAt: nil
            ),
            now: now
        )

        XCTAssertEqual(state.phase, .mobile)
        XCTAssertTrue(state.email.isVerified)
        XCTAssertFalse(state.mobile.isVerified)
        XCTAssertTrue(state.mobile.canSendCode)
    }

    func test_recoveryWithBothChannelsVerifiedResumesCompletionStep() {
        let now = Date(timeIntervalSince1970: 1_788_400_000)
        var state = VerifyIdentityFlowState()

        state.applyRecovery(
            SignupSessionRecoveryResponseDTO(
                state: .valid,
                emailMasked: "am***@example.com",
                phoneMasked: "+91******9299",
                emailVerified: true,
                phoneVerified: true,
                nextStep: .completeSignup,
                expiresAt: now.addingTimeInterval(900),
                emailResendAvailableAt: nil,
                phoneResendAvailableAt: nil
            ),
            now: now
        )

        XCTAssertEqual(state.phase, .mobile)
        XCTAssertTrue(state.email.isVerified)
        XCTAssertTrue(state.mobile.isVerified)
    }

    func test_otpValidationRequiresSixDigits() {
        var state = ContactVerificationState(channel: .email, contactValue: "aman@example.com")
        state.beginSendingCode()
        state.completeSendingCode()

        state.setOTPCode("12a3")

        XCTAssertEqual(state.otpCode, "123")
        XCTAssertEqual(state.otpErrorMessage, "Enter the full 6-digit code.")
        XCTAssertFalse(state.canVerify)
    }

    func test_countdownTicksToZeroBeforeResendIsEnabled() {
        var state = ContactVerificationState(channel: .mobile, contactValue: "9876543210")
        state.beginSendingCode()
        state.completeSendingCode()

        for _ in 0..<state.channel.countdownDuration {
            state.tickCountdown()
        }

        XCTAssertEqual(state.countdownRemaining, 0)
        XCTAssertTrue(state.canResendCode)
        XCTAssertEqual(state.countdownText, "You can resend a code now.")
    }

    func test_successfulVerificationTransitionsIntoVerifiedState() {
        var state = ContactVerificationState(channel: .email, contactValue: "aman@example.com")
        state.beginSendingCode()
        state.completeSendingCode()
        state.setOTPCode("123456")

        state.beginVerification()
        state.completeVerification()

        XCTAssertTrue(state.isVerified)
        XCTAssertFalse(state.isVerifying)
        XCTAssertFalse(state.canVerify)
        XCTAssertEqual(state.countdownRemaining, 0)
    }

    func test_resetForContactChangeClearsDeliveryAndVerificationState() {
        var state = ContactVerificationState(channel: .mobile, contactValue: "9876543210")
        state.beginSendingCode()
        state.completeSendingCode()
        state.setOTPCode("123456")
        state.beginVerification()
        state.completeVerification()

        state.resetForContactChange()

        XCTAssertEqual(state.otpCode, "")
        XCTAssertFalse(state.hasSentCode)
        XCTAssertFalse(state.isVerified)
        XCTAssertEqual(state.countdownRemaining, 0)
        XCTAssertEqual(state.contactValue, "9876543210")
    }
}
