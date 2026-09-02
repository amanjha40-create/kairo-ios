import Foundation

struct OnboardingFlowState: Equatable, Sendable {
    var createAccountDraft: CreateAccountDraft
    var verifyIdentityState: VerifyIdentityFlowState
    var chooseStartState: ChooseStartState
    var resumeImportState: ResumeImportState
    var manualProfileState: ManualProfileFlowState

    init(
        createAccountDraft: CreateAccountDraft = CreateAccountDraft(),
        verifyIdentityState: VerifyIdentityFlowState = VerifyIdentityFlowState(),
        chooseStartState: ChooseStartState = ChooseStartState(),
        resumeImportState: ResumeImportState = ResumeImportState(),
        manualProfileState: ManualProfileFlowState = ManualProfileFlowState()
    ) {
        self.createAccountDraft = createAccountDraft
        self.verifyIdentityState = verifyIdentityState
        self.chooseStartState = chooseStartState
        self.resumeImportState = resumeImportState
        self.manualProfileState = manualProfileState
    }

    mutating func applyCompletedResumeImportHandoff(
        manualProfileState: ManualProfileFlowState
    ) {
        chooseStartState.select(.buildProfileManually)
        resumeImportState = ResumeImportState()
        self.manualProfileState = manualProfileState
    }
}

enum VerifyIdentityPhase: String, Equatable, Sendable {
    case introduction
    case email
    case mobile
}

enum VerificationChannel: String, Equatable, Sendable {
    case email
    case mobile

    var title: String {
        switch self {
        case .email:
            "Verify your email"
        case .mobile:
            "Verify your mobile"
        }
    }

    var subtitle: String {
        switch self {
        case .email:
            "Confirm the email address that anchors your reusable Trust Passport."
        case .mobile:
            "Add your mobile number as a trusted second contact for your passport."
        }
    }

    var eyebrow: String {
        "Verify once. Trusted everywhere."
    }

    var contactFieldTitle: String {
        switch self {
        case .email:
            "Email Address"
        case .mobile:
            "Mobile Number"
        }
    }

    var contactFieldPrompt: String {
        switch self {
        case .email:
            "name@example.com"
        case .mobile:
            "10-digit Indian mobile number"
        }
    }

    var contactAccessibilityHint: String {
        switch self {
        case .email:
            "Enter the email address you want to verify for your Trust Passport."
        case .mobile:
            "Enter a 10-digit Indian mobile number for your Trust Passport."
        }
    }

    var codeFieldTitle: String {
        "OTP Code"
    }

    var codeFieldPrompt: String {
        "Enter the 6-digit code"
    }

    var sendCodeButtonTitle: String {
        "Send Code"
    }

    var verifyButtonTitle: String {
        switch self {
        case .email:
            "Verify Email"
        case .mobile:
            "Verify Mobile"
        }
    }

    var changeButtonTitle: String {
        switch self {
        case .email:
            "Change Email"
        case .mobile:
            "Change Mobile"
        }
    }

    var continueButtonTitle: String {
        switch self {
        case .email:
            "Continue to Mobile Verification"
        case .mobile:
            "Continue to Choose Start"
        }
    }

    var successTitle: String {
        switch self {
        case .email:
            "Email verified"
        case .mobile:
            "Mobile verified"
        }
    }

    var successMessage: String {
        switch self {
        case .email:
            "Your verified email is now linked to your Trust Passport foundation."
        case .mobile:
            "Your Trust Passport now has both verified contact points in place."
        }
    }

    var statusMessage: String {
        switch self {
        case .email:
            "We'll use this verified email to help you own and carry your professional trust."
        case .mobile:
            "This number stays with your Trust Passport as a reusable contact for future verification."
        }
    }

    var codeSentMessage: String {
        switch self {
        case .email:
            "A 6-digit code was sent to the email address linked to this signup."
        case .mobile:
            "A 6-digit code was sent to the mobile number linked to this signup."
        }
    }

    var emptyContactMessage: String {
        switch self {
        case .email:
            "Enter your email address."
        case .mobile:
            "Enter your mobile number."
        }
    }

    var invalidContactMessage: String {
        switch self {
        case .email:
            "Enter a valid email address."
        case .mobile:
            "Enter a valid 10-digit Indian mobile number."
        }
    }

    var contactAccessibilityIdentifier: String {
        switch self {
        case .email:
            KairoAccessibilityID.verifyIdentityEmailAddress
        case .mobile:
            KairoAccessibilityID.verifyIdentityMobileNumber
        }
    }

    var codeAccessibilityIdentifier: String {
        switch self {
        case .email:
            KairoAccessibilityID.verifyIdentityEmailCode
        case .mobile:
            KairoAccessibilityID.verifyIdentityMobileCode
        }
    }

