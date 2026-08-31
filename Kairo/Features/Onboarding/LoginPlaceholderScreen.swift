import SwiftUI

struct LoginScreenView: View {
    private enum FocusField: Hashable {
        case email
        case password
    }

    @Environment(\.authService) private var authService
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @FocusState private var focusedField: FocusField?
    @State private var emailAddress = ""
    @State private var password = ""
    @State private var touchedFields: Set<FocusField> = []
    @State private var isSubmitting = false
    @State private var submissionErrorMessage: String?

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Welcome back",
            title: "Login",
            subtitle: "Sign in to continue building and using your Trust Passport.",
            titleAccessibilityIdentifier: KairoAccessibilityID.onboardingLoginTitle
        ) {
            EmptyView()
        } content: {
            KairoCard {
                VStack(spacing: KairoSpacing.medium) {
                    KairoTextField(
                        title: "Email Address",
                        prompt: "name@example.com",
                        text: $emailAddress,
                        errorMessage: emailErrorMessage,
                        accessibilityIdentifier: KairoAccessibilityID.onboardingLoginEmail,
                        accessibilityLabel: "Email address",
                        keyboardType: .emailAddress,
                        textContentType: .username,
                        textInputAutocapitalization: .never,
                        submitLabel: .next,
                        focus: $focusedField,
                        focusedField: .email,
                        onSubmit: {
                            touchedFields.insert(.email)
                            focusedField = .password
                        }
                    )

                    KairoTextField(
                        title: "Password",
                        prompt: "Enter your password",
                        text: $password,
                        errorMessage: passwordErrorMessage,
                        accessibilityIdentifier: KairoAccessibilityID.onboardingLoginPassword,
                        accessibilityLabel: "Password",
                        textContentType: .password,
                        textInputAutocapitalization: .never,
                        isSecure: true,
                        submitLabel: .go,
                        focus: $focusedField,
                        focusedField: .password,
                        onSubmit: {
                            touchedFields.insert(.password)
                            submit()
                        }
                    )

                    Button("Forgot password?") {
                        router.showForgotPassword(initialEmail: emailAddress)
                    }
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.brandPrimary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier(KairoAccessibilityID.passwordResetForgotPassword)
                    .disabled(isSubmitting)
                }
            }
        } actions: {
            VStack(spacing: KairoSpacing.medium) {
                KairoPrimaryButton(
                    title: "Login",
                    isLoading: isSubmitting,
                    accessibilityIdentifier: KairoAccessibilityID.onboardingLoginSubmit,
                    action: submit
                )
                .disabled(!isFormValid || isSubmitting)

                KairoSecondaryButton(
                    title: "Back",
                    accessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                    action: { router.showOnboarding() }
                )
                .disabled(isSubmitting)

                if let submissionErrorMessage {
                    Text(submissionErrorMessage)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.danger)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(KairoAccessibilityID.onboardingLoginError)
                }
            }
        }
        .onChange(of: emailAddress) { _, _ in
            submissionErrorMessage = nil
        }
        .onChange(of: password) { _, _ in
            submissionErrorMessage = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.onboardingLoginScreen)
    }

    private var emailErrorMessage: String? {
        guard touchedFields.contains(.email) else {
            return nil
        }

        let draft = CreateAccountDraft(
            firstName: "Placeholder",
            lastName: "Placeholder",
            emailAddress: emailAddress,
            mobileNumber: "9876543210"
        )
        return CreateAccountValidation.errorMessage(for: .emailAddress, in: draft)
    }

    private var passwordErrorMessage: String? {
        guard touchedFields.contains(.password) else {
            return nil
        }

        return password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Enter your password."
            : nil
    }

    private var isFormValid: Bool {
        validateEmail(emailAddress) == nil && validatePassword(password) == nil
    }

    private func submit() {
        touchedFields.formUnion([.email, .password])
        guard isFormValid, !isSubmitting else {
            return
        }

        submissionErrorMessage = nil
        isSubmitting = true

        let normalizedEmail = CreateAccountValidation.normalizedEmail(emailAddress)
        let currentPassword = password

        Task {
            do {
                _ = try await authService.login(email: normalizedEmail, password: currentPassword)
                await sessionStore.completeAuthenticationAndRoute()
                await MainActor.run {
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submissionErrorMessage = loginMessage(for: error)
                }
            }
        }
    }

    private func loginMessage(for error: Error) -> String {
        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .api(let apiError):
                switch apiError.code {
                case .unauthorized:
                    return "Check your email and password, then try again."
                case .rateLimited:
                    return "Too many login attempts. Please try again shortly."
                case .serviceUnavailable, .internalError:
                    return "Kairo is temporarily unavailable. Please try again."
                default:
                    return apiError.message
                }
            case .transport:
                return "Kairo couldn't reach the network. Check your connection and try again."
            case .invalidResponse:
                return "Kairo received an unexpected response. Please try again."
            case .invalidURL:
                return "Kairo's API configuration is invalid."
            case .unavailableInDemoMode:
                return "Demo Mode keeps authentication local only."
            }
        default:
            return error.localizedDescription
        }
    }

    private func validateEmail(_ value: String) -> String? {
        let draft = CreateAccountDraft(
            firstName: "Placeholder",
            lastName: "Placeholder",
            emailAddress: value,
            mobileNumber: "9876543210"
        )
        return CreateAccountValidation.errorMessage(for: .emailAddress, in: draft)
    }

    private func validatePassword(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Enter your password."
            : nil
    }
}
