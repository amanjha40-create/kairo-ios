import SwiftUI

enum KairoColors {
    static let background = Color.adaptive(light: 0xF3F6F9, dark: 0x0B1220)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x141F32)
    static let surfaceMuted = Color.adaptive(light: 0xEAF0F4, dark: 0x202D42)
    static let surfaceElevated = Color.adaptive(light: 0xFFFFFF, dark: 0x26344A)
    static let border = Color.adaptive(light: 0xD4DEE7, dark: 0x39465A)
    // Opt-in brand hierarchy, not a replacement for semantic status colours.
    static let surfaceBrand = Color.adaptive(light: 0xE8F5F3, dark: 0x112F36)
    static let borderBrand = Color.adaptive(light: 0xB4D8D4, dark: 0x345C63)
    static let borderSubtle = Color.adaptive(light: 0xE0E6EE, dark: 0x2D3B50)
    static let fieldSurface = Color.adaptive(light: 0xF8FAFC, dark: 0x111D2E)
    static let fieldBorder = Color.adaptive(light: 0x8290A2, dark: 0x72849C)
    static let info = Color.adaptive(light: 0x245C88, dark: 0x89C7F6)
    static let identity = Color.adaptive(light: 0x5B4A97, dark: 0xC3B7F1)
    static let onDanger = Color.adaptive(light: 0xFFFFFF, dark: 0x07122B)
    static let navy = Color(hex: 0x07122B)
    static let trustNavy = Color(hex: 0x020B20)
    static let brandPrimary = Color.adaptive(light: 0x07122B, dark: 0x12D6C5)
    static let brandPrimaryPressed = Color.adaptive(light: 0x111D38, dark: 0x0FB9AC)
    static let accent = Color.adaptive(light: 0x12D6C5, dark: 0x12D6C5)
    static let teal = Color.adaptive(light: 0x00777A, dark: 0x54DFD3)
    static let onPrimary = Color.adaptive(light: 0xFFFFFF, dark: 0x07122B)
    static let textPrimary = Color.adaptive(light: 0x07122B, dark: 0xFAFBFC)
    static let textSecondary = Color.adaptive(light: 0x536173, dark: 0xB5C0D1)
    static let textMuted = Color.adaptive(light: 0x687386, dark: 0x9CAAC0)
    static let success = Color.adaptive(light: 0x187348, dark: 0x65D6A0)
    static let warning = Color.adaptive(light: 0xD9822B, dark: 0xF1AE5F)
    static let danger = Color.adaptive(light: 0xBA3E32, dark: 0xF16E63)
    static let pending = Color.adaptive(light: 0x875A13, dark: 0xF3C26F)
    static let attention = Color.adaptive(light: 0xA44718, dark: 0xFFB28A)
    static let rejected = danger
    static let draft = textSecondary
    static let candidateProvided = info
}

/// Visual roles only. Callers still own all status, grouping and eligibility decisions.
enum KairoSemanticAccent: CaseIterable {
    case neutral, brand, info, success, pending, attention, danger, identity

    var foreground: Color {
        switch self {
        case .neutral: KairoColors.textSecondary
        case .brand: KairoColors.teal
        case .info: KairoColors.info
        case .success: KairoColors.success
        case .pending: KairoColors.pending
        case .attention: KairoColors.attention
        case .danger: KairoColors.danger
        case .identity: KairoColors.identity
        }
    }

    var surface: Color {
        switch self {
        case .neutral: KairoColors.surface
        case .brand: KairoColors.surfaceBrand
        case .info: .adaptive(light: 0xEEF4FB, dark: 0x172B43)
        case .success: .adaptive(light: 0xECF6EF, dark: 0x142F29)
        case .pending: .adaptive(light: 0xFBF3E4, dark: 0x332B1D)
        case .attention: .adaptive(light: 0xFFF2E9, dark: 0x342720)
        case .danger: .adaptive(light: 0xFFF0EF, dark: 0x35242B)
        case .identity: .adaptive(light: 0xF2F0FA, dark: 0x25243C)
        }
    }

    var border: Color { self == .neutral ? KairoColors.borderSubtle : foreground.opacity(0.22) }
}
