import XCTest
@testable import Kairo

@MainActor
final class PostPolishBugBatchTests: XCTestCase {
    func testResumeDateDisplayAndWireAreSeparate() throws {
        let date = try XCTUnwrap(ResumeReviewDate.parse("2024-02-29"))
        XCTAssertEqual(ResumeReviewDate.display("2024-02-29"), "2024/02/29")
        XCTAssertEqual(ResumeReviewDate.wire(date), "2024-02-29")
        XCTAssertNil(ResumeReviewDate.parse("2023-02-29"))
        XCTAssertNil(ResumeReviewDate.parse("2024-13-01"))
    }
    func testLegacyResumeDatesAreNotInvented() {
        for raw in ["2020", "2020-03", "Present", "Unspecified"] {
            XCTAssertNil(ResumeReviewDate.parse(raw))
            XCTAssertEqual(ResumeReviewDate.display(raw), raw)
        }
    }
    func testDOBPickerRoundTripPreservesCanonicalFormat() throws {
        let date = try XCTUnwrap(ProfileBirthDate.parse("29022000"))
        XCTAssertEqual(ProfileBirthDate.display(date), "29-02-2000")
        XCTAssertEqual(ProfileBirthDate.wire(date), "2000-02-29")
    }
    func testNewPasswordCompositionAndLength() {
        for invalid in ["abcdefghijkl", "abcdefghij12", "1234567890!!", "abcdefghijk!", "abcdefghij1 "] {
            XCTAssertNotNil(CreateAccountValidation.passwordErrorMessage(invalid))
            XCTAssertNotNil(PasswordResetValidation.newPasswordMessage(invalid))
        }
        for valid in ["abcdefghij1!", "Multi word pass 9!"] {
            XCTAssertNil(CreateAccountValidation.passwordErrorMessage(valid))
            XCTAssertNil(PasswordResetValidation.newPasswordMessage(valid))
        }
    }
    func testTourDestinationSequencePreservesFourTabs() {
        XCTAssertEqual(CandidateTab.allCases, [.home, .career, .passport, .more])
        XCTAssertEqual(GuidedTourStep.allCases.map(\.destination), [.home, .passport, .career, .verify, .more])
        let router = AppRouter(rootDestination: .mainTabs)
        router.selectTab(.verify)
        XCTAssertEqual(router.selectedTab, .career)
        XCTAssertTrue(router.showsCareerVerification)
    }
    func testReceivedRejectionAndApprovalAreNotDroppedOrInvented() {
        for event in ["verification_rejected", "verification_approved", "verification_updated"] {
            let dto = CandidateNotificationDTO(publicID: "fixture", category: "verification", eventType: event,
                title: "Backend supplied title", body: "Backend supplied outcome", metadata: [:], readAt: nil, createdAt: .distantPast)
            let mapped = CandidateNotificationMapper.map(dto)
            XCTAssertEqual(mapped.destination, .verify)
            XCTAssertEqual(mapped.title, dto.title)
            XCTAssertEqual(mapped.message, dto.body)
            XCTAssertFalse(mapped.isRead)
            XCTAssertFalse(mapped.categorySystemImage.contains("checkmark"))
        }
    }
    func testUnknownDegreeRemainsCustom() {
        XCTAssertTrue(CandidateDegreeCatalogue.isCustom("Existing uncommon degree"))
        XCTAssertFalse(CandidateDegreeCatalogue.isCustom("Master of Business Administration (MBA)"))
    }
}