    var sendButtonAccessibilityIdentifier: String {
        switch self {
        case .email:
            KairoAccessibilityID.verifyIdentityEmailSendCode
        case .mobile:
            KairoAccessibilityID.verifyIdentityMobileSendCode
        }
    }

    var verifyButtonAccessibilityIdentifier: String {
        switch self {
        case .email:
            KairoAccessibilityID.verifyIdentityEmailVerify
        case .mobile:
            KairoAccessibilityID.verifyIdentityMobileVerify
        }
    }

    var resendButtonAccessibilityIdentifier: String {
        switch self {
        case .email:
            KairoAccessibilityID.verifyIdentityEmailResendCode
        case .mobile:
            KairoAccessibilityID.verifyIdentityMobileResendCode
        }
    }

    var changeButtonAccessibilityIdentifier: String {
        switch self {
        case .email:
            KairoAccessibilityID.verifyIdentityEmailChange
        case .mobile:
            KairoAccessibilityID.verifyIdentityMobileChange
        }
    }

    var successAccessibilityIdentifier: String {
        switch self {
        case .email:
            KairoAccessibilityID.verifyIdentityEmailSuccess
        case .mobile:
            KairoAccessibilityID.verifyIdentityMobileSuccess
        }
    }

    var countdownAccessibilityIdentifier: String {
        switch self {
        case .email:
            KairoAccessibilityID.verifyIdentityEmailCountdown
        case .mobile:
            KairoAccessibilityID.verifyIdentityMobileCountdown
        }
    }

    var otpLength: Int { 6 }
    var countdownDuration: Int { 30 }

    func sanitizeContact(_ value: String) -> String {
        switch self {
        case .email:
            CreateAccountValidation.normalizedEmail(value)
        case .mobile:
            CreateAccountValidation.sanitizedMobileNumber(value)
        }
    }

    func contactValidationMessage(for value: String) -> String? {
        let normalizedValue = sanitizeContact(value)
        guard !normalizedValue.isEmpty else {
            return emptyContactMessage
        }

        switch self {
        case .email:
            let draft = CreateAccountDraft(
                firstName: "Placeholder",
                lastName: "Placeholder",
                emailAddress: normalizedValue,
                mobileNumber: "9876543210"
            )
            return CreateAccountValidation.errorMessage(for: .emailAddress, in: draft)
        case .mobile:
            let draft = CreateAccountDraft(
                firstName: "Placeholder",
                lastName: "Placeholder",
                emailAddress: "placeholder@example.com",
                mobileNumber: normalizedValue
            )
            return CreateAccountValidation.errorMessage(for: .mobileNumber, in: draft)
        }
    }
}

struct VerifyIdentityFlowState: Equatable, Sendable {
    var phase: VerifyIdentityPhase = .introduction
    var email = ContactVerificationState(channel: .email)
    var mobile = ContactVerificationState(channel: .mobile)

    var usesAuthoritativeRecovery: Bool {
        email.isAuthoritativeContact || mobile.isAuthoritativeContact
    }

    mutating func prepare(using draft: CreateAccountDraft) {
        email.prefillIfPristine(with: draft.emailAddress)
        mobile.prefillIfPristine(with: draft.mobileNumber)
    }

    mutating func applyRecovery(
        _ recovery: SignupSessionRecoveryResponseDTO,
        now: Date = Date()
    ) {
        guard recovery.state == .valid else {
            return
        }

        email.applyAuthoritativeRecovery(
            maskedContact: recovery.emailMasked,
            isVerified: recovery.emailVerified,
            resendAvailableAt: recovery.emailResendAvailableAt,
            now: now
        )
        mobile.applyAuthoritativeRecovery(
            maskedContact: recovery.phoneMasked,
            isVerified: recovery.phoneVerified,
            resendAvailableAt: recovery.phoneResendAvailableAt,
            now: now
        )

        switch recovery.nextStep {
        case .verifyEmail:
            phase = .email
        case .verifyPhone, .completeSignup:
            phase = .mobile
        case .completed, .none:
            phase = .introduction
        }
    }
}

struct ContactVerificationState: Equatable, Sendable {
    let channel: VerificationChannel
    var contactValue: String = ""
    var otpCode: String = ""
    var serverErrorMessage: String?
    var isContactTouched = false
    var isOTPTouched = false
    var hasSentCode = false
    var isSendingCode = false
    var isVerifying = false
    var isVerified = false
    var countdownRemaining = 0
    var isAuthoritativeContact = false

    init(channel: VerificationChannel, contactValue: String = "") {
        self.channel = channel
        self.contactValue = channel.sanitizeContact(contactValue)
    }

