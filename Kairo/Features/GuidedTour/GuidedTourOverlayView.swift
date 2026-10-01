import SwiftUI
import UIKit

nonisolated enum GuidedTourCoachPlacement: Equatable, Sendable {
    case above
    case below
    case centered
}

nonisolated enum GuidedTourLayout {
    static func spotlight(target: CGRect, step: GuidedTourStep, viewport: CGRect, homeVisibleFrame: CGRect) -> CGRect {
        let boundary = (step == .trustScore || step == .passport) ? homeVisibleFrame : viewport
        return target.insetBy(dx: -5, dy: -5).intersection(boundary.insetBy(dx: 4, dy: 4))
    }

    static func minimumCoachHeight(accessibilitySize: Bool, viewport: CGRect) -> CGFloat {
        accessibilitySize ? min(500, max(1, viewport.height - 24)) : 190
    }

    static func placement(
        target: CGRect,
        viewport: CGRect,
        minimumCoachHeight: CGFloat = 190,
        gap: CGFloat = 14,
        margin: CGFloat = 12
    ) -> GuidedTourCoachPlacement {
        let above = target.minY - viewport.minY - gap - margin
        let below = viewport.maxY - target.maxY - gap - margin
        if below >= minimumCoachHeight { return .below }
        if above >= minimumCoachHeight { return .above }
        return .centered
    }
}

struct GuidedTourOverlayView: View {
    let step: GuidedTourStep
    let targetFrame: CGRect
    let homeVisibleFrame: CGRect
    var targetWindowFrame: CGRect = .zero
    let nextAction: () -> Void
    let backAction: () -> Void
    let skipAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var titleFocused: Bool
    @State private var renderedSpotlightFrame: CGRect = .zero

    // Opt-in geometry probe for XCTest only; absent from normal and VoiceOver QA.
    private var exposesGeometryForTesting: Bool {
        UITestLaunchConfiguration.current().isEnabled &&
        ProcessInfo.processInfo.environment["KAIRO_UI_TEST_TOUR_GEOMETRY"] == "1"
    }

    var body: some View {
        GeometryReader { proxy in
            let viewport = CGRect(origin: .zero, size: proxy.size)
            let spotlight = GuidedTourLayout.spotlight(
                target: targetFrame, step: step, viewport: viewport, homeVisibleFrame: homeVisibleFrame
            )
            let placement = GuidedTourLayout.placement(
                target: spotlight, viewport: homeVisibleFrame,
                minimumCoachHeight: GuidedTourLayout.minimumCoachHeight(
                    accessibilitySize: dynamicTypeSize.isAccessibilitySize, viewport: homeVisibleFrame
                )
            )

            ZStack {
                GuidedTourSpotlightScrim(spotlight: spotlight)
                    .fill(Color.black.opacity(0.66), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                    .stroke(KairoColors.accent, lineWidth: 3)
                    .frame(width: spotlight.width, height: spotlight.height)
                    .background {
                        if exposesGeometryForTesting {
                            GeometryReader { measurement in
                                Color.clear
                                    .onAppear { renderedSpotlightFrame = measurement.frame(in: .global) }
                                    .onChange(of: measurement.frame(in: .global)) { _, frame in
                                        renderedSpotlightFrame = frame
                                    }
                            }
                        }
                    }
                    .position(x: spotlight.midX, y: spotlight.midY)
                    .accessibilityHidden(true)

                coachRegion(placement: placement, spotlight: spotlight, viewport: homeVisibleFrame)
            }
            .contentShape(Rectangle())
            .accessibilityIdentifier(KairoAccessibilityID.guidedTourOverlay)
        }
        .transition(reduceMotion ? .identity : .opacity)
        .onAppear { focusTitle() }
        .onChange(of: step) { _, _ in focusTitle() }
    }

    @ViewBuilder
    private func coachRegion(
        placement: GuidedTourCoachPlacement,
        spotlight: CGRect,
        viewport: CGRect
    ) -> some View {
        let gap: CGFloat = 14
        let margin: CGFloat = 12

        switch placement {
        case .above:
            let height = max(1, min(viewport.maxY, spotlight.minY - gap) - viewport.minY - margin)
            coachCard(maxHeight: height)
                .frame(width: viewport.width - margin * 2, height: height, alignment: .bottom)
                .position(x: viewport.midX, y: viewport.minY + margin + height / 2)
        case .below:
            let top = spotlight.maxY + gap
            let height = max(1, viewport.maxY - top - margin)
            coachCard(maxHeight: height)
                .frame(width: viewport.width - margin * 2, height: height, alignment: .top)
                .position(x: viewport.midX, y: top + height / 2)
        case .centered:
            coachCard(maxHeight: max(1, viewport.height - margin * 2))
                .frame(width: viewport.width - margin * 2, height: viewport.height - margin * 2)
                .position(x: viewport.midX, y: viewport.midY)
        }
    }

    private func coachCard(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: true) {
                    coachCopy
                }
                .accessibilityIdentifier("candidate.guidedTour.scrollableCopy")
            } else {
                coachCopy
            }

