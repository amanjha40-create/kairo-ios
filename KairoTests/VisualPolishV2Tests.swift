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
        for style in [ColorScheme.light, .dark] {
            let standard = measure(layoutFixture, size: .large, style: style)
            let accessible = measure(layoutFixture, size: .accessibility5, style: style)
            assertFitsProposedWidth(accessible)
            XCTAssertGreaterThan(accessible.size.height, standard.size.height)
        }
    }

    func testLongButtonsAndCardsFitAtNormalTextSize() {
        for style in [ColorScheme.light, .dark] {
            let standard = measure(layoutFixture, size: .large, style: style)
            assertFitsProposedWidth(standard)
            XCTAssertGreaterThan(standard.size.height, 0)
            let short = measure(KairoPrimaryButton(title: "Continue") {}, size: .large, style: style, width: 160)
            let long = measure(KairoPrimaryButton(title: "Continue with the selected information") {}, size: .large, style: style, width: 160)
            XCTAssertLessThanOrEqual(long.size.width, 160 + 1 / max(1, long.scale))
            // The long label must wrap, not fit by truncating to one line.
            XCTAssertGreaterThan(long.size.height, short.size.height)
        }
    }

    private var layoutFixture: some View {
        KairoCard(accent: .identity) {
            KairoSectionHeading(title: "A long authoritative section title", count: 12)
            KairoPrimaryButton(title: "Continue with the selected information") {}
            KairoStatusChip(title: "Pending KairoID Review", tone: .pending)
        }
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

    private func assertFitsProposedWidth(_ measurement: (size: CGSize, scale: CGFloat),
                                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(measurement.scale, 1, file: file, line: line)
        // iOS 26.5 at 3x reports 320 + 1/3 pt for this 320-pt card; at 2x it
        // reports 320. Rendered 320-pt Light/Dark XXXL frames show full wrapping,
        // no clipping/overlap and zero safe-area inset. Allow only one physical
        // pixel of fitting-size rounding, not a device-independent epsilon.
        // Overflow beyond that pixel still fails; vertical expansion is separate.
        let pixel = 1 / max(1, measurement.scale)
        XCTAssertLessThanOrEqual(measurement.size.width, 320 + pixel, file: file, line: line)
    }

    private func measure<V: View>(_ view: V, size: DynamicTypeSize,
                                 style: ColorScheme, width: CGFloat = 320) -> (size: CGSize, scale: CGFloat) {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, size)
            .environment(\.colorScheme, style))
        return (host.sizeThatFits(in: CGSize(width: width, height: 10_000)), host.traitCollection.displayScale)
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
