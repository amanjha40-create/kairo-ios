import SwiftUI

/// Exact geometry of the approved Android 045ed45 brand SVG, not the brand board.
enum TrustPassportMarkVariant: String, CaseIterable {
    case primary, monochromeDark, monochromeLight, small

    static func adaptive(dark: Bool, small: Bool = false) -> Self {
        dark ? .monochromeLight : (small ? .small : .primary)
    }
}

struct TrustPassportMark: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat = 44
    var variant: TrustPassportMarkVariant?
    var compact = false

    var body: some View {
        let resolved = variant ?? .adaptive(dark: colorScheme == .dark, small: compact)
        Canvas { context, bounds in
            context.scaleBy(x: bounds.width / 64, y: bounds.height / 88)
            let navy = Color(hex: 0x0F172A)
            let teal = Color(hex: 0x0EA5A4)
            let mono: Color? = resolved == .monochromeLight ? .white : (resolved == .monochromeDark ? navy : nil)
            var top = Path()
            top.move(to: CGPoint(x: 8, y: 17)); top.addLine(to: CGPoint(x: 43, y: 3))
            top.addQuadCurve(to: CGPoint(x: 51, y: 8), control: CGPoint(x: 51, y: 0))
            top.addLine(to: CGPoint(x: 51, y: 17)); top.addLine(to: CGPoint(x: 11, y: 25))
            top.addQuadCurve(to: CGPoint(x: 3, y: 22), control: CGPoint(x: 3, y: 26))
            top.addQuadCurve(to: CGPoint(x: 8, y: 17), control: CGPoint(x: 3, y: 19)); top.closeSubpath()
            context.fill(top, with: .color(mono ?? navy))
            var bottom = Path()
            bottom.move(to: CGPoint(x: 26, y: 79)); bottom.addLine(to: CGPoint(x: 55, y: 65))
            bottom.addQuadCurve(to: CGPoint(x: 60, y: 60), control: CGPoint(x: 58, y: 63))
            bottom.addLine(to: CGPoint(x: 60, y: 77))
            bottom.addQuadCurve(to: CGPoint(x: 50, y: 85), control: CGPoint(x: 60, y: 87)); bottom.closeSubpath()
            context.fill(bottom, with: .color(mono ?? navy))
            var fold = Path()
            fold.move(to: CGPoint(x: 4, y: 31)); fold.addLine(to: CGPoint(x: 42, y: 44))
            fold.addQuadCurve(to: CGPoint(x: 42, y: 49), control: CGPoint(x: 48, y: 46))
            fold.addLine(to: CGPoint(x: 4, y: 66)); fold.closeSubpath()
            if let mono { context.fill(fold, with: .color(mono)) }
            else if resolved == .small { context.fill(fold, with: .color(navy)) }
            else { context.fill(fold, with: .linearGradient(Gradient(colors: [teal, navy]), startPoint: CGPoint(x: 5, y: 29), endPoint: CGPoint(x: 53, y: 51))) }
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: 10, y: 29)); ribbon.addLine(to: CGPoint(x: 53, y: 20))
            ribbon.addQuadCurve(to: CGPoint(x: 60, y: 28), control: CGPoint(x: 60, y: 19))
            ribbon.addLine(to: CGPoint(x: 60, y: 50))
            ribbon.addQuadCurve(to: CGPoint(x: 52, y: 63), control: CGPoint(x: 60, y: 59))
            ribbon.addLine(to: CGPoint(x: 18, y: 79))
            ribbon.addQuadCurve(to: CGPoint(x: 4, y: 70), control: CGPoint(x: 6, y: 77))
            ribbon.addQuadCurve(to: CGPoint(x: 11, y: 61), control: CGPoint(x: 3, y: 65))
            ribbon.addLine(to: CGPoint(x: 47, y: 45))
            ribbon.addQuadCurve(to: CGPoint(x: 47, y: 41), control: CGPoint(x: 51, y: 43)); ribbon.closeSubpath()
            context.fill(ribbon, with: .color(mono ?? teal))
        }
        .frame(width: size * 64 / 88, height: size)
        .accessibilityHidden(true)
    }
}

/// Deterministic alpha extraction preserves the founder master, TM and spacing.
struct KairoIDBrandView: View {
    @Environment(\.colorScheme) private var colorScheme
    var width: CGFloat = 180
    var body: some View {
        Image("KairoIDMaster").resizable().renderingMode(.original)
            .scaledToFit().frame(maxWidth: width)
            // A soft edge shadow supports navy on dark surfaces without tinting
            // the artwork or placing an opaque rectangle behind it.
            .shadow(color: colorScheme == .dark ? .white.opacity(0.30) : .clear,
                    radius: 0.75, x: 0, y: 0)
            .accessibilityHidden(true)
    }
}

/// External-service artwork must never inherit tint or merge with product marks.
struct DigiLockerBrandView: View {
    var body: some View {
        Image("DigiLockerOfficial").resizable().renderingMode(.original)
            .scaledToFit().frame(width: 132)
            .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

enum ProductGuidanceTopic: String {
    case career, passport, digiLocker, permanentAddress, invitation
    var title: String {
        switch self {
        case .career: "Your career records"
        case .passport: "Share your Passport"
        case .digiLocker: "Verify with DigiLocker"
        case .permanentAddress: "Check your permanent address"
        case .invitation: "Review your invitation"
        }
    }
    var message: String {
        switch self {
        case .career: "Keep your work and education details together. Open a record to review its details, verification status and available actions."
        case .passport: "Review included categories and expiry before creating a share link. Employment sharing applies to the category, not individual jobs. Sharing does not verify a record."
        case .digiLocker: "Connect securely, choose available documents and give consent to verify. Connecting alone does not verify them."
        case .permanentAddress: "This private check does not change your Trust Score. Save your address, then follow the document and location steps. Location is checked only when you start a check."
        case .invitation: "Review who invited you before accepting. Use the intended account. Linking an organization does not create verification requests or mean verification is complete."
        }
    }
}

struct ProductGuidanceView: View {
    let topic: ProductGuidanceTopic
    var body: some View {
        DisclosureGroup(topic.title) {
            Text(topic.message).font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(KairoTypography.bodyStrong)
        .accessibilityIdentifier("guidance.\(topic.rawValue)")
    }
}
