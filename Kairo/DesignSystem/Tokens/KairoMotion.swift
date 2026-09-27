import CoreGraphics
import SwiftUI

/// A small, shared motion vocabulary for product surfaces. Motion remains
/// decorative: Reduce Motion and deterministic UI tests render the end state.
enum KairoMotion {
    static let fastDuration: TimeInterval = 0.16
    static let standardDuration: TimeInterval = 0.24
    static let emphasisDuration: TimeInterval = 0.42

    struct PageEntrancePlan: Equatable, Sendable {
        let initialOpacity: Double
        let initialOffset: CGFloat
        let duration: TimeInterval?
    }

    static func pageEntrancePlan(reduceMotion: Bool) -> PageEntrancePlan {
        if reduceMotion {
            return PageEntrancePlan(initialOpacity: 1, initialOffset: 0, duration: nil)
        }

        return PageEntrancePlan(
            initialOpacity: 0.96,
            initialOffset: 6,
            duration: standardDuration
        )
    }
}

private struct KairoPageEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var isVisible = false

    private var plan: KairoMotion.PageEntrancePlan {
        let deterministicUITest = UITestLaunchConfiguration.current().disablesAnimations
        return KairoMotion.pageEntrancePlan(
            reduceMotion: accessibilityReduceMotion || deterministicUITest
        )
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : plan.initialOpacity)
            .offset(y: isVisible ? 0 : plan.initialOffset)
            .onAppear {
                guard !isVisible else { return }
                if let duration = plan.duration {
                    withAnimation(.easeOut(duration: duration)) {
                        isVisible = true
                    }
                } else {
                    isVisible = true
                }
            }
    }
}

extension View {
    func kairoPageEntrance() -> some View {
        modifier(KairoPageEntranceModifier())
    }
}
