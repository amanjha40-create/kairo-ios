import XCTest
import SwiftUI
import UIKit
@testable import Kairo

@MainActor
final class Batch4HomePresentationTests: XCTestCase {
    func testAttentionAndProgressKeepDistinctAuthoritativeDestinations() {
        guard case .populated(let content) = Batch4HomeScenario.attention.state.phase else { return XCTFail() }
        XCTAssertEqual(content.verificationRequests.filter(\.needsAttention).map(\.authoritativeDestinationID), ["synthetic-attention"])
        XCTAssertEqual(content.verificationRequests.filter { !$0.needsAttention }.map(\.authoritativeDestinationID), ["synthetic-progress"])
    }
    func testUpstreamTaskPriorityAndRecommendationDeduplicationRemain() {
        guard case .populated(let content) = Batch4HomeScenario.partial.state.phase else { return XCTFail() }
        XCTAssertEqual(content.visibleTrustTasks.map(\.priority), [1, 2])
        XCTAssertEqual(content.compactTrustTasks.map(\.title), ["Add your employment history"])
        XCTAssertEqual(content.recommendation.destinationTab, .career)
    }
    func testCompleteAndNoTasksDoNotInventRequiredWork() {
        for scenario in [Batch4HomeScenario.complete, .noTasks] {
            guard case .populated(let content) = scenario.state.phase else { return XCTFail() }
            XCTAssertEqual(content.profileCompletion.percentage, 100)
            XCTAssertTrue(content.trustTasks.isEmpty)
            XCTAssertTrue(content.verificationRequests.isEmpty)
        }
    }
    func testUnavailableScoreDoesNotInferPassportReadinessOrRequests() {
        guard case .populated(let content) = Batch4HomeScenario.unavailable.state.phase else { return XCTFail() }
        XCTAssertNil(content.trustScore.score)
        XCTAssertFalse(content.verificationRequestsAvailable)
        XCTAssertTrue(content.verificationRequests.isEmpty)
    }
    func testEmptyErrorLoadingStatesStayDistinct() {
        guard case .empty = Batch4HomeScenario.empty.state.phase else { return XCTFail() }
        XCTAssertEqual(Batch4HomeScenario.loading.state.phase, .loading)
        for scenario in [Batch4HomeScenario.error, .offline] {
            guard case .error = scenario.state.phase else { return XCTFail() }
        }
    }
    func testTextContrastOnEveryChangedSurfaceInBothModes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for background in [KairoColors.background, KairoColors.surface, KairoColors.surfaceMuted, KairoColors.surfaceBrand] {
                for foreground in [KairoColors.textPrimary, KairoColors.textSecondary] {
                    XCTAssertGreaterThanOrEqual(contrast(foreground, background, style), 4.5)
                }
            }
            XCTAssertGreaterThanOrEqual(contrast(KairoColors.teal, KairoColors.surfaceBrand, style), 3)
            XCTAssertGreaterThanOrEqual(contrast(KairoColors.onPrimary, KairoColors.brandPrimary, style), 4.5)
        }
    }
    func testDarkCanvasSurfaceMutedAndBorderRemainExact() {
        for (color, hex) in [(KairoColors.background, 0x0B1220), (KairoColors.surface, 0x141F32),
                             (KairoColors.surfaceMuted, 0x202D42), (KairoColors.border, 0x39465A)] {
            let actual = rgb(color, .dark)
            let expected = rgb(Color(hex: UInt(hex)), .dark)
            for (a, b) in zip(actual, expected) { XCTAssertEqual(a, b, accuracy: 0.001) }
        }
    }
    func testLightCanvasAndSurfaceAreDifferentiatedWithoutNewHueFamily() {
        XCTAssertNotEqual(rgb(KairoColors.background, .light), rgb(KairoColors.surface, .light))
        XCTAssertNotEqual(rgb(KairoColors.surfaceBrand, .light), rgb(KairoColors.surface, .light))
    }
    private func rgb(_ color: Color, _ style: UIUserInterfaceStyle) -> [CGFloat] {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b]
    }
    private func contrast(_ a: Color, _ b: Color, _ style: UIUserInterfaceStyle) -> Double {
        func luminance(_ color: Color) -> Double {
            let linear = rgb(color, style).map { value -> Double in
                let v = Double(value); return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
