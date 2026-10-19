import SwiftUI

struct GoogleAuthenticationButton: View {
    @Environment(\.authService) private var authService
    @Environment(\.openURL) private var openURL
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: KairoSpacing.small) {
            HStack(spacing: KairoSpacing.small) {
                Rectangle()
                    .fill(KairoColors.border)
                    .frame(height: 1)
                Text("OR")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                Rectangle()
                    .fill(KairoColors.border)
                    .frame(height: 1)
            }
            .accessibilityHidden(true)

            KairoSecondaryButton(
                title: "Continue with Google",
                isLoading: isLoading,
                accessibilityIdentifier: KairoAccessibilityID.googleAuthenticationStart,
                action: start
            )
            .disabled(isLoading)

            if let errorMessage {
                Text(errorMessage)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(KairoAccessibilityID.googleAuthenticationError)
            }
        }
    }

    private func start() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let authorizationURL = try await authService.googleAuthorizationURL()
                openURL(authorizationURL) { wasOpened in
                    isLoading = false
                    if !wasOpened {
                        errorMessage = "Google sign-in could not be opened. Please try again."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = Self.message(for: error)
                }
            }
        }
    }

    private static func message(for error: Error) -> String {
        guard let networkError = error as? NetworkError else {
            return "Google sign-in could not be started. Please try again."
        }

        return switch networkError {
        case .transport:
            "KairoID couldn't reach the network. Check your connection and try again."
        case .unavailableInDemoMode:
            "Google sign-in is unavailable in Demo Mode."
        case .api:
            "Google sign-in could not be started. Please try again."
        case .invalidResponse, .invalidURL:
            "Google sign-in could not be started safely. Please try again."
        }
    }
}

struct GoogleAuthenticationHandoffView: View {
    private enum Phase: Equatable {
        case exchanging
        case failed(String)
    }

    let presentation: GoogleAuthenticationPresentation

    @Environment(\.authService) private var authService
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @State private var phase: Phase = .exchanging
    @State private var hasStarted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: KairoSpacing.large) {
                Spacer()

                switch phase {
                case .exchanging:
                    KairoLoadingStateView(
                        title: "Completing Google sign-in",
                        message: "KairoID is securely exchanging the one-time sign-in handoff."
                    )
                case .failed(let message):
                    KairoErrorStateView(
                        title: "Google sign-in unavailable",
                        message: message
                    )

                    KairoPrimaryButton(
                        title: "Try Google again",
                        accessibilityIdentifier: KairoAccessibilityID.googleAuthenticationRetry,
                        action: router.dismissGoogleAuthentication
                    )
                }

                Spacer()
            }
            .padding(KairoSpacing.large)
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Google sign-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: router.dismissGoogleAuthentication)
                        .accessibilityIdentifier(KairoAccessibilityID.googleAuthenticationCancel)
                }
            }
        }
        .interactiveDismissDisabled(phase == .exchanging)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await GoogleReturnDiagnostics.$deliveryAttemptID.withValue(presentation.diagnosticDeliveryID) {
                await exchangeHandoff()
            }
        }
        .accessibilityIdentifier(KairoAccessibilityID.googleAuthenticationHandoff)
    }

    private func exchangeHandoff() async {
        GoogleReturnDiagnostics.emit(.exchangeStarted)
        do {
            let response = try await authService.exchangeGoogleHandoff(
                code: presentation.handoffCode
            )
            GoogleReturnDiagnostics.emit(.exchangeFinished)

            switch response.outcome {
            case .loginComplete:
                router.dismissGoogleAuthentication()
                await sessionStore.completeAuthenticationAndRoute()
            case .phoneVerificationRequired:
                guard let signup = response.signup else {
                    phase = .failed("Google sign-in returned an incomplete phone-verification handoff.")
                    return
                }
                router.dismissGoogleAuthentication()
                sessionStore.continueGooglePhoneSignup(signup)
            case .accountLinkingRequired:
                phase = .failed(
                    "An existing KairoID account uses this email. Sign in with your password; accounts are never linked automatically."
                )
            case .authFailed:
                phase = .failed(response.message)
            }
        } catch {
            GoogleReturnDiagnostics.emit(.exchangeFailed)
            phase = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        guard let networkError = error as? NetworkError else {
            return "Google sign-in could not be completed. Please try again."
        }

        return switch networkError {
        case .api: "Google sign-in could not be completed. Please try again."
        case .transport: "KairoID couldn't reach the network. Check your connection and try again."
        case .invalidResponse, .invalidURL: "Google sign-in returned an invalid handoff. Please try again."
        case .unavailableInDemoMode: "Google sign-in is unavailable in Demo Mode."
        }
    }
}

