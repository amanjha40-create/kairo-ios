import SwiftUI

enum PasswordResetPhase: Equatable {
    case request
    case checkEmail
    case reset
    case success
}

struct PasswordResetFlowState: Equatable {
    var phase: PasswordResetPhase = .request
    var emailAddress: String
    var token = ""
    var newPassword = ""
    var confirmPassword = ""

    init(emailAddress: String = "") {
        self.emailAddress = emailAddress
    }

    mutating func showCheckEmail() {
        phase = .checkEmail
    }

    mutating func showResetForm() {
        phase = .reset
    }

    mutating func showSuccess() {
        clearSensitiveFields()
        phase = .success
    }

    mutating func requestNewReset() {
        clearSensitiveFields()
        phase = .request
    }

    mutating func clearSensitiveFields() {
        token = ""
        newPassword = ""
        confirmPassword = ""
    }
}

enum PasswordResetValidation {
    static let passwordLengthRange = 12 ... 128
    static let tokenLengthRange = 20 ... 512

    static func emailMessage(_ value: String) -> String? {
        let draft = CreateAccountDraft(
            firstName: "Placeholder",
            lastName: "Placeholder",
            emailAddress: value,
            mobileNumber: "9876543210"
        )
        return CreateAccountValidation.errorMessage(for: .emailAddress, in: draft)
    }

    static func tokenMessage(_ value: String) -> String? {
        if value.isEmpty {
            return "Enter the reset token from your email."
        }

        guard tokenLengthRange.contains(value.count) else {
            return "Enter the complete reset token from your email."
        }

        return nil
    }

    static func newPasswordMessage(_ value: String) -> String? {
        if value.count < passwordLengthRange.lowerBound {
            return "Password must be at least 12 characters."
        }

        if value.count > passwordLengthRange.upperBound {
            return "Password must be no more than 128 characters."
        }

        return nil
    }

    static func confirmationMessage(password: String, confirmation: String) -> String? {
        if confirmation.isEmpty {
            return "Confirm your new password."
        }

        return password == confirmation ? nil : "Passwords do not match."
    }
}

enum PasswordResetRequestContext: Equatable {
    case requestEmail
    case submitReset
}

struct PasswordResetErrorPresentation: Equatable {
    let message: String
    let offersNewReset: Bool

    static func resolve(
        _ error: Error,
        context: PasswordResetRequestContext
    ) -> PasswordResetErrorPresentation {
        guard let networkError = error as? NetworkError else {
            return PasswordResetErrorPresentation(
                message: "Something went wrong. Please try again.",
                offersNewReset: false
            )
        }

        switch networkError {
        case .api(let apiError):
            switch apiError.code {
            case .unauthorized where context == .submitReset:
                return PasswordResetErrorPresentation(
                    message: "This reset token is invalid, expired, or already used.",
                    offersNewReset: true
                )
            case .validationError:
                return PasswordResetErrorPresentation(
                    message: validationMessage(from: apiError, context: context),
                    offersNewReset: false
                )
            case .rateLimited:
                return PasswordResetErrorPresentation(
                    message: "Too many reset attempts. Please wait and try again.",
                    offersNewReset: false
                )
            case .serviceUnavailable, .internalError:
                return PasswordResetErrorPresentation(
                    message: "Kairo is temporarily unavailable. Please try again.",
                    offersNewReset: false
                )
            default:
                return PasswordResetErrorPresentation(
                    message: apiError.message,
                    offersNewReset: false
                )
            }
        case .transport:
            return PasswordResetErrorPresentation(
                message: "Kairo couldn't reach the network. Check your connection and try again.",
                offersNewReset: false
            )
        case .invalidResponse:
            return PasswordResetErrorPresentation(
                message: "Kairo received an unexpected response. Please try again.",
                offersNewReset: false
            )
        case .invalidURL:
            return PasswordResetErrorPresentation(
                message: "Kairo's API configuration is invalid.",
                offersNewReset: false
            )
        case .unavailableInDemoMode:
            return PasswordResetErrorPresentation(
                message: "Demo Mode keeps password reset local only.",
                offersNewReset: false
            )
        }
    }

