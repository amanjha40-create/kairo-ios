import SwiftUI
import Combine

@MainActor
final class AccountMobileVerificationState: ObservableObject {
    @Published var code = ""
    @Published private(set) var isBusy = false
    @Published private(set) var hasSentCode = false
    @Published private(set) var phoneRequired = false
    @Published private(set) var awaitingStatusRefresh = false
    @Published private(set) var message: String?
    @Published private(set) var resendAvailableAt: Date?

    func cooldown(at date: Date = Date()) -> Int {
        max(0, Int(ceil((resendAvailableAt ?? .distantPast).timeIntervalSince(date))))
    }

    var canVerify: Bool {
        hasSentCode && !isBusy && !awaitingStatusRefresh && !phoneRequired &&
        code.count == 6 && code.allSatisfy { $0.isASCII && $0.isNumber }
    }

    func send(using service: any AuthServiceProtocol) async -> Bool {
        guard !isBusy, !phoneRequired, !awaitingStatusRefresh, cooldown() == 0 else { return false }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let response = try await service.requestAccountMobileVerification()
            return try apply(response)
        } catch {
            message = safeMessage(error, verifying: false)
            return false
        }
    }

    func verify(using service: any AuthServiceProtocol) async -> Bool {
        guard canVerify else { return false }
        isBusy = true
        message = nil
        let submittedCode = code
        defer { isBusy = false }
        do {
            let response = try await service.verifyAccountMobile(code: submittedCode)
            return try apply(response)
        } catch {
            message = safeMessage(error, verifying: true)
            return false
        }
    }

    private func apply(_ response: AccountMobileVerificationResponse) throws -> Bool {
        guard response.isConsistent else { throw NetworkError.invalidResponse }
        code = ""
        switch response.state {
        case .codeSent:
            hasSentCode = true
            resendAvailableAt = Date().addingTimeInterval(TimeInterval(response.resendAfterSeconds))
        case .phoneRequired:
            phoneRequired = true
            hasSentCode = false
        case .verified:
            // Only a fresh onboarding-status read decides navigation, never this hint.
            awaitingStatusRefresh = true
            hasSentCode = false
            return true
        }
        return false
    }

    private func safeMessage(_ error: Error, verifying: Bool) -> String {
        if case AccountMobileVerificationError.emailRequired = error {
            return "This account needs email verification. Contact support for account recovery."
        }
        if case NetworkError.api(let apiError) = error {
            switch apiError.code {
            case .unauthorized:
                return verifying
                    ? "The code could not be verified. Check the latest code, or refresh your session and try again."
                    : "Your session needs to be refreshed. Tap Refresh status before trying again."
            case .rateLimited:
                return "Too many attempts. Wait before trying again."
            case .forbidden:
                return "Verification is unavailable for this account. Contact support for help."
            default:
                break
            }
        }
        return "Verification could not be completed. Check your connection and try again."
    }
}

struct AccountMobileVerificationScreen: View {
    let user: AppUser
    let status: OnboardingStatusResponseDTO?
    @Environment(\.authService) private var authService
    @EnvironmentObject private var sessionStore: AppSessionStore
    @StateObject private var state = AccountMobileVerificationState()
    @FocusState private var focus: Bool?

    private var needsPhone: Bool {
        state.phoneRequired || user.phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
    }

    private var canRequest: Bool {
        status?.emailVerified == true && status?.phoneVerified == false &&
        !needsPhone && !state.awaitingStatusRefresh
    }

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Account verification",
            title: "Verify your mobile number",
            subtitle: "Continue with your existing account. No new signup is needed.",
            titleAccessibilityIdentifier: "onboarding.accountVerification.title"
        ) {
            EmptyView()
        } content: {
            KairoCard {
                if status?.emailVerified == true {
                    Label("Email verified", systemImage: "checkmark.circle.fill")
                        .accessibilityIdentifier("onboarding.accountVerification.emailVerified")
                }
                if status == nil {
                    Text("Refresh your account status to continue.")
                } else if status?.emailVerified != true {
                    Text("This account needs email verification. Contact support for account recovery.")
                } else if needsPhone {
                    Text("Your account needs a mobile number before verification. Contact support to update your account.")
                        .accessibilityIdentifier("onboarding.accountVerification.phoneRequired")
                } else if state.awaitingStatusRefresh || status?.phoneVerified == true {
                    Text("Refresh your account status to continue with verified information.")
                } else {
                    Text("We'll send a code to the mobile number saved on your account.")
                    Text("Mobile ending in \(String((user.phone ?? "").suffix(4)))")
                        .font(KairoTypography.bodyStrong)
                    if state.hasSentCode {
                        KairoOTPField(
                            title: "OTP Code", prompt: "6-digit code", length: 6,
                            code: $state.code,
                            accessibilityIdentifier: "onboarding.accountVerification.code",
                            accessibilityLabel: "Mobile verification code",
                            accessibilityHint: "Enter the latest 6-digit code.",
                            focus: $focus, focusedField: true
                        )
                        .disabled(state.isBusy)
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = state.cooldown(at: context.date)
                        KairoSecondaryButton(
                            title: seconds > 0 ? "Resend available in \(seconds)s" : (state.hasSentCode ? "Resend Code" : "Send Code"),
                            accessibilityIdentifier: "onboarding.accountVerification.send"
                        ) {
                            Task {
                                if await state.send(using: authService) {
                                    await sessionStore.refreshLaunchRoute()
                                }
                            }
                        }
                        .disabled(!canRequest || state.isBusy || seconds > 0)
                    }
                }
                if let message = state.message {
                    Text(message)
                        .foregroundStyle(KairoColors.textSecondary)
                        .accessibilityIdentifier("onboarding.accountVerification.error")
                }
            }
        } actions: {
            if canRequest && state.hasSentCode {
                KairoPrimaryButton(
                    title: "Verify Mobile",
                    accessibilityIdentifier: "onboarding.accountVerification.verify"
                ) {
                    Task {
                        if await state.verify(using: authService) {
                            focus = nil
                            await sessionStore.refreshLaunchRoute()
                        }
                    }
                }
                .disabled(!state.canVerify)
            }
            KairoSecondaryButton(
                title: "Refresh status",
                accessibilityIdentifier: "onboarding.accountVerification.refresh"
            ) {
                Task { await sessionStore.refreshLaunchRoute() }
            }
            .disabled(state.isBusy)
        }
        .navigationBarBackButtonHidden(true)
    }
}
