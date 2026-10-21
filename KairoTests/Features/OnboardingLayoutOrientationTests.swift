import SwiftUI
import XCTest
@testable import Kairo

@MainActor
final class OnboardingLayoutOrientationTests: XCTestCase {
    func testPortraitSEDoesNotReplaceFormWhenKeyboardCompressesViewport() {
        for height in [593.0, 333.0, 250.0] {
            XCTAssertFalse(OnboardingLayoutOrientation.isLandscape(
                viewport: CGSize(width: 375, height: height),
                horizontalSizeClass: .compact, verticalSizeClass: .regular))
        }
    }

    func testLargePortraitPhoneRetainsPortraitLayoutWithKeyboard() {
        for height in [852.0, 480.0, 300.0] {
            XCTAssertFalse(OnboardingLayoutOrientation.isLandscape(
                viewport: CGSize(width: 430, height: height),
                horizontalSizeClass: .compact, verticalSizeClass: .regular))
        }
    }

    func testActualLandscapePhoneRetainsLandscapeLayout() {
        XCTAssertTrue(OnboardingLayoutOrientation.isLandscape(
            viewport: CGSize(width: 667, height: 300),
            horizontalSizeClass: .compact, verticalSizeClass: .compact))
        XCTAssertTrue(OnboardingLayoutOrientation.isLandscape(
            viewport: CGSize(width: 932, height: 350),
            horizontalSizeClass: .regular, verticalSizeClass: .compact))
    }

    func testRegularWidthAndUnknownTraitsPreserveExistingAdaptiveLayout() {
        for sizeClass in [UserInterfaceSizeClass.regular, nil] {
            XCTAssertTrue(OnboardingLayoutOrientation.isLandscape(
                viewport: CGSize(width: 1024, height: 768),
                horizontalSizeClass: sizeClass, verticalSizeClass: .regular))
            XCTAssertFalse(OnboardingLayoutOrientation.isLandscape(
                viewport: CGSize(width: 768, height: 1024),
                horizontalSizeClass: sizeClass, verticalSizeClass: .regular))
        }
    }
}
