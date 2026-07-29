import SwiftUI
import UIKit

struct KairoTextField<Field: Hashable>: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let errorMessage: String?
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let textInputAutocapitalization: TextInputAutocapitalization
    let submitLabel: SubmitLabel
    let focus: FocusState<Field?>.Binding?
    let focusedField: Field?
    let onSubmit: (() -> Void)?

    private var isFocused: Bool {
        focus?.wrappedValue == focusedField
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
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled()
                .textContentType(textContentType)
                .keyboardType(keyboardType)
                .submitLabel(submitLabel)
                .font(KairoTypography.body)
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.medium)
                .background(KairoColors.surfaceMuted.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))
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
            return KairoColors.brandPrimary
        }

        return KairoColors.border
    }
}

extension KairoTextField where Field == Never {
    init(
        title: String,
        prompt: String,
        text: Binding<String>,
        errorMessage: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        textInputAutocapitalization: TextInputAutocapitalization = .sentences,
        submitLabel: SubmitLabel = .done,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.prompt = prompt
        _text = text
        self.errorMessage = errorMessage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.textInputAutocapitalization = textInputAutocapitalization
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
        errorMessage: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        textInputAutocapitalization: TextInputAutocapitalization = .sentences,
        submitLabel: SubmitLabel = .done,
        focus: FocusState<Field?>.Binding,
        focusedField: Field,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.prompt = prompt
        _text = text
        self.errorMessage = errorMessage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.textInputAutocapitalization = textInputAutocapitalization
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