struct GooglePhoneCompletionView: View {
    private enum FocusField: Hashable {
        case phone
    }

    @Environment(\.authService) private var authService
    @EnvironmentObject private var sessionStore: AppSessionStore
    @FocusState private var focusedField: FocusField?
    @State private var phone = ""
    @State private var isSubmitting = false
    @State private var touched = false
    @State private var errorMessage: String?

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Google sign-in",
            title: "Add your mobile number",
            subtitle: "Your Google email is confirmed. Add and verify a mobile number to secure your KairoID account.",
            titleAccessibilityIdentifier: KairoAccessibilityID.googlePhoneCompletionTitle
        ) {
            EmptyView()
        } content: {
            KairoCard {
                KairoTextField(
                    title: "Mobile Number",
                    prompt: "10-digit Indian mobile number",
                    text: phoneBinding,
                    errorMessage: phoneErrorMessage,
                    accessibilityIdentifier: KairoAccessibilityID.googlePhoneCompletionPhone,
                    accessibilityLabel: "Mobile number",
                    accessibilityHint: "Enter a 10-digit Indian mobile number. KairoID will send a verification code.",
                    keyboardType: .phonePad,
                    textContentType: .telephoneNumber,
                    textInputAutocapitalization: .never,
                    submitLabel: .go,
                    focus: $focusedField,
                    focusedField: .phone,
                    onSubmit: submit
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(KairoAccessibilityID.googleAuthenticationError)
                }
            }
        } actions: {
            VStack(spacing: KairoSpacing.small) {
                KairoPrimaryButton(
                    title: "Send verification code",
                    isLoading: isSubmitting,
                    accessibilityIdentifier: KairoAccessibilityID.googlePhoneCompletionSubmit,
                    action: submit
                )
                .disabled(phoneErrorMessage != nil || isSubmitting)

                KairoSecondaryButton(
                    title: "Cancel Google signup",
                    accessibilityIdentifier: KairoAccessibilityID.googleAuthenticationCancel,
                    action: cancel
                )
                .disabled(isSubmitting)
            }
        }
        .onAppear { focusedField = .phone }
    }

    private var phoneBinding: Binding<String> {
        Binding(
            get: { phone },
            set: {
                phone = CreateAccountValidation.sanitizedMobileNumber($0)
                errorMessage = nil
            }
        )
    }

    private var phoneErrorMessage: String? {
        guard touched || !phone.isEmpty else { return nil }
        let draft = CreateAccountDraft(
            firstName: "Placeholder",
            lastName: "Placeholder",
            emailAddress: "placeholder@example.com",
            mobileNumber: phone
        )
        return CreateAccountValidation.errorMessage(for: .mobileNumber, in: draft)
    }

    private func submit() {
        touched = true
        guard phoneErrorMessage == nil, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let signup = try await authService.startGooglePhoneVerification(phone: phone)
                await MainActor.run {
                    isSubmitting = false
                    sessionStore.continueGooglePhoneVerification(signup)
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = GoogleAuthenticationHandoffView.messageForPhone(error)
                }
            }
        }
    }

    private func cancel() {
        Task {
            await sessionStore.abandonPendingSignup()
        }
    }
}

private extension GoogleAuthenticationHandoffView {
    static func messageForPhone(_ error: Error) -> String {
        guard let networkError = error as? NetworkError else {
            return "KairoID couldn't start mobile verification. Please try again."
        }

        return switch networkError {
        case .api:
            "Enter a valid mobile number and try again."
        case .transport:
            "KairoID couldn't reach the network. Check your connection and try again."
        case .invalidResponse, .invalidURL:
            "KairoID couldn't start mobile verification safely. Please try again."
        case .unavailableInDemoMode:
            "Google signup is unavailable in Demo Mode."
        }
    }
}
