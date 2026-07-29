import SwiftUI
import UIKit

struct KairoOTPField<Field: Hashable>: View {
    let title: String
    let prompt: String
    let length: Int
    @Binding var code: String
    let errorMessage: String?
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    let accessibilityHint: String?
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

            ZStack {
                HStack(spacing: KairoSpacing.small) {
                    ForEach(0..<length, id: \.self) { index in
                        otpCell(at: index)
                    }
                }
                .accessibilityHidden(true)

                TextField(prompt, text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .opacity(0.015)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier(accessibilityIdentifier ?? title)
                    .accessibilityLabel(accessibilityLabel ?? title)
                    .accessibilityHint(resolvedAccessibilityHint)
                    .accessibilityValue(accessibilityValue)
                    .kairoFocused(focus, equals: focusedField)
                    .onChange(of: code) { _, newValue in
                        let sanitizedValue = ContactVerificationState.sanitizedOTPCode(
                            newValue,
                            length: length
                        )
                        if sanitizedValue != newValue {
                            code = sanitizedValue
                        }
                    }
                    .onSubmit {
                        onSubmit?()
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func otpCell(at index: Int) -> some View {
        let digit = character(at: index)
        let isActive = isFocused && code.count == index
        let isFilled = digit != nil

        return RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
            .fill(KairoColors.surfaceMuted.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    .stroke(borderColor(isActive: isActive, isFilled: isFilled), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, minHeight: 56)
            .overlay {
                Text(digit.map(String.init) ?? "")
                    .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(KairoColors.textPrimary)
            }
    }

    private func character(at index: Int) -> Character? {
        guard index < code.count else {
            return nil
        }

        return Array(code)[index]
    }

    private func borderColor(isActive: Bool, isFilled: Bool) -> Color {
        if errorMessage != nil {
            return KairoColors.danger
        }

        if isActive {
            return KairoColors.brandPrimary
        }

        return isFilled ? KairoColors.textPrimary.opacity(0.16) : KairoColors.border
    }

    private var accessibilityValue: String {
        "\(code.count) of \(length) digits entered"
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

extension KairoOTPField where Field == Never {
    init(
        title: String,
        prompt: String,
        length: Int = 6,
        code: Binding<String>,
        errorMessage: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.prompt = prompt
        self.length = length
        _code = code
        self.errorMessage = errorMessage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.focus = nil
        self.focusedField = nil
        self.onSubmit = onSubmit
    }
}

extension KairoOTPField {
    init(
        title: String,
        prompt: String,
        length: Int = 6,
        code: Binding<String>,
        errorMessage: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        focus: FocusState<Field?>.Binding,
        focusedField: Field,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.prompt = prompt
        self.length = length
        _code = code
        self.errorMessage = errorMessage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.focus = focus
        self.focusedField = focusedField
        self.onSubmit = onSubmit
    }
}
