import SwiftUI

struct ShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum KairoShadow {
    static let card = ShadowToken(
        color: Color.black.opacity(0.08),
        radius: 18,
        x: 0,
        y: 10
    )
}

extension View {
    func kairoShadow(_ token: ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