    private static func validationMessage(
        from error: APIError,
        context: PasswordResetRequestContext
    ) -> String {
        let preferredFields: [String] = switch context {
        case .requestEmail:
            ["email"]
        case .submitReset:
            ["token", "new_password", "confirm_password"]
        }

        for field in preferredFields {
            if let message = error.fieldErrors[field]?.first {
                return message
            }
        }

        return error.globalErrors.first ?? error.message
    }
}

struct PasswordResetFlowView: View {
    private enum FocusField: Hashable {
        case email
        case token
        case newPassword
        case confirmPassword
    }

    @Environment(\.authService) private var authService
    @EnvironmentObject private var router: AppRouter
    @FocusState private var focusedField: FocusField?
    @State private var state: PasswordResetFlowState
    @State private var touchedFields: Set<FocusField> = []
    @State private var isSubmitting = false
    @State private var submissionErrorMessage: String?
    @State private var offersNewReset = false

    init(initialEmail: String = "") {
        _state = State(initialValue: PasswordResetFlowState(emailAddress: initialEmail))
    }

    var body: some View {
        Group {
            switch state.phase {
            case .request:
                requestScreen
            case .checkEmail:
                checkEmailScreen
            case .reset:
                resetScreen
            case .success:
                successScreen
            }
        }
        .onDisappear {
            state.clearSensitiveFields()
        }
    }

