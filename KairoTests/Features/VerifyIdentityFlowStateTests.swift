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
