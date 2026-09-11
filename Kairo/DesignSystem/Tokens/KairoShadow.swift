import SwiftUI

struct ShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum KairoShadow {
    static let card = ShadowToken(
        color: Color.black.opacity(0.055),
        radius: 12,
        x: 0,
        y: 6
    )
}

extension View {
    func kairoShadow(_ token: ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