            Divider()

            actionArea
                .padding(.horizontal, KairoSpacing.small)
                .padding(.vertical, KairoSpacing.xSmall)
        }
        .frame(maxWidth: 360)
        .frame(height: min(maxHeight, dynamicTypeSize.isAccessibilitySize ? 500 : 270))
        .background(KairoColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                .stroke(KairoColors.border, lineWidth: 1)
        )
        .kairoShadow(KairoShadow.card)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier(KairoAccessibilityID.guidedTourCoach)
    }

    private var coachCopy: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text("Explore KairoID · \(step.progressText)")
                .font(KairoTypography.sectionEyebrow)
                .foregroundStyle(KairoColors.brandPrimary)
                .textCase(.uppercase)
                .accessibilityLabel("Explore KairoID, step \(step.rawValue + 1) of \(GuidedTourStep.allCases.count)")
                .accessibilityIdentifier(KairoAccessibilityID.guidedTourProgress)

            Text(step.title)
                .font(KairoTypography.screenTitle)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
                .accessibilityIdentifier(KairoAccessibilityID.guidedTourTitle)
                .accessibilityValue(exposesGeometryForTesting
                    ? NSCoder.string(for: targetWindowFrame) + "|" + NSCoder.string(for: renderedSpotlightFrame)
                        + "|" + NSCoder.string(for: homeVisibleFrame.offsetBy(
                            dx: targetWindowFrame.minX - targetFrame.minX,
                            dy: targetWindowFrame.minY - targetFrame.minY
                        )) : "")

            Text(step.body)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(KairoAccessibilityID.guidedTourBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KairoSpacing.medium)
        .padding(.top, KairoSpacing.medium)
        .padding(.bottom, KairoSpacing.small)
    }

    private var actionArea: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: KairoSpacing.xSmall) {
                    primaryButton
                        .frame(maxWidth: .infinity)
                    if step.previous != nil {
                        backButton
                            .frame(maxWidth: .infinity)
                    }
                    skipButton
                        .frame(maxWidth: .infinity)
                }
            } else {
                standardActionArea
            }
        }
    }

    private var standardActionArea: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: KairoSpacing.xSmall) {
                skipButton
                Spacer(minLength: KairoSpacing.xSmall)
                navigationActions
            }

            VStack(spacing: KairoSpacing.xSmall) {
                navigationActions
                    .frame(maxWidth: .infinity, alignment: .trailing)
                skipButton
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var skipButton: some View {
        Button("Skip tour", action: skipAction)
            .font(KairoTypography.action)
            .foregroundStyle(KairoColors.textSecondary)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint("Ends the guided tour and does not show it again for this account")
            .accessibilityIdentifier(KairoAccessibilityID.guidedTourSkip)
    }

    private var navigationActions: some View {
        HStack(spacing: KairoSpacing.xSmall) {
            if step.previous != nil {
                backButton
            }

            primaryButton
        }
    }

    private var backButton: some View {
        Button(action: backAction) {
            Label("Back", systemImage: "arrow.left")
                .frame(minWidth: 44, minHeight: 44)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .font(KairoTypography.action)
        .foregroundStyle(KairoColors.textPrimary)
        .accessibilityIdentifier(KairoAccessibilityID.guidedTourBack)
    }

    private var primaryButton: some View {
        Button(action: nextAction) {
            Label(
                step.primaryActionTitle,
                systemImage: step.next == nil ? "checkmark" : "arrow.right"
            )
            .labelStyle(GuidedTourTrailingIconLabelStyle())
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: 76, minHeight: 44)
            .padding(.horizontal, KairoSpacing.small)
            .foregroundStyle(KairoColors.onPrimary)
            .background(KairoColors.brandPrimary, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small))
        }
        .buttonStyle(.plain)
        .font(KairoTypography.action)
        .accessibilityIdentifier(step.next == nil
            ? KairoAccessibilityID.guidedTourDone
            : KairoAccessibilityID.guidedTourNext)
    }

    private func focusTitle() {
        titleFocused = false
        DispatchQueue.main.async {
            titleFocused = true
            UIAccessibility.post(
                notification: .screenChanged,
                argument: "\(step.title). \(step.progressText). \(step.body)"
            )
        }
    }
}

private struct GuidedTourSpotlightScrim: Shape {
    let spotlight: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: spotlight,
            cornerSize: CGSize(width: KairoCornerRadius.large, height: KairoCornerRadius.large)
        )
        return path
    }
}

private struct GuidedTourTrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: KairoSpacing.xxSmall) {
            configuration.title
            configuration.icon
        }
    }
}
