import XCTest
import SwiftUI
@testable import Kairo

@MainActor
final class VisualParityTests: XCTestCase {
    func testCompactDestinationExpandsForLongMetadataAndAccessibilityType() {
        let row = KairoCompactDestinationRow(
            title: "Documents and supporting professional records",
            metadata: "Candidate-provided records remain unverified until authoritatively confirmed.",
            systemImage: "doc.on.doc", action: {}
        )
        let standard = size(row)
        let accessible = size(row, dynamicType: .accessibility3)
        XCTAssertGreaterThanOrEqual(standard.height, 44)
        XCTAssertGreaterThan(accessible.height, standard.height)
        // Hosting measurement rounds fractional text layout to device pixels.
        XCTAssertLessThanOrEqual(accessible.width, 320 + 1 / UITraitCollection.current.displayScale)
    }

    func testCompactSectionIsOptInAndDoesNotChangeDefaultSpacing() {
        let regular = size(KairoSection { Text("Section") })
        let compact = size(KairoSection(compact: true) { Text("Section") })
        XCTAssertEqual(regular.height - compact.height,
                       2 * (KairoSpacing.medium - KairoSpacing.xSmall), accuracy: 0.5)
    }

    func testLongDocumentRowsExpandAtAccessibilitySizes() {
        let view = KairoDocumentRow(
            filename: "Employment-confirmation-and-supporting-evidence-with-a-long-filename.pdf",
            metadata: "Employment · 20 MB", source: "A long employer name and source record",
            status: "Pending KairoID Review", isHistorical: true,
            details: { EmptyView() }, actions: { Button("View securely") {}.buttonStyle(KairoActionStyle()) }
        )
        let standard = size(view, dynamicType: .large)
        let accessible = size(view, dynamicType: .accessibility3)
        XCTAssertLessThanOrEqual(standard.width, 320)
        XCTAssertLessThanOrEqual(accessible.width, 320)
        XCTAssertGreaterThan(accessible.height, standard.height)
    }

    func testStatusChipsKeepLongAuthoritativeCopyWithinNarrowWidth() {
        let view = KairoStatusChip(title: "Pending KairoID Review", tone: .pending)
        let measured = size(view, dynamicType: .accessibility3)
        XCTAssertLessThanOrEqual(measured.width, 320)
        XCTAssertGreaterThan(measured.height, 30)
    }

    func testActionHasMinimumTouchTarget() {
        let measured = size(Button("View") {}.buttonStyle(KairoActionStyle()))
        XCTAssertGreaterThanOrEqual(measured.height, 44)
        XCTAssertGreaterThanOrEqual(measured.width, 44)
    }

    func testPrimaryTextContrastInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let foreground = UIColor(KairoColors.textPrimary).resolvedColor(with: traits)
            let background = UIColor(KairoColors.background).resolvedColor(with: traits)
            XCTAssertGreaterThanOrEqual(contrast(foreground, background), 7)
            let action = UIColor(KairoColors.onPrimary).resolvedColor(with: traits)
            let primary = UIColor(KairoColors.brandPrimary).resolvedColor(with: traits)
            XCTAssertGreaterThanOrEqual(contrast(action, primary), 4.5)
        }
    }

    func testRecordDetailsDoNotInventStatusOrActions() {
        let record = CareerRecordDetailPresentation(id: "qa-record", title: "Project", organization: "Candidate provided", status: nil, metadata: [])
        XCTAssertNil(record.status)
        XCTAssertNil(record.documents)
        XCTAssertNil(record.edit)
        XCTAssertNil(record.delete)
        XCTAssertNil(record.verify)
    }

    func testCanonicalStatusLanguageAndAuthoritativeOverride() {
        XCTAssertEqual(KairoStatusTone.allCases.map(\.canonicalTitle), [
            "Verified", "Pending KairoID Review", "Needs your attention", "Rejected",
            "Withdrawn", "Draft", "Candidate-provided"
        ])
        XCTAssertEqual(KairoStatusChip(tone: .pending).title, "Pending KairoID Review")
        XCTAssertEqual(KairoStatusChip(title: "Awaiting candidate consent", tone: .attention).title, "Awaiting candidate consent")
    }

    func testPageEntranceMotionHasFastSubtleTravel() throws {
        let plan = KairoMotion.pageEntrancePlan(reduceMotion: false)
        XCTAssertEqual(plan.initialOpacity, 0.96)
        XCTAssertEqual(plan.initialOffset, 3)
        XCTAssertEqual(plan.duration, KairoMotion.standardDuration)
        XCTAssertLessThanOrEqual(try XCTUnwrap(plan.duration), 0.25)
    }

    func testPageEntranceRemovesMovementForReduceMotion() {
        let plan = KairoMotion.pageEntrancePlan(reduceMotion: true)
        XCTAssertEqual(plan.initialOpacity, 1)
        XCTAssertEqual(plan.initialOffset, 0)
        XCTAssertNil(plan.duration)
    }

    private func size<V: View>(_ view: V, dynamicType: DynamicTypeSize = .large) -> CGSize {
        let controller = UIHostingController(rootView: view.environment(\.dynamicTypeSize, dynamicType))
        return controller.sizeThatFits(in: CGSize(width: 320, height: 10_000))
    }

    private func contrast(_ first: UIColor, _ second: UIColor) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ value: CGFloat) -> Double {
                let v = Double(value)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
