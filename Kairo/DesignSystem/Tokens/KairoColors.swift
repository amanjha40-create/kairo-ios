import SwiftUI

enum KairoColors {
    static let background = Color.adaptive(light: 0xFEFEFF, dark: 0x111827)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x1C2538)
    static let surfaceMuted = Color.adaptive(light: 0xF3F5F7, dark: 0x263148)
    static let border = Color.adaptive(light: 0xE6E8EC, dark: 0xFFFFFF, darkAlpha: 0.08)
    static let brandPrimary = Color.adaptive(light: 0x07122B, dark: 0x12D6C5)
    static let brandPrimaryPressed = Color.adaptive(light: 0x111D38, dark: 0x0FB9AC)
    static let accent = Color.adaptive(light: 0x12D6C5, dark: 0x12D6C5)
    static let textPrimary = Color.adaptive(light: 0x07122B, dark: 0xFAFBFC)
    static let textSecondary = Color.adaptive(light: 0x687386, dark: 0xADB7C8)
    static let success = Color.adaptive(light: 0x1E8E5A, dark: 0x43C488)
    static let warning = Color.adaptive(light: 0xD9822B, dark: 0xF1AE5F)
    static let danger = Color.adaptive(light: 0xC44536, dark: 0xF16E63)
}
