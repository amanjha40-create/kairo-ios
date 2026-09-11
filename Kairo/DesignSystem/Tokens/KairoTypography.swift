import SwiftUI

enum KairoTypography {
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let screenTitle = Font.system(.title2, design: .default).weight(.bold)
    static let title = Font.system(.title, design: .default).weight(.bold)
    static let title2 = Font.system(.title2, design: .default).weight(.semibold)
    static let headline = Font.system(.headline, design: .default).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let bodyStrong = Font.system(.body, design: .default).weight(.medium)
    static let footnote = Font.system(.footnote, design: .default)
    static let caption = Font.system(.caption, design: .default).weight(.semibold)
    static let sectionEyebrow = Font.system(.caption2, design: .default).weight(.semibold)
}
