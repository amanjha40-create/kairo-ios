import SwiftUI

enum KairoTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title, design: .rounded).weight(.bold)
    static let title2 = Font.system(.title2, design: .default).weight(.semibold)
    static let headline = Font.system(.headline, design: .default).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let bodyStrong = Font.system(.body, design: .default).weight(.medium)
    static let footnote = Font.system(.footnote, design: .default)
    static let caption = Font.system(.caption, design: .rounded).weight(.semibold)
}
