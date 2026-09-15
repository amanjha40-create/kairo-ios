import SwiftUI

/// Keep scrolling tab content out of the system status-bar's visual region.
/// Geometry remains inside the safe area so its inset is the native window inset,
/// not a device-specific estimate. The opaque overlay does not intercept gestures.
struct KairoStatusBarProtection: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geometry in
                KairoColors.background
                    .frame(height: geometry.safeAreaInsets.top)
                    .offset(y: -geometry.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