    var isPristine: Bool {
        contactValue.isEmpty &&
        otpCode.isEmpty &&
        !isContactTouched &&
        !isOTPTouched &&
        !hasSentCode &&
        !isSendingCode &&
        !isVerifying &&
        !isVerified &&
        countdownRemaining == 0
    }

    var contactErrorMessage: String? {
        if isAuthoritativeContact {
            return nil
        }

        return channel.contactValidationMessage(for: contactValue)
    }

    var displayedContactErrorMessage: String? {
        isContactTouched ? contactErrorMessage : nil
    }

    var otpErrorMessage: String? {
        guard hasSentCode else {
            return nil
        }

        if otpCode.isEmpty {
            return "Enter the 6-digit code."
        }

        return otpCode.count == channel.otpLength ? nil : "Enter the full 6-digit code."
    }

    var displayedOTPErrorMessage: String? {
        if let otpErrorMessage, isOTPTouched {
            return otpErrorMessage
        }

        return serverErrorMessage
    }

    var canSendCode: Bool {
        !hasSentCode &&
        !isSendingCode &&
        !isVerifying &&
        !isVerified &&
        contactErrorMessage == nil
    }

    var canResendCode: Bool {
        hasSentCode &&
        !isSendingCode &&
        !isVerifying &&
        !isVerified &&
        countdownRemaining == 0
    }

    var canVerify: Bool {
        hasSentCode &&
        !isSendingCode &&
        !isVerifying &&
        !isVerified &&
        otpErrorMessage == nil
    }

    var isCodeEntryEnabled: Bool {
        hasSentCode && !isVerified
    }

    var countdownText: String {
        let seconds = String(format: "%02d", max(countdownRemaining, 0))
        return countdownRemaining == 0
            ? "You can resend a code now."
            : "Resend available in 00:\(seconds)"
    }

    mutating func prefillIfPristine(with value: String) {
        guard isPristine, !isAuthoritativeContact else {
            return
        }

        contactValue = channel.sanitizeContact(value)
    }

    mutating func setContactValue(_ value: String) {
        guard !isAuthoritativeContact else {
            return
        }

        contactValue = channel.sanitizeContact(value)
        serverErrorMessage = nil
    }

    mutating func setOTPCode(_ value: String) {
        otpCode = Self.sanitizedOTPCode(value, length: channel.otpLength)
        if !otpCode.isEmpty {
            isOTPTouched = true
        }
        serverErrorMessage = nil
    }

    mutating func markContactTouched() {
        isContactTouched = true
    }

    mutating func markOTPTouched() {
        if hasSentCode {
            isOTPTouched = true
        }
    }

    mutating func beginSendingCode() {
        isContactTouched = true

        guard canSendCode else {
            return
        }

        isSendingCode = true
    }

    mutating func completeSendingCode(resendAfterSeconds: Int = 30) {
        isSendingCode = false
        hasSentCode = true
        isVerified = false
        otpCode = ""
        isOTPTouched = false
        countdownRemaining = max(resendAfterSeconds, 0)
        serverErrorMessage = nil
    }

    mutating func applyAuthoritativeRecovery(
        maskedContact: String,
        isVerified: Bool,
        resendAvailableAt: Date?,
        now: Date
    ) {
        contactValue = maskedContact
        otpCode = ""
        serverErrorMessage = nil
        isContactTouched = false
        isOTPTouched = false
        isSendingCode = false
        isVerifying = false
        self.isVerified = isVerified
        isAuthoritativeContact = true
        hasSentCode = !isVerified && resendAvailableAt != nil

        if let resendAvailableAt, !isVerified {
            countdownRemaining = max(
                Int(ceil(resendAvailableAt.timeIntervalSince(now))),
                0
            )
        } else {
            countdownRemaining = 0
        }
    }

    mutating func failSendingCode(message: String) {
        isSendingCode = false
        serverErrorMessage = message
    }

    mutating func tickCountdown() {
        guard countdownRemaining > 0 else {
            return
        }

        countdownRemaining -= 1
    }

    mutating func beginVerification() {
        isOTPTouched = true

        guard canVerify else {
            return
        }

        isVerifying = true
    }

    mutating func completeVerification() {
        isVerifying = false
        isVerified = true
        countdownRemaining = 0
        serverErrorMessage = nil
    }

    mutating func failVerification(message: String) {
        isVerifying = false
        serverErrorMessage = message
    }

    mutating func resetForContactChange() {
        otpCode = ""
        isOTPTouched = false
        hasSentCode = false
        isSendingCode = false
        isVerifying = false
        isVerified = false
        countdownRemaining = 0
        serverErrorMessage = nil
    }

    static func sanitizedOTPCode(_ value: String, length: Int = 6) -> String {
        String(value.filter(\.isNumber).prefix(length))
    }
}
