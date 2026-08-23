import SwiftUI

struct CreateAccountScreenView: View {
    @Binding var draft: CreateAccountDraft
    let onContinue: (() -> Void)?

    @Environment(\.authService) private var authService
    @EnvironmentObject private var router: AppRouter
    @FocusState private var focusedField: CreateAccountField?
    @State private var touchedFields: Set<CreateAccountField>
    @State private var lastFocusedField: CreateAccountField?
    @State private var presentedLegalDocument: LegalDocument?
    @State private var isSubmitting = false
    @State private var backendFieldErrors: [CreateAccountField: String] = [:]
    @State private var submissionErrorMessage: String?

    init(
        draft: Binding<CreateAccountDraft>,
        initialTouchedFields: Set<CreateAccountField> = [],
        onContinue: (() -> Void)? = nil
    ) {
        _draft = draft
        _touchedFields = State(initialValue: initialTouchedFields)
        self.onContinue = onContinue
    }

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Create your Kairo account",
            title: "Create your account",
            subtitle: "Start building your Trust Passport.",
            titleAccessibilityIdentifier: OnboardingStep.createAccount.titleAccessibilityIdentifier,
            topPaddingAdjustment: -KairoSpacing.xLarge
        ) {
            EmptyView()
        } content: {
            createAccountFormCard
        } actions: {
            actionsSection
        }
        .environment(\.openURL, OpenURLAction { url in
            handleOpenURL(url)
        })
        .onChange(of: focusedField) { _, newValue in
            handleFocusedFieldChange(newValue)
        }
        .onChange(of: draft.mobileNumber) { _, newValue in
            sanitizeMobileNumber(newValue)
        }
        .onChange(of: draft.firstName) { _, _ in
            handleNameFieldChange()
        }
        .onChange(of: draft.lastName) { _, _ in
            handleNameFieldChange()
        }
        .onChange(of: draft.emailAddress) { _, _ in
            handleEmailFieldChange()
        }
        .onChange(of: draft.mobileNumber) { _, _ in
            handleMobileFieldChange()
        }
        .onChange(of: draft.password) { _, _ in
            handlePasswordFieldChange()
        }
        .sheet(item: $presentedLegalDocument) { document in
            LegalDocumentPlaceholderSheet(document: document)
        }
    }

    private var isFormValid: Bool {
        CreateAccountValidation.isFormValid(draft)
    }

    private var legalCopy: some View {
        Text(.init("By continuing you agree to Kairo's [Terms of Service](kairo://terms) and [Privacy Policy](kairo://privacy)."))
            .font(KairoTypography.footnote)
            .foregroundStyle(KairoColors.textSecondary)
            .multilineTextAlignment(.center)
            .tint(KairoColors.brandPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var createAccountFormCard: some View {
        KairoCard {
            createAccountFields
        }
    }

    private var createAccountFields: some View {
        VStack(spacing: KairoSpacing.small) {
            firstNameField
            lastNameField
            emailField
            mobileField
            passwordField
        }
    }

    private var firstNameField: some View {
        KairoTextField(
            title: "First Name",
            prompt: "Enter your first name",
            text: $draft.firstName,
            errorMessage: errorMessage(for: .firstName),
            accessibilityIdentifier: KairoAccessibilityID.createAccountFirstName,
            accessibilityLabel: "First name",
            textContentType: .givenName,
            textInputAutocapitalization: .words,
            submitLabel: .next,
            focus: $focusedField,
            focusedField: .firstName,
            onSubmit: { moveFocusForward(from: .firstName) }
        )
    }

    private var lastNameField: some View {
        KairoTextField(
            title: "Last Name",
            prompt: "Enter your last name",
            text: $draft.lastName,
            errorMessage: errorMessage(for: .lastName),
            accessibilityIdentifier: KairoAccessibilityID.createAccountLastName,
            accessibilityLabel: "Last name",
            textContentType: .familyName,
            textInputAutocapitalization: .words,
            submitLabel: .next,
            focus: $focusedField,
            focusedField: .lastName,
            onSubmit: { moveFocusForward(from: .lastName) }
        )
    }

    private var emailField: some View {
        KairoTextField(
            title: "Email Address",
            prompt: "name@example.com",
            text: $draft.emailAddress,
            errorMessage: errorMessage(for: .emailAddress),
            accessibilityIdentifier: KairoAccessibilityID.createAccountEmail,
            accessibilityLabel: "Email address",
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            textInputAutocapitalization: .never,
            submitLabel: .next,
            focus: $focusedField,
            focusedField: .emailAddress,
            onSubmit: { moveFocusForward(from: .emailAddress) }
        )
    }

    private var mobileField: some View {
        KairoTextField(
            title: "Mobile Number",
            prompt: "10-digit Indian mobile number",
            text: $draft.mobileNumber,
            errorMessage: errorMessage(for: .mobileNumber),
            accessibilityIdentifier: KairoAccessibilityID.createAccountMobile,
            accessibilityLabel: "Mobile number",
            accessibilityHint: "Enter a 10-digit Indian mobile number.",
            keyboardType: .phonePad,
            textContentType: .telephoneNumber,
            textInputAutocapitalization: .never,
            submitLabel: .next,
            focus: $focusedField,
            focusedField: .mobileNumber,
            onSubmit: { moveFocusForward(from: .mobileNumber) }
        )
    }

    private var passwordField: some View {
        KairoTextField(
            title: "Password",
            prompt: "At least 12 characters",
            text: $draft.password,
            errorMessage: errorMessage(for: .password),
            accessibilityIdentifier: KairoAccessibilityID.createAccountPassword,
            accessibilityLabel: "Password",
            accessibilityHint: "Enter a password with at least 12 characters.",
            textContentType: .newPassword,
            textInputAutocapitalization: .never,
            isSecure: true,
            submitLabel: .done,
            focus: $focusedField,
            focusedField: .password,
            onSubmit: handlePasswordSubmit
        )
    }

    private var actionsSection: some View {
        VStack(spacing: KairoSpacing.medium) {
            KairoPrimaryButton(
                title: "Create Account",
                isLoading: isSubmitting,
                accessibilityIdentifier: KairoAccessibilityID.createAccountContinue,
                action: handleContinue
            )
            .disabled(!isFormValid || isSubmitting)

            loginRow
                .disabled(isSubmitting)

            legalCopy

            submissionErrorView
        }
        .accessibilityElement(children: .contain)
    }

    private var loginRow: some View {
        HStack(spacing: KairoSpacing.xxSmall) {
            Text("Already have an account?")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            Button("Log in") {
                router.showLogin()
            }
            .font(KairoTypography.footnote.weight(.semibold))
            .foregroundStyle(KairoColors.brandPrimary)
            .buttonStyle(.plain)
            .accessibilityIdentifier(KairoAccessibilityID.createAccountLogin)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var submissionErrorView: some View {
        if let submissionErrorMessage {
            Text(submissionErrorMessage)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.danger)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorMessage(for field: CreateAccountField) -> String? {
        guard touchedFields.contains(field) else {
            return nil
        }

        if let localError = CreateAccountValidation.errorMessage(for: field, in: draft) {
            return localError
        }

        return backendFieldErrors[field]
    }

    private func touch(_ field: CreateAccountField) {
        touchedFields.insert(field)
    }

    private func handleFocusedFieldChange(_ newValue: CreateAccountField?) {
        if let lastFocusedField, lastFocusedField != newValue {
            touch(lastFocusedField)
        }

        lastFocusedField = newValue
    }

    private func handleNameFieldChange() {
        submissionErrorMessage = nil
        clearBackendErrors(for: [.firstName, .lastName])
    }

    private func handleEmailFieldChange() {
        submissionErrorMessage = nil
        clearBackendErrors(for: [.emailAddress])
    }

    private func handleMobileFieldChange() {
        submissionErrorMessage = nil
        clearBackendErrors(for: [.mobileNumber])
    }

    private func handlePasswordFieldChange() {
        submissionErrorMessage = nil
        clearBackendErrors(for: [.password])
    }

    private func sanitizeMobileNumber(_ newValue: String) {
        let sanitizedValue = CreateAccountValidation.sanitizedMobileNumber(newValue)

        if sanitizedValue != newValue {
            draft.mobileNumber = sanitizedValue
        }
    }

    private func moveFocusForward(from field: CreateAccountField) {
        touch(field)

        if let nextField = field.next {
            focusedField = nextField
        } else {
            focusedField = nil
        }
    }

    private func handlePasswordSubmit() {
        touch(.password)
        focusedField = nil
    }

    private func handleContinue() {
        touchedFields.formUnion(CreateAccountField.allCases)
        guard isFormValid, !isSubmitting else {
            return
        }

        backendFieldErrors = [:]
        submissionErrorMessage = nil
        isSubmitting = true

        guard let phone = CreateAccountValidation.e164PhoneNumber(draft.mobileNumber) else {
            isSubmitting = false
            touchedFields.insert(.mobileNumber)
            return
        }

        let request = RegisterRequestDTO(
            fullName: CreateAccountValidation.normalizedFullName(
                firstName: draft.firstName,
                lastName: draft.lastName
            ),
            email: CreateAccountValidation.normalizedEmail(draft.emailAddress),
            phone: phone,
            password: draft.password
        )

        Task {
            do {
                _ = try await authService.signupStart(request)
                await MainActor.run {
                    isSubmitting = false

                    if let onContinue {
                        onContinue()
                    } else {
                        router.advanceOnboarding(from: .createAccount)
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    applySubmissionError(error)
                }
            }
        }
    }

    private func clearBackendErrors(for fields: [CreateAccountField]) {
        for field in fields {
            backendFieldErrors.removeValue(forKey: field)
        }
    }

    private func applySubmissionError(_ error: Error) {
        switch error {
        case let networkError as NetworkError:
            guard case .api(let apiError) = networkError else {
                submissionErrorMessage = authenticationMessage(for: error)
                return
            }

            if apiError.code == .validationError {
                let mappedErrors = mapBackendFieldErrors(apiError.fieldErrors)
                backendFieldErrors = mappedErrors
                touchedFields.formUnion(mappedErrors.keys)
                submissionErrorMessage = apiError.globalErrors.first
                    ?? (mappedErrors.isEmpty ? apiError.message : nil)
                return
            }

            submissionErrorMessage = authenticationMessage(for: error)
        default:
            submissionErrorMessage = authenticationMessage(for: error)
        }
    }

    private func mapBackendFieldErrors(_ fieldErrors: [String: [String]]) -> [CreateAccountField: String] {
        var mappedErrors: [CreateAccountField: String] = [:]

        for (fieldName, messages) in fieldErrors {
            guard let message = messages.first else {
                continue
            }

            for field in mappedFields(for: fieldName) {
                mappedErrors[field] = message
            }
        }

        return mappedErrors
    }

    private func mappedFields(for backendFieldName: String) -> [CreateAccountField] {
        switch backendFieldName {
        case "email":
            [.emailAddress]
        case "phone", "mobile", "mobile_number":
            [.mobileNumber]
        case "password":
            [.password]
        case "full_name", "fullName", "name":
            [.firstName, .lastName]
        default:
            []
        }
    }

    private func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        switch url.host {
        case "terms":
            presentedLegalDocument = .termsOfService
            return .handled
        case "privacy":
            presentedLegalDocument = .privacyPolicy
            return .handled
        default:
            return .systemAction
        }
    }

    private func authenticationMessage(for error: Error) -> String {
        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .api(let apiError):
                switch apiError.code {
                case .conflict:
                    return "An account with these details already exists. Try signing in instead."
                case .validationError:
                    return apiError.globalErrors.first ?? apiError.message
                case .rateLimited:
                    return "Too many attempts. Please try again shortly."
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
                return "Demo Mode keeps account creation local only."
            }
        default:
            return error.localizedDescription
        }
    }
}

private enum LegalDocument: String, Identifiable {
    case termsOfService
    case privacyPolicy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .termsOfService:
            "Terms of Service"
        case .privacyPolicy:
            "Privacy Policy"
        }
    }

    var message: String {
        switch self {
        case .termsOfService:
            "Kairo's Terms of Service content will be connected in a later milestone."
        case .privacyPolicy:
            "Kairo's Privacy Policy content will be connected in a later milestone."
        }
    }
}

private struct LegalDocumentPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let document: LegalDocument

    var body: some View {
        NavigationStack {
            KairoCard {
                Text(document.title)
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                Text(document.message)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(KairoSpacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
