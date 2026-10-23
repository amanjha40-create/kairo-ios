import XCTest
import SwiftUI
import UIKit
@testable import Kairo

@MainActor
final class VisualPolishV2Tests: XCTestCase {
    func testSemanticTextContrastInBothModes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for role in KairoSemanticAccent.allCases {
                for text in [role.foreground, KairoColors.textPrimary, KairoColors.textSecondary] {
                    XCTAssertGreaterThanOrEqual(contrast(text, role.surface, style), 4.5, "\(role), \(style)")
                }
            }
        }
    }

    func testButtonAndFieldContrastInBothModes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for pair in [(KairoColors.onPrimary, KairoColors.brandPrimary),
                         (KairoColors.onDanger, KairoColors.danger),
                         (KairoColors.textSecondary, KairoColors.fieldSurface)] {
                XCTAssertGreaterThanOrEqual(contrast(pair.0, pair.1, style), 4.5)
            }
            XCTAssertGreaterThanOrEqual(contrast(KairoColors.fieldBorder, KairoColors.fieldSurface, style), 3)
        }
    }

    func testSemanticSurfacesSeparateFromCanvas() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for role in KairoSemanticAccent.allCases {
                XCTAssertNotEqual(rgb(role.surface, style), rgb(KairoColors.background, style))
            }
        }
    }

    func testLongButtonsAndCardsExpandAtXXXL() {
        let view = KairoCard(accent: .identity) {
            KairoSectionHeading(title: "A long authoritative section title", count: 12)
            KairoPrimaryButton(title: "Continue with the selected information") {}
            KairoStatusChip(title: "Pending KairoID Review", tone: .pending)
        }
        let standard = measure(view, size: .large)
        let accessible = measure(view, size: .accessibility5)
        XCTAssertLessThanOrEqual(accessible.width, 320)
        XCTAssertGreaterThan(accessible.height, standard.height)
    }

    func testTouchTargetsAndRoleLabelsRemain() {
        XCTAssertGreaterThanOrEqual(KairoControlMetrics.buttonHeight, 44)
        XCTAssertGreaterThanOrEqual(KairoControlMetrics.minimumTarget, 44)
        for tone in KairoStatusTone.allCases {
            XCTAssertFalse(tone.canonicalTitle.isEmpty)
            XCTAssertFalse(tone.symbol.isEmpty)
        }
        XCTAssertEqual(KairoStatusChip(title: "Authoritative status", tone: .attention).title, "Authoritative status")
    }

    func testReducedMotionKeepsStaticReadableEndState() {
        let plan = KairoMotion.pageEntrancePlan(reduceMotion: true)
        XCTAssertEqual(plan.initialOpacity, 1)
        XCTAssertEqual(plan.initialOffset, 0)
        XCTAssertNil(plan.duration)
    }

    private func measure<V: View>(_ view: V, size: DynamicTypeSize) -> CGSize {
        UIHostingController(rootView: view.environment(\.dynamicTypeSize, size))
            .sizeThatFits(in: CGSize(width: 320, height: 10_000))
    }
    private func rgb(_ color: Color, _ style: UIUserInterfaceStyle) -> [Double] {
        let color = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Double(r), Double(g), Double(b)]
    }
    private func contrast(_ first: Color, _ second: Color, _ style: UIUserInterfaceStyle) -> Double {
        func luminance(_ color: Color) -> Double {
            let c = rgb(color, style).map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
