import SwiftUI

struct VerifyIdentityScreenView: View {
    @Binding var createAccountDraft: CreateAccountDraft
    @Binding var state: VerifyIdentityFlowState
    let recoveredSession: SignupSessionRecoveryResponseDTO?
    let onStartOver: () -> Void

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        currentScreen
            .navigationBarBackButtonHidden(true)
            .accessibilityIdentifier(
                state.usesAuthoritativeRecovery
                    ? KairoAccessibilityID.verifyIdentityRecoveredSession
                    : OnboardingStep.verifyIdentity.titleAccessibilityIdentifier
            )
            .onAppear {
                state.prepare(using: createAccountDraft)
                if let recoveredSession, !state.usesAuthoritativeRecovery {
                    state.applyRecovery(recoveredSession)
                }
            }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch state.phase {
        case .introduction:
            introductionScreen
        case .email:
            ContactVerificationScreenView(
                channel: .email,
                state: $state.email,
                onBack: { state.phase = .introduction },
                onStartOver: onStartOver,
                onContinue: { state.phase = .mobile }
            )
        case .mobile:
            ContactVerificationScreenView(
                channel: .mobile,
                state: $state.mobile,
                onBack: { state.phase = .email },
                onStartOver: onStartOver,
                onContinue: { router.advanceOnboarding(from: .verifyIdentity) }
            )
        }
    }

    private var introductionScreen: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Identity verification",
            title: "Verify your identity",
            subtitle: "Confirm your email and mobile number so Kairo can secure your account and continue onboarding.",
            titleAccessibilityIdentifier: OnboardingStep.verifyIdentity.titleAccessibilityIdentifier
        ) {
            EmptyView()
        } content: {
            KairoCard {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    introductionStep(
                        title: "Verify your email",
                        message: "Start with the code sent to the email address linked to this account."
                    )

                    Divider()
                        .overlay(KairoColors.border)

                    introductionStep(
                        title: "Verify your mobile number",
                        message: "Then confirm your mobile number so Kairo can protect your account and recovery steps."
                    )
                }
            }
        } actions: {
            OnboardingActionGroup(
                primaryTitle: "Continue",
                primaryAccessibilityIdentifier: KairoAccessibilityID.verifyIdentityIntroContinue,
                primaryAction: { state.phase = .email },
                secondaryTitle: recoveredSession == nil ? "Back" : "Start over",
                secondaryAccessibilityIdentifier: recoveredSession == nil
                    ? KairoAccessibilityID.verifyIdentityIntroBack
                    : KairoAccessibilityID.verifyIdentityRecoveryStartOver,
                secondaryAction: {
                    if recoveredSession == nil {
                        router.goBackOnboarding(from: .verifyIdentity)
                    } else {
                        onStartOver()
                    }
                }
            )
        }
    }

    private func introductionStep(title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: KairoSpacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(KairoColors.brandPrimary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                Text(title)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)

                Text(message)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ContactVerificationScreenView: View {
    enum FocusField: Hashable {
        case contact
        case code
    }

    let channel: VerificationChannel
    @Binding var state: ContactVerificationState
    let onBack: () -> Void
    let onStartOver: () -> Void
    let onContinue: () -> Void

    @Environment(\.authService) private var authService
    @EnvironmentObject private var sessionStore: AppSessionStore
    @FocusState private var focusedField: FocusField?
    @State private var lastFocusedField: FocusField?
    @State private var isCompletingSignup = false

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: channel.eyebrow,
            title: channel.title,
            subtitle: channel.subtitle,
            titleAccessibilityIdentifier: channel == .email
                ? KairoAccessibilityID.verifyIdentityEmailTitle
                : KairoAccessibilityID.verifyIdentityMobileTitle
        ) {
            EmptyView()
        } content: {
            if state.isVerified {
                successCard
            } else {
                entryCard
            }
        } actions: {
            actionGroup
        }
        .onChange(of: focusedField) { _, newValue in
            if let lastFocusedField, lastFocusedField != newValue {
                markTouched(lastFocusedField)
            }

            lastFocusedField = newValue
        }
        .task(id: timerTaskKey) {
            guard state.countdownRemaining > 0 else {
                return
            }

            try? await Task.sleep(for: .seconds(1))
            state.tickCountdown()
        }
    }

    private var timerTaskKey: String {
        "\(channel.rawValue)-\(state.countdownRemaining)-\(state.hasSentCode)-\(state.isVerified)"
    }

    private var entryCard: some View {
        KairoCard {
            Text(channel == .email ? "We'll send a 6-digit code to the email address linked to this account." : "We'll send a 6-digit code to the mobile number linked to this account.")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            KairoTextField(
                title: channel.contactFieldTitle,
                prompt: channel.contactFieldPrompt,
                text: contactBinding,
                errorMessage: state.displayedContactErrorMessage,
                accessibilityIdentifier: channel.contactAccessibilityIdentifier,
                accessibilityLabel: channel.contactFieldTitle,
                accessibilityHint: state.isAuthoritativeContact
                    ? "This masked contact is owned by the recovered signup session and cannot be changed here."
                    : channel.contactAccessibilityHint,
                keyboardType: channel == .email ? .emailAddress : .phonePad,
                textContentType: channel == .email ? .emailAddress : .telephoneNumber,
                textInputAutocapitalization: .never,
                submitLabel: state.hasSentCode ? .next : .done,
                focus: $focusedField,
                focusedField: .contact,
                onSubmit: {
                    state.markContactTouched()
                    if state.hasSentCode {
                        focusedField = .code
                    } else {
                        focusedField = nil
                    }
                }
            )
            .disabled(
                state.isAuthoritativeContact ||
                state.hasSentCode ||
                state.isSendingCode ||
                state.isVerifying
            )

            Divider()
                .overlay(KairoColors.border)

            KairoOTPField(
                title: channel.codeFieldTitle,
                prompt: channel.codeFieldPrompt,
                length: channel.otpLength,
                code: otpBinding,
                errorMessage: state.displayedOTPErrorMessage,
                accessibilityIdentifier: channel.codeAccessibilityIdentifier,
                accessibilityLabel: "\(channel.codeFieldTitle), \(channel == .email ? "email" : "mobile") verification",
                accessibilityHint: "Enter the 6-digit code. Supports paste and one-time-code autofill.",
                focus: $focusedField,
                focusedField: .code,
                onSubmit: {
                    state.markOTPTouched()
                    focusedField = nil
                }
            )
            .disabled(!state.isCodeEntryEnabled || state.isSendingCode || state.isVerifying)

            statusBlock

            KairoSecondaryButton(
                title: channel.sendCodeButtonTitle,
                isLoading: state.isSendingCode,
                accessibilityIdentifier: channel.sendButtonAccessibilityIdentifier,
                action: sendCode
            )
            .disabled(!state.canSendCode)
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        if state.hasSentCode || state.isSendingCode {
            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                Text(channel.codeSentMessage)
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(state.countdownText)
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                    .accessibilityIdentifier(channel.countdownAccessibilityIdentifier)

                HStack(spacing: KairoSpacing.large) {
                    Button("Resend Code", action: resendCode)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(state.canResendCode ? KairoColors.brandPrimary : KairoColors.textSecondary)
                        .disabled(!state.canResendCode)
                        .accessibilityIdentifier(channel.resendButtonAccessibilityIdentifier)

                    if !state.isAuthoritativeContact {
                        Button(channel.changeButtonTitle, action: changeContact)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.brandPrimary)
                            .accessibilityIdentifier(channel.changeButtonAccessibilityIdentifier)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(channel.statusMessage)
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var successCard: some View {
        KairoCard {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                HStack(spacing: KairoSpacing.small) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(KairoColors.brandPrimary)

                    Text(channel.successTitle)
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)
                        .accessibilityIdentifier(channel.successAccessibilityIdentifier)
                }

                Text(channel.successMessage)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: KairoSpacing.small) {
                    Image(systemName: channel == .email ? "arrow.forward.circle" : "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(channel == .email ? "Continue to mobile verification." : "Continue into the rest of onboarding.")
                        .font(KairoTypography.footnote)
                }
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionGroup: some View {
        VStack(spacing: KairoSpacing.small) {
            KairoPrimaryButton(
                title: primaryButtonTitle,
                isLoading: primaryButtonLoading,
                accessibilityIdentifier: primaryButtonAccessibilityIdentifier,
                action: primaryButtonAction
            )
            .disabled(primaryButtonDisabled)

            KairoSecondaryButton(
                title: state.isAuthoritativeContact ? "Start over" : "Back",
                accessibilityIdentifier: state.isAuthoritativeContact
                    ? KairoAccessibilityID.verifyIdentityRecoveryStartOver
                    : KairoAccessibilityID.verifyIdentityBack,
                action: state.isAuthoritativeContact ? onStartOver : onBack
            )
            .disabled(isCompletingSignup)
        }
        .accessibilityElement(children: .contain)
    }

    private func sendCode() {
        state.beginSendingCode()
        guard state.isSendingCode else {
            return
        }

        Task {
            do {
                let response: SignupChannelSendResponseDTO
                switch channel {
                case .email:
                    response = try await authService.sendEmailCode(email: state.contactValue)
                case .mobile:
                    response = try await authService.sendPhoneCode(mobileNumber: state.contactValue)
                }

                await MainActor.run {
                    state.completeSendingCode(resendAfterSeconds: response.resendAfterSeconds)
                    focusedField = .code
                }
            } catch {
                await MainActor.run {
                    state.failSendingCode(message: authMessage(for: error))
                }
            }
        }
    }

    private func resendCode() {
        state.resetForContactChange()
        state.beginSendingCode()
        guard state.isSendingCode else {
            return
        }

        Task {
            do {
                let response: SignupChannelSendResponseDTO
                switch channel {
                case .email:
                    response = try await authService.resendEmailCode(email: state.contactValue)
                case .mobile:
                    response = try await authService.resendPhoneCode(mobileNumber: state.contactValue)
                }

                await MainActor.run {
                    state.completeSendingCode(resendAfterSeconds: response.resendAfterSeconds)
                    focusedField = .code
                }
            } catch {
                await MainActor.run {
                    state.failSendingCode(message: authMessage(for: error))
                }
            }
        }
    }

    private func changeContact() {
        guard !state.isAuthoritativeContact else {
            return
        }

        state.resetForContactChange()
        focusedField = .contact
    }

    private func verifyCode() {
        state.beginVerification()
        guard state.isVerifying else {
            return
        }

        Task {
            do {
                switch channel {
                case .email:
                    try await authService.verifyEmail(
                        email: state.contactValue,
                        code: state.otpCode
                    )
                case .mobile:
                    try await authService.verifyPhone(
                        mobileNumber: state.contactValue,
                        code: state.otpCode
                    )
                }

                await MainActor.run {
                    state.completeVerification()
                    focusedField = nil
                }
            } catch {
                await MainActor.run {
                    state.failVerification(message: authMessage(for: error))
                }
            }
        }
    }

    private func markTouched(_ field: FocusField) {
        switch field {
        case .contact:
            state.markContactTouched()
        case .code:
            state.markOTPTouched()
        }
    }

    private var contactBinding: Binding<String> {
        Binding(
            get: { state.contactValue },
            set: { state.setContactValue($0) }
        )
    }

    private var otpBinding: Binding<String> {
        Binding(
            get: { state.otpCode },
            set: { state.setOTPCode($0) }
        )
    }

    private func continueAfterVerification() {
        guard state.isVerified else {
            return
        }

        if channel == .email {
            onContinue()
            return
        }

        isCompletingSignup = true

        Task {
            do {
                _ = try await authService.completeSignup()
                await sessionStore.completeAuthenticationAndRoute()
                await MainActor.run {
                    isCompletingSignup = false
                }
            } catch {
                await MainActor.run {
                    isCompletingSignup = false
                    state.serverErrorMessage = authMessage(for: error)
                }
            }
        }
    }

    private var primaryButtonTitle: String {
        state.isVerified ? channel.continueButtonTitle : channel.verifyButtonTitle
    }

    private var primaryButtonLoading: Bool {
        state.isVerified ? isCompletingSignup : state.isVerifying
    }

    private var primaryButtonAccessibilityIdentifier: String {
        state.isVerified
            ? KairoAccessibilityID.onboardingContinue
            : channel.verifyButtonAccessibilityIdentifier
    }

    private var primaryButtonDisabled: Bool {
        state.isVerified ? isCompletingSignup : !state.canVerify
    }

    private func primaryButtonAction() {
        if state.isVerified {
            continueAfterVerification()
        } else {
            verifyCode()
        }
    }

    private func authMessage(for error: Error) -> String {
        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .api(let apiError):
                switch apiError.code {
                case .validationError:
                    return apiError.fieldErrors["code"]?.first ?? apiError.message
                case .rateLimited:
                    return "Too many attempts. Please try again shortly."
                case .serviceUnavailable, .internalError:
                    return "Kairo is temporarily unavailable. Please try again."
                case .unauthorized:
                    return "Your signup session expired. Please start again."
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
                return "Verification isn't available in this preview."
            }
        case let sessionError as SessionServiceError where sessionError == .missingSignupSession:
            return "Your signup session expired. Please start again."
        default:
            return error.localizedDescription
        }
    }
}
