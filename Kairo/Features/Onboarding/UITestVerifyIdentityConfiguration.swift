import Foundation

struct UITestVerifyIdentityConfiguration {
    enum EnvironmentKey {
        static let phase = "KAIRO_UI_TEST_VERIFY_IDENTITY_PHASE"
        static let emailState = "KAIRO_UI_TEST_VERIFY_IDENTITY_EMAIL_STATE"
        static let mobileState = "KAIRO_UI_TEST_VERIFY_IDENTITY_MOBILE_STATE"
    }

    enum ChannelState: String {
        case pristine
        case codeSent
        case invalidCode
        case validCode
        case verified
    }

    let state: VerifyIdentityFlowState

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestVerifyIdentityConfiguration {
        guard UITestLaunchConfiguration.current(arguments: arguments, environment: environment).isEnabled else {
            return UITestVerifyIdentityConfiguration(state: VerifyIdentityFlowState())
        }

        let phase = VerifyIdentityPhase(rawValue: environment[EnvironmentKey.phase] ?? "") ?? .introduction
        let emailState = ChannelState(rawValue: environment[EnvironmentKey.emailState] ?? "") ?? .pristine
        let mobileState = ChannelState(rawValue: environment[EnvironmentKey.mobileState] ?? "") ?? .pristine

        var state = VerifyIdentityFlowState()
        state.phase = phase
        apply(channelState: emailState, to: &state.email)
        apply(channelState: mobileState, to: &state.mobile)

        return UITestVerifyIdentityConfiguration(state: state)
    }

    private static func apply(
        channelState: ChannelState,
        to state: inout ContactVerificationState
    ) {
        switch channelState {
        case .pristine:
            break
        case .codeSent:
            state.beginSendingCode()
            state.completeSendingCode()
        case .invalidCode:
            state.beginSendingCode()
            state.completeSendingCode()
            state.setOTPCode("123")
            state.markOTPTouched()
        case .validCode:
            state.beginSendingCode()
            state.completeSendingCode()
            state.setOTPCode("123456")
            state.markOTPTouched()
        case .verified:
            state.beginSendingCode()
            state.completeSendingCode()
            state.setOTPCode("123456")
            state.beginVerification()
            state.completeVerification()
        }
    }
}
