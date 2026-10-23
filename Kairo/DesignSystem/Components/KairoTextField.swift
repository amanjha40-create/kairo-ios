import SwiftUI
import UIKit

struct KairoTextField<Field: Hashable>: View {
    let title: String
    let titleColor: Color
    let titleFont: Font
    let prompt: String
    @Binding var text: String
    let errorMessage: String?
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let textInputAutocapitalization: TextInputAutocapitalization
    let isSecure: Bool
    let submitLabel: SubmitLabel
    let focus: FocusState<Field?>.Binding?
    let focusedField: Field?
    let onSubmit: (() -> Void)?

    private var isFocused: Bool {
        guard let focus, let focusedField else { return false }
        return focus.wrappedValue == focusedField
    }

    private var resolvedAccessibilityHint: String {
        [accessibilityHint, errorMessage]
            .compactMap { value in
                guard let value, !value.isEmpty else {
                    return nil
                }

                return value
            }
            .joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)

            fieldInput
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled()
                .textContentType(textContentType)
                .keyboardType(keyboardType)
                .submitLabel(submitLabel)
                .font(KairoTypography.body)
                .padding(.horizontal, 14)
                .padding(.vertical, KairoSpacing.xSmall)
                .frame(minHeight: KairoControlMetrics.buttonHeight)
                .background(KairoColors.fieldSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: KairoControlMetrics.fieldRadius, style: .continuous)
                        .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: KairoControlMetrics.fieldRadius, style: .continuous))
                .accessibilityIdentifier(accessibilityIdentifier ?? title)
                .accessibilityLabel(accessibilityLabel ?? title)
                .accessibilityHint(resolvedAccessibilityHint)
                .kairoFocused(focus, equals: focusedField)
                .onSubmit {
                    onSubmit?()
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return KairoColors.danger
        }

        if isFocused {
            return KairoColors.teal
        }

        return KairoColors.fieldBorder
    }

    @ViewBuilder
    private var fieldInput: some View {
        if isSecure {
            SecureField(prompt, text: $text)
        } else {
            TextField(prompt, text: $text)
        }
    }
}

extension KairoTextField where Field == Never {
    init(
        title: String,
        prompt: String,
        text: Binding<String>,
        titleColor: Color = KairoColors.textSecondary,
        titleFont: Font = .system(.caption2, design: .default).weight(.semibold),
        errorMessage: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        textInputAutocapitalization: TextInputAutocapitalization = .sentences,
        isSecure: Bool = false,
        submitLabel: SubmitLabel = .done,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.prompt = prompt
        _text = text
        self.errorMessage = errorMessage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.textInputAutocapitalization = textInputAutocapitalization
        self.isSecure = isSecure
        self.submitLabel = submitLabel
        self.focus = nil
        self.focusedField = nil
        self.onSubmit = onSubmit
    }
}

extension KairoTextField {
    init(
        title: String,
        prompt: String,
        text: Binding<String>,
        titleColor: Color = KairoColors.textSecondary,
        titleFont: Font = .system(.caption2, design: .default).weight(.semibold),
        errorMessage: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        textInputAutocapitalization: TextInputAutocapitalization = .sentences,
        isSecure: Bool = false,
        submitLabel: SubmitLabel = .done,
        focus: FocusState<Field?>.Binding,
        focusedField: Field,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.prompt = prompt
        _text = text
        self.errorMessage = errorMessage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.textInputAutocapitalization = textInputAutocapitalization
        self.isSecure = isSecure
        self.submitLabel = submitLabel
        self.focus = focus
        self.focusedField = focusedField
        self.onSubmit = onSubmit
    }
}

private extension View {
    @ViewBuilder
    func kairoFocused<Field: Hashable>(
        _ binding: FocusState<Field?>.Binding?,
        equals value: Field?
    ) -> some View {
        if let binding, let value {
            self.focused(binding, equals: value)
        } else {
            self
        }
    }
}
