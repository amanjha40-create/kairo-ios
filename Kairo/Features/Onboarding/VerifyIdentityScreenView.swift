import SwiftUI

struct VerifyIdentityScreenView: View {
    @Binding var createAccountDraft: CreateAccountDraft
    @Binding var state: VerifyIdentityFlowState

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        currentScreen
            .navigationBarBackButtonHidden(true)
            .onAppear {
                state.prepare(using: createAccountDraft)
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
                onContinue: { state.phase = .mobile }
            )
        case .mobile:
            ContactVerificationScreenView(
                channel: .mobile,
                state: $state.mobile,
                onBack: { state.phase = .email },
                onContinue: { router.advanceOnboarding(from: .verifyIdentity) }
            )
        }
    }

    private var introductionScreen: some View {
        OnboardingScreenLayout(
            eyebrow: "Verify once. Trusted everywhere.",
            title: "Verify your identity",
            subtitle: "Verify your email and mobile number to create your Trust Passport.",
            titleAccessibilityIdentifier: OnboardingStep.verifyIdentity.titleAccessibilityIdentifier
        ) {
            VerifyIdentityHero()
                .frame(maxWidth: 184)
        } content: {
            KairoCard {
                Text("Identity verification is the foundation of your reusable professional trust. You'll only need to do this once.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                trustBenefitRow(
                    title: "Own your trust",
                    message: "Verified identity becomes the durable base layer for your Trust Passport."
                )

                trustBenefitRow(
                    title: "Carry it forward",
                    message: "Your passport is designed to move with your career, not stay trapped in one system."
                )
            }
        } actions: {
            OnboardingActionGroup(
                primaryTitle: "Continue",
                primaryAccessibilityIdentifier: KairoAccessibilityID.verifyIdentityIntroContinue,
                primaryAction: { state.phase = .email },
                secondaryTitle: "Back",
                secondaryAccessibilityIdentifier: KairoAccessibilityID.verifyIdentityIntroBack,
                secondaryAction: { router.goBackOnboarding(from: .verifyIdentity) }
            )
        }
    }

    private func trustBenefitRow(title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: KairoSpacing.medium) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(KairoColors.brandPrimary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                Text(title)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)

                Text(message)
                    .font(KairoTypography.footnote)
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
    let onContinue: () -> Void

    @FocusState private var focusedField: FocusField?
    @State private var lastFocusedField: FocusField?

    var body: some View {
        OnboardingScreenLayout(
            eyebrow: channel.eyebrow,
            title: channel.title,
            subtitle: channel.subtitle,
            titleAccessibilityIdentifier: channel == .email
                ? KairoAccessibilityID.verifyIdentityEmailTitle
                : KairoAccessibilityID.verifyIdentityMobileTitle
        ) {
            VerificationMethodHero(channel: channel)
                .frame(maxWidth: 152)
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
            KairoTextField(
                title: channel.contactFieldTitle,
                prompt: channel.contactFieldPrompt,
                text: contactBinding,
                errorMessage: state.displayedContactErrorMessage,
                accessibilityIdentifier: channel.contactAccessibilityIdentifier,
                accessibilityLabel: channel.contactFieldTitle,
                accessibilityHint: channel.contactAccessibilityHint,
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
            .disabled(state.hasSentCode || state.isSendingCode || state.isVerifying)

            if channel == .mobile {
                Text("For this MVP, Kairo verifies 10-digit Indian mobile numbers.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
                    .font(KairoTypography.footnote)
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

                    Button(channel.changeButtonTitle, action: changeContact)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.brandPrimary)
                        .accessibilityIdentifier(channel.changeButtonAccessibilityIdentifier)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(channel.statusMessage)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var successCard: some View {
        KairoCard {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(KairoColors.brandPrimary)

            Text(channel.successTitle)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
                .accessibilityIdentifier(channel.successAccessibilityIdentifier)

            Text(channel.successMessage)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                Label("Trusted contact confirmed", systemImage: "checkmark.circle.fill")
                Label("Ready for the next verification step", systemImage: "arrow.forward.circle")
            }
            .font(KairoTypography.footnote)
            .foregroundStyle(KairoColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionGroup: some View {
        VStack(spacing: KairoSpacing.small) {
            KairoPrimaryButton(
                title: state.isVerified ? channel.continueButtonTitle : channel.verifyButtonTitle,
                isLoading: state.isVerifying,
                accessibilityIdentifier: state.isVerified
                    ? KairoAccessibilityID.onboardingContinue
                    : channel.verifyButtonAccessibilityIdentifier,
                action: state.isVerified ? onContinue : verifyCode
            )
            .disabled(state.isVerified ? false : !state.canVerify)

            KairoSecondaryButton(
                title: "Back",
                accessibilityIdentifier: KairoAccessibilityID.verifyIdentityBack,
                action: onBack
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func sendCode() {
        state.beginSendingCode()
        guard state.isSendingCode else {
            return
        }

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                state.completeSendingCode()
                focusedField = .code
            }
        }
    }

    private func resendCode() {
        state.resetForContactChange()
        sendCode()
    }

    private func changeContact() {
        state.resetForContactChange()
        focusedField = .contact
    }

    private func verifyCode() {
        state.beginVerification()
        guard state.isVerifying else {
            return
        }

        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                state.completeVerification()
                focusedField = nil
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
}

private struct VerifyIdentityHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                .fill(KairoColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                        .stroke(KairoColors.border, lineWidth: 1)
                )
                .kairoShadow(KairoShadow.card)

            VStack(spacing: KairoSpacing.large) {
                HStack(spacing: KairoSpacing.medium) {
                    verificationPill(systemImage: "envelope.badge.shield.half.filled", title: "Email")
                    verificationPill(systemImage: "iphone.badge.checkmark", title: "Mobile")
                }

                ZStack {
                    Circle()
                        .fill(KairoColors.brandPrimary.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(KairoColors.brandPrimary)
                }

                VStack(spacing: KairoSpacing.small) {
                    Text("Trust Passport")
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)

                    Text("Verified once")
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)
                }
            }
            .padding(KairoSpacing.xLarge)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.02, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func verificationPill(systemImage: String, title: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(KairoTypography.caption)
            .foregroundStyle(KairoColors.brandPrimary)
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.small)
            .background(KairoColors.brandPrimary.opacity(0.1), in: Capsule())
    }
}

private struct VerificationMethodHero: View {
    let channel: VerificationChannel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                .fill(KairoColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                        .stroke(KairoColors.border, lineWidth: 1)
                )
                .kairoShadow(KairoShadow.card)

            VStack(spacing: KairoSpacing.large) {
                Image(systemName: channel == .email ? "envelope.badge.shield.half.filled" : "iphone.badge.checkmark")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(KairoColors.brandPrimary)
                    .padding(KairoSpacing.medium)
                    .background(KairoColors.brandPrimary.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: KairoSpacing.small) {
                    Capsule()
                        .fill(KairoColors.textPrimary.opacity(0.12))
                        .frame(width: 116, height: 10)

                    Capsule()
                        .fill(KairoColors.textPrimary.opacity(0.08))
                        .frame(width: 136, height: 10)

                    Label("6-digit placeholder code", systemImage: "number.circle")
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                }
            }
            .padding(KairoSpacing.xLarge)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.02, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
