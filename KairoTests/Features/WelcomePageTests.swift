import XCTest
import CoreGraphics
@testable import Kairo

@MainActor
final class WelcomePageTests: XCTestCase {
    func testExactFourPageReferenceStoryAndSequence() {
        XCTAssertEqual(WelcomePage.allCases, [.career, .identity, .sharing, .ownership])
        XCTAssertEqual(WelcomePage.allCases.map(\.headline), ["Your career.", "One identity.", "Share with confidence.", "Your verified career"])
        XCTAssertEqual(WelcomePage.allCases.map(\.accentHeadline), ["Verified once.", "All your trust.", "Wherever you need.", "comes with you."])
        XCTAssertEqual(WelcomePage.allCases.map(\.support), [
            "Build a verified professional identity that stays with you and can be shared wherever your career takes you.",
            "We bring your verified career information together in one secure identity.",
            "Share your verified identity instantly and open doors to new opportunities.",
            "Build your professional identity once and share it whenever you need."
        ])
        XCTAssertEqual(WelcomePage.allCases.compactMap(\.next), [.identity, .sharing, .ownership])
        XCTAssertNil(WelcomePage.ownership.next)
    }

    func testReferencePrivacyOwnershipAndCTAContent() {
        XCTAssertEqual(WelcomePage.allCases.map(\.primaryButtonTitle), ["Get Started", "Continue", "Continue", "Get Started"])
        XCTAssertEqual(WelcomePage.identity.benefit?.title, "Private by default")
        XCTAssertEqual(WelcomePage.identity.benefit?.body, "Only you decide what to share and with whom.")
        XCTAssertEqual(WelcomePage.sharing.benefit?.title, "You’re always in control")
        XCTAssertEqual(WelcomePage.sharing.benefit?.body, "Share what matters, with the right people, for the right purpose.")
        XCTAssertEqual(WelcomePage.ownershipBenefits.map(\.title), ["Verify once", "You own it", "Share with confidence"])
        XCTAssertEqual(WelcomePage.ownershipBenefits.map(\.body), [
            "We verify with trusted sources.", "Your verified identity stays with you.", "Share what matters, where it matters."
        ])
    }

    func testArtworkHierarchyAndViewportsExcludeFlattenedControls() {
        XCTAssertEqual(WelcomePage.allCases.map(\.artworkComesFirst), [true, false, false, true])
        for page in WelcomePage.allCases {
            XCTAssertFalse(page.artworkDescription.isEmpty)
            XCTAssertGreaterThan(page.artworkCrop.minY, 0)
            XCTAssertLessThan(page.artworkCrop.maxY, page.artworkSize.height - 400)
            XCTAssertEqual(page.artworkCrop.width, page.artworkSize.width)
        }
    }
}