    private var requestScreen: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Account recovery",
            title: "Reset your password",
            subtitle: "Enter the email linked to your Kairo account. We’ll send you a password-reset email.",
            titleAccessibilityIdentifier: KairoAccessibilityID.passwordResetRequestTitle
        ) {
            EmptyView()
        } content: {
            KairoCard {
                KairoTextField(
                    title: "Email Address",
                    prompt: "name@example.com",
                    text: $state.emailAddress,
                    errorMessage: requestEmailErrorMessage,
                    accessibilityIdentifier: KairoAccessibilityID.passwordResetEmail,
                    accessibilityLabel: "Email address for password reset",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    textInputAutocapitalization: .never,
                    submitLabel: .go,
                    focus: $focusedField,
                    focusedField: .email,
                    onSubmit: requestResetEmail
                )
            }
        } actions: {
            VStack(spacing: KairoSpacing.medium) {
                KairoPrimaryButton(
                    title: "Send reset email",
                    isLoading: isSubmitting,
                    accessibilityIdentifier: KairoAccessibilityID.passwordResetSendEmail,
                    action: requestResetEmail
                )
                .disabled(!isRequestFormValid || isSubmitting)

                KairoSecondaryButton(
                    title: "Back to login",
                    accessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                    action: returnToLogin
                )
                .disabled(isSubmitting)

                errorBlock
            }
        }
        .onChange(of: state.emailAddress) { _, _ in clearSubmissionError() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.passwordResetRequestScreen)
    }

    private var checkEmailScreen: some View {
        OnboardingScreenLayout(
            layoutMode: .choice,
            eyebrow: "Account recovery",
            title: "Check your email",
            subtitle: "If an account exists for that email, a password-reset email has been sent.",
            titleAccessibilityIdentifier: KairoAccessibilityID.passwordResetCheckEmailSuccess
        ) {
            statusIcon(systemName: "envelope.badge.shield.half.filled")
        } content: {
            KairoCard {
                Text("Open the email, then return here with the one-time reset token. The token expires after 30 minutes and can be used once.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            VStack(spacing: KairoSpacing.medium) {
                KairoPrimaryButton(
                    title: "Enter reset token",
                    accessibilityIdentifier: KairoAccessibilityID.passwordResetEnterToken,
                    action: showResetForm
                )

                KairoSecondaryButton(
                    title: "Back to login",
                    accessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                    action: returnToLogin
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.passwordResetCheckEmailScreen)
    }

    private var resetScreen: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Account recovery",
            title: "Reset password",
            subtitle: "Enter the one-time token from your email and choose a new password.",
            titleAccessibilityIdentifier: KairoAccessibilityID.passwordResetTokenScreen
        ) {
            EmptyView()
        } content: {
            VStack(spacing: KairoSpacing.medium) {
                KairoCard {
                    VStack(spacing: KairoSpacing.medium) {
                        KairoTextField(
                            title: "Reset token",
                            prompt: "Enter your one-time token",
                            text: $state.token,
                            errorMessage: resetTokenErrorMessage,
                            accessibilityIdentifier: KairoAccessibilityID.passwordResetToken,
                            accessibilityLabel: "One-time reset token",
                            textContentType: .oneTimeCode,
                            textInputAutocapitalization: .never,
                            isSecure: true,
                            submitLabel: .next,
                            focus: $focusedField,
                            focusedField: .token,
                            onSubmit: {
                                touchedFields.insert(.token)
                                focusedField = .newPassword
                            }
                        )

                        KairoTextField(
                            title: "New password",
                            prompt: "Enter your new password",
                            text: $state.newPassword,
                            errorMessage: newPasswordErrorMessage,
                            accessibilityIdentifier: KairoAccessibilityID.passwordResetNewPassword,
                            accessibilityLabel: "New password",
                            accessibilityHint: "Use 12 to 128 characters.",
                            textContentType: .newPassword,
                            textInputAutocapitalization: .never,
                            isSecure: true,
                            submitLabel: .next,
                            focus: $focusedField,
                            focusedField: .newPassword,
                            onSubmit: {
                                touchedFields.insert(.newPassword)
                                focusedField = .confirmPassword
                            }
                        )

                        KairoTextField(
                            title: "Confirm password",
                            prompt: "Enter your new password again",
                            text: $state.confirmPassword,
                            errorMessage: confirmationErrorMessage,
                            accessibilityIdentifier: KairoAccessibilityID.passwordResetConfirmPassword,
                            accessibilityLabel: "Confirm new password",
                            textContentType: .newPassword,
                            textInputAutocapitalization: .never,
                            isSecure: true,
                            submitLabel: .go,
                            focus: $focusedField,
                            focusedField: .confirmPassword,
                            onSubmit: submitReset
                        )
                    }
                }

                Text("Use 12–128 characters. No uppercase, lowercase, number, or symbol combination is required.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            VStack(spacing: KairoSpacing.medium) {
                KairoPrimaryButton(
                    title: "Update password",
                    isLoading: isSubmitting,
                    accessibilityIdentifier: KairoAccessibilityID.passwordResetSubmit,
                    action: submitReset
                )
                .disabled(!isResetFormValid || isSubmitting)

                KairoSecondaryButton(
                    title: "Request a new reset email",
                    accessibilityIdentifier: KairoAccessibilityID.passwordResetRequestNew,
                    action: requestNewReset
                )
                .disabled(isSubmitting)

                errorBlock
            }
        }
        .onChange(of: state.token) { _, _ in clearSubmissionError() }
        .onChange(of: state.newPassword) { _, _ in clearSubmissionError() }
        .onChange(of: state.confirmPassword) { _, _ in clearSubmissionError() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.passwordResetTokenScreen)
    }

    private var successScreen: some View {
        OnboardingScreenLayout(
            layoutMode: .choice,
            eyebrow: "Account recovery",
            title: "Password updated",
            subtitle: "Your password has been changed. Sign in normally with your new password.",
            titleAccessibilityIdentifier: KairoAccessibilityID.passwordResetSuccess
        ) {
            statusIcon(systemName: "checkmark.shield.fill")
        } content: {
            EmptyView()
        } actions: {
            KairoPrimaryButton(
                title: "Back to login",
                accessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                action: returnToLogin
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.passwordResetSuccessScreen)
    }

    @ViewBuilder
    private var errorBlock: some View {
        if let submissionErrorMessage {
            VStack(spacing: KairoSpacing.small) {
                Text(submissionErrorMessage)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(KairoAccessibilityID.passwordResetError)

                if offersNewReset {
                    Button("Request a new reset email", action: requestNewReset)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.passwordResetRequestNew)
                }
            }
        }
    }

    private var requestEmailErrorMessage: String? {
        touchedFields.contains(.email)
            ? PasswordResetValidation.emailMessage(state.emailAddress)
            : nil
    }

    private var resetTokenErrorMessage: String? {
        touchedFields.contains(.token)
            ? PasswordResetValidation.tokenMessage(state.token)
            : nil
    }

    private var newPasswordErrorMessage: String? {
        touchedFields.contains(.newPassword)
            ? PasswordResetValidation.newPasswordMessage(state.newPassword)
            : nil
    }

    private var confirmationErrorMessage: String? {
        touchedFields.contains(.confirmPassword)
            ? PasswordResetValidation.confirmationMessage(
                password: state.newPassword,
                confirmation: state.confirmPassword
            )
            : nil
    }

    private var isRequestFormValid: Bool {
        PasswordResetValidation.emailMessage(state.emailAddress) == nil
    }

    private var isResetFormValid: Bool {
        PasswordResetValidation.tokenMessage(state.token) == nil
            && PasswordResetValidation.newPasswordMessage(state.newPassword) == nil
            && PasswordResetValidation.confirmationMessage(
                password: state.newPassword,
                confirmation: state.confirmPassword
            ) == nil
    }

    private func requestResetEmail() {
        touchedFields.insert(.email)
        guard isRequestFormValid, !isSubmitting else { return }

        clearSubmissionError()
        isSubmitting = true
        let normalizedEmail = CreateAccountValidation.normalizedEmail(state.emailAddress)

        Task {
            do {
                _ = try await authService.requestPasswordReset(email: normalizedEmail)
                await MainActor.run {
                    isSubmitting = false
                    state.emailAddress = normalizedEmail
                    state.showCheckEmail()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    apply(error, context: .requestEmail)
                }
            }
        }
    }

    private func submitReset() {
        touchedFields.formUnion([.token, .newPassword, .confirmPassword])
        guard isResetFormValid, !isSubmitting else { return }

        clearSubmissionError()
        isSubmitting = true
        let token = state.token
        let newPassword = state.newPassword
        let confirmPassword = state.confirmPassword

        Task {
            do {
                _ = try await authService.resetPassword(
                    token: token,
                    newPassword: newPassword,
                    confirmPassword: confirmPassword
                )
                await MainActor.run {
                    isSubmitting = false
                    state.showSuccess()
                    touchedFields.removeAll()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    apply(error, context: .submitReset)
                }
            }
        }
    }

    private func showResetForm() {
        clearSubmissionError()
        state.showResetForm()
        touchedFields.removeAll()
        focusedField = .token
    }

    private func requestNewReset() {
        clearSubmissionError()
        state.requestNewReset()
        touchedFields.removeAll()
        focusedField = .email
    }

    private func returnToLogin() {
        state.clearSensitiveFields()
        clearSubmissionError()
        router.showLogin()
    }

    private func apply(_ error: Error, context: PasswordResetRequestContext) {
        let presentation = PasswordResetErrorPresentation.resolve(error, context: context)
        submissionErrorMessage = presentation.message
        offersNewReset = presentation.offersNewReset
    }

    private func clearSubmissionError() {
        submissionErrorMessage = nil
        offersNewReset = false
    }

    private func statusIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 54, weight: .semibold))
            .foregroundStyle(KairoColors.brandPrimary)
            .accessibilityHidden(true)
    }
}
