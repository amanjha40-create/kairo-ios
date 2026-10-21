import SwiftUI

enum KairoColors {
    static let background = Color.adaptive(light: 0xF3F6F9, dark: 0x0B1220)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x141F32)
    static let surfaceMuted = Color.adaptive(light: 0xEAF0F4, dark: 0x202D42)
    static let surfaceElevated = Color.adaptive(light: 0xFFFFFF, dark: 0x26344A)
    static let border = Color.adaptive(light: 0xD4DEE7, dark: 0x39465A)
    // Opt-in brand hierarchy, not a replacement for semantic status colours.
    static let surfaceBrand = Color.adaptive(light: 0xE8F5F3, dark: 0x141F32)
    static let borderBrand = Color.adaptive(light: 0xB4D8D4, dark: 0x39465A)
    static let navy = Color(hex: 0x07122B)
    static let trustNavy = Color(hex: 0x020B20)
    static let brandPrimary = Color.adaptive(light: 0x07122B, dark: 0x12D6C5)
    static let brandPrimaryPressed = Color.adaptive(light: 0x111D38, dark: 0x0FB9AC)
    static let accent = Color.adaptive(light: 0x12D6C5, dark: 0x12D6C5)
    static let teal = Color.adaptive(light: 0x007F82, dark: 0x54DFD3)
    static let onPrimary = Color.adaptive(light: 0xFFFFFF, dark: 0x07122B)
    static let textPrimary = Color.adaptive(light: 0x07122B, dark: 0xFAFBFC)
    static let textSecondary = Color.adaptive(light: 0x536173, dark: 0xB5C0D1)
    static let textMuted = Color.adaptive(light: 0x687386, dark: 0x9CAAC0)
    static let success = Color.adaptive(light: 0x1E8E5A, dark: 0x43C488)
    static let warning = Color.adaptive(light: 0xD9822B, dark: 0xF1AE5F)
    static let danger = Color.adaptive(light: 0xC44536, dark: 0xF16E63)
    static let pending = Color.adaptive(light: 0x875A13, dark: 0xF3C26F)
    static let attention = Color.adaptive(light: 0xA44718, dark: 0xFFB28A)
    static let rejected = danger
    static let draft = textSecondary
    static let candidateProvided = Color.adaptive(light: 0x245C88, dark: 0x89C7F6)
}
