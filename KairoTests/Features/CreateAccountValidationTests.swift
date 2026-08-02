import XCTest
@testable import Kairo

final class CreateAccountValidationTests: XCTestCase {
    func test_validDraftPassesValidation() {
        let draft = CreateAccountDraft(
            firstName: "Aman",
            lastName: "Jha",
            emailAddress: "aman@example.com",
            mobileNumber: "9876543210",
            password: "StrongPassword123!"
        )

        XCTAssertTrue(CreateAccountValidation.isFormValid(draft))
    }

    func test_requiredFieldsReturnExpectedMessages() {
        let draft = CreateAccountDraft()

        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .firstName, in: draft),
            "Enter your first name."
        )
        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .lastName, in: draft),
            "Enter your last name."
        )
        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .emailAddress, in: draft),
            "Enter your email address."
        )
        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .mobileNumber, in: draft),
            "Enter your mobile number."
        )
        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .password, in: draft),
            "Enter a password."
        )
    }

    func test_invalidEmailFailsValidation() {
        let draft = CreateAccountDraft(
            firstName: "Aman",
            lastName: "Jha",
            emailAddress: "aman@invalid",
            mobileNumber: "9876543210",
            password: "StrongPassword123!"
        )

        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .emailAddress, in: draft),
            "Enter a valid email address."
        )
        XCTAssertFalse(CreateAccountValidation.isFormValid(draft))
    }

    func test_emailValidationTrimsWhitespaceAndRequiresFullMatch() {
        let trimmedDraft = CreateAccountDraft(
            firstName: "Aman",
            lastName: "Jha",
            emailAddress: "  aman@example.com  ",
            mobileNumber: "9876543210",
            password: "StrongPassword123!"
        )
        let invalidDraft = CreateAccountDraft(
            firstName: "Aman",
            lastName: "Jha",
            emailAddress: "<aman@example.com>",
            mobileNumber: "9876543210",
            password: "StrongPassword123!"
        )

        XCTAssertNil(CreateAccountValidation.errorMessage(for: .emailAddress, in: trimmedDraft))
        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .emailAddress, in: invalidDraft),
            "Enter a valid email address."
        )
    }

    func test_mobileNumberMustBeExactlyTenDigits() {
        let draft = CreateAccountDraft(
            firstName: "Aman",
            lastName: "Jha",
            emailAddress: "aman@example.com",
            mobileNumber: "987654321",
            password: "StrongPassword123!"
        )

        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .mobileNumber, in: draft),
            "Enter a valid 10-digit Indian mobile number."
        )
        XCTAssertFalse(CreateAccountValidation.isFormValid(draft))
    }

    func test_mobileNumberSanitizerNormalizesCommonIndianFormats() {
        XCTAssertEqual(
            CreateAccountValidation.sanitizedMobileNumber("+91 98765-43210 ext"),
            "9876543210"
        )
        XCTAssertEqual(
            CreateAccountValidation.sanitizedMobileNumber("09876543210"),
            "9876543210"
        )
    }

    func test_mobileNumberSubmissionFormatsToE164() {
        XCTAssertEqual(
            CreateAccountValidation.e164PhoneNumber("98765 43210"),
            "+919876543210"
        )
    }

    func test_passwordMustMeetBackendMinimumLength() {
        let draft = CreateAccountDraft(
            firstName: "Aman",
            lastName: "Jha",
            emailAddress: "aman@example.com",
            mobileNumber: "9876543210",
            password: "Short123"
        )

        XCTAssertEqual(
            CreateAccountValidation.errorMessage(for: .password, in: draft),
            "Use at least 12 characters."
        )
        XCTAssertFalse(CreateAccountValidation.isFormValid(draft))
    }

    func test_fullNameCombinesTrimmedFirstAndLastName() {
        XCTAssertEqual(
            CreateAccountValidation.normalizedFullName(
                firstName: "  Aman ",
                lastName: " Jha  "
            ),
            "Aman Jha"
        )
    }
}
