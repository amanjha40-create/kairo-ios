import SwiftUI

struct CreateAccountScreenView: View {
    private let indianMobileGuidance = "For this MVP, enter a 10-digit Indian mobile number."

    @Binding var draft: CreateAccountDraft
    let onContinue: (() -> Void)?

    @EnvironmentObject private var router: AppRouter
    @FocusState private var focusedField: CreateAccountField?
    @State private var touchedFields: Set<CreateAccountField>
    @State private var lastFocusedField: CreateAccountField?
    @State private var presentedLegalDocument: LegalDocument?

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
            eyebrow: "Set up your profile",
            title: "Create your account",
            subtitle: "Start building your portable professional trust profile.",
            titleAccessibilityIdentifier: OnboardingStep.createAccount.titleAccessibilityIdentifier
        ) {
            CreateAccountHero()
                .frame(maxWidth: 168)
        } content: {
            KairoCard {
                VStack(spacing: KairoSpacing.medium) {
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
                        submitLabel: .done,
                        focus: $focusedField,
                        focusedField: .mobileNumber,
                        onSubmit: {
                            touch(.mobileNumber)
                            focusedField = nil
                        }
                    )

                    Text(indianMobileGuidance)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(indianMobileGuidance)
                }
            }
        } actions: {
            VStack(spacing: KairoSpacing.medium) {
                KairoPrimaryButton(
                    title: "Continue",
                    accessibilityIdentifier: KairoAccessibilityID.createAccountContinue,
                    action: handleContinue
                )
                .disabled(!isFormValid)

                KairoSecondaryButton(
                    title: "I already have an account",
                    accessibilityIdentifier: KairoAccessibilityID.createAccountLogin,
                    action: { router.showLoginPlaceholder() }
                )

                legalCopy
            }
            .accessibilityElement(children: .contain)
        }
        .toolbar {
            if let focusedField {
                ToolbarItemGroup(placement: .keyboard) {
                    if let previousField = focusedField.previous {
                        Button("Previous") {
                            touch(focusedField)
                            self.focusedField = previousField
                        }
                    }

                    Spacer()

                    Button(focusedField == .mobileNumber ? "Done" : "Next") {
                        moveFocusForward(from: focusedField)
                    }
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            handleOpenURL(url)
        })
        .onChange(of: focusedField) { _, newValue in
            if let lastFocusedField, lastFocusedField != newValue {
                touch(lastFocusedField)
            }

            lastFocusedField = newValue
        }
        .onChange(of: draft.mobileNumber) { _, newValue in
            let sanitizedValue = CreateAccountValidation.sanitizedMobileNumber(newValue)
            if sanitizedValue != newValue {
                draft.mobileNumber = sanitizedValue
            }
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

    private func errorMessage(for field: CreateAccountField) -> String? {
        guard touchedFields.contains(field) else {
            return nil
        }

        return CreateAccountValidation.errorMessage(for: field, in: draft)
    }

    private func touch(_ field: CreateAccountField) {
        touchedFields.insert(field)
    }

    private func moveFocusForward(from field: CreateAccountField) {
        touch(field)

        if let nextField = field.next {
            focusedField = nextField
        } else {
            focusedField = nil
        }
    }

    private func handleContinue() {
        if let onContinue {
            onContinue()
        } else {
            router.advanceOnboarding(from: .createAccount)
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
}

private struct CreateAccountHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                .fill(KairoColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                        .stroke(KairoColors.border, lineWidth: 1)
                )
                .kairoShadow(KairoShadow.card)

            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                        Text("Kairo")
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textSecondary)

                        Text("Candidate")
                            .font(KairoTypography.title2)
                            .foregroundStyle(KairoColors.textPrimary)
                    }

                    Spacer()

                    Circle()
                        .fill(KairoColors.brandPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(KairoColors.brandPrimary)
                        )
                }

                VStack(alignment: .leading, spacing: KairoSpacing.small) {
                    Capsule()
                        .fill(KairoColors.textPrimary.opacity(0.12))
                        .frame(width: 132, height: 10)

                    Capsule()
                        .fill(KairoColors.textPrimary.opacity(0.08))
                        .frame(width: 108, height: 10)

                    HStack(spacing: KairoSpacing.small) {
                        Label("Secure setup", systemImage: "checkmark.shield")
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.brandPrimary)
                            .padding(.horizontal, KairoSpacing.small)
                            .padding(.vertical, KairoSpacing.xSmall)
                            .background(KairoColors.brandPrimary.opacity(0.1), in: Capsule())

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(KairoSpacing.large)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.1, contentMode: .fit)
        .accessibilityHidden(true)
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
