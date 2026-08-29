import SwiftUI
import Combine

@MainActor
final class VerificationInitiationViewModel: ObservableObject {
    @Published private(set) var eligibility: VerificationInitiationEligibility?
    @Published var selectedSubjectID: String?
    @Published var draft: VerificationInitiationDraft?
    @Published private(set) var result: VerificationInitiationResult?
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var error: VerificationInitiationPresentationError?

    private let service: any VerificationInitiationServiceProtocol
    private let preset: VerificationInitiationPreset?
    private var hasLoaded = false

    init(
        service: any VerificationInitiationServiceProtocol,
        preset: VerificationInitiationPreset?
    ) {
        self.service = service
        self.preset = preset
    }

    var selectedSubject: VerificationInitiationSubject? {
        eligibility?.subjects.first { $0.id == selectedSubjectID }
    }

    var canContinue: Bool {
        selectedSubject?.isEligible == true && !isLoading
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await service.loadEligibility()
            eligibility = loaded

            if let preset, let subject = loaded.subject(matching: preset) {
                selectedSubjectID = subject.id
                if subject.isEligible {
                    await loadEvidenceForSelection()
                } else {
                    error = VerificationInitiationPresentationError(
                        title: "Verification unavailable",
                        message: subject.eligibilityMessage ?? "This record cannot start verification."
                    )
                }
            }
        } catch {
            self.error = .map(error, fallbackTitle: "Verification unavailable")
        }
    }

    func loadEvidenceForSelection() async {
        guard let subject = selectedSubject, subject.isEligible else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let documents = try await service.loadEvidence(for: subject)
            draft = VerificationInitiationDraft(subject: subject, documents: documents)
        } catch {
            self.error = .map(error, fallbackTitle: "Evidence required")
        }
    }

    func toggleDocument(_ id: String) {
        guard var draft else { return }
        if draft.selectedDocumentIDs.contains(id) {
            draft.selectedDocumentIDs.remove(id)
        } else {
            draft.selectedDocumentIDs.insert(id)
        }
        self.draft = draft
    }

    func submit() async {
        guard let draft, draft.canSubmit, !isSubmitting else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        do {
            result = try await service.submit(draft)
        } catch {
            self.error = .map(error, fallbackTitle: "Request not sent")
        }
    }
}

struct VerificationInitiationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: VerificationInitiationViewModel
    private let onSuccess: (String) -> Void

    init(
        service: any VerificationInitiationServiceProtocol,
        preset: VerificationInitiationPreset? = nil,
        onSuccess: @escaping (String) -> Void
    ) {
        _model = StateObject(
            wrappedValue: VerificationInitiationViewModel(service: service, preset: preset)
        )
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    content
                }
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Start verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .disabled(model.isSubmitting)
                }
            }
        }
        .task { await model.load() }
        .alert(item: $model.error) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .accessibilityIdentifier(KairoAccessibilityID.verifyStartVerificationSheet)
        .presentationDetents([.large])
        .interactiveDismissDisabled(model.isSubmitting)
    }

    @ViewBuilder
    private var content: some View {
        if let result = model.result {
            successContent(result)
        } else if let draft = Binding($model.draft) {
            detailsContent(draft)
        } else if model.isLoading && model.eligibility == nil {
            KairoLoadingStateView(
                title: "Checking eligible records",
                message: "Kairo is checking your live Career records and active requests."
            )
        } else {
            selectionContent
        }
    }

    private var selectionContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoCard {
                Text("Choose a Career record")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("Employment and education are supported by the current verification backend. Record status and duplicate checks come from Kairo before submission.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let subjects = model.eligibility?.subjects, !subjects.isEmpty {
                ForEach(subjects) { subject in
                    Button {
                        model.selectedSubjectID = subject.id
                    } label: {
                        HStack(alignment: .top, spacing: KairoSpacing.medium) {
                            Image(systemName: subject.kind == .employment ? "building.2" : "graduationcap")
                                .foregroundStyle(subject.isEligible ? KairoColors.brandPrimary : KairoColors.textSecondary)

                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                Text(subject.title)
                                    .font(KairoTypography.bodyStrong)
                                    .foregroundStyle(KairoColors.textPrimary)
                                Text(subject.subtitle)
                                    .font(KairoTypography.footnote)
                                    .foregroundStyle(KairoColors.textSecondary)
                                if let message = subject.eligibilityMessage {
                                    Text(message)
                                        .font(KairoTypography.caption)
                                        .foregroundStyle(KairoColors.textSecondary)
                                }
                            }

                            Spacer(minLength: KairoSpacing.small)
                            Image(systemName: model.selectedSubjectID == subject.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(subject.isEligible ? KairoColors.brandPrimary : KairoColors.border)
                        }
                        .padding(KairoSpacing.medium)
                        .background(KairoColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                                .stroke(KairoColors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!subject.isEligible)
                    .accessibilityIdentifier(KairoAccessibilityID.verificationInitiationSubject(subject.id))
                }
            } else {
                KairoEmptyStateView(
                    title: "No supported records",
                    message: "Add an employment or education record in Career before starting verification.",
                    systemImage: "doc.badge.plus"
                )
            }

            Text("Certification and project verification initiation is not supported by the current backend and is not offered here.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            KairoPrimaryButton(
                title: model.isLoading ? "Loading evidence…" : "Continue",
                accessibilityIdentifier: KairoAccessibilityID.verificationInitiationContinue,
                action: { Task { await model.loadEvidenceForSelection() } }
            )
            .disabled(!model.canContinue)
        }
    }

    private func detailsContent(_ draft: Binding<VerificationInitiationDraft>) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoCard {
                Text(draft.wrappedValue.subject.kind.title + " verification")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)
                Text(draft.wrappedValue.subject.title)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)
                Text(draft.wrappedValue.subject.subtitle)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
            }

            KairoCard {
                Text("Supporting evidence")
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)
                Text("Select at least one completed document already attached to this Career record.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)

                ForEach(draft.wrappedValue.documents) { document in
                    Button {
                        model.toggleDocument(document.id)
                    } label: {
                        HStack(spacing: KairoSpacing.small) {
                            Image(systemName: draft.wrappedValue.selectedDocumentIDs.contains(document.id) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(KairoColors.brandPrimary)
                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                Text(document.filename)
                                    .font(KairoTypography.bodyStrong)
                                    .foregroundStyle(KairoColors.textPrimary)
                                Text(document.displayType)
                                    .font(KairoTypography.caption)
                                    .foregroundStyle(KairoColors.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(KairoAccessibilityID.verificationInitiationEvidence(document.id))
                }
            }

            KairoCard {
                Text("Verification contact")
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)

                KairoTextField(title: "Contact email", prompt: "hr@organisation.com", text: draft.contactEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                KairoTextField(title: "Contact name (optional)", prompt: "Name", text: draft.contactName)
                KairoTextField(title: "Role (optional)", prompt: "HR manager", text: draft.contactRole)

                Picker("Contact type", selection: draft.contactType) {
                    ForEach(VerificationContactType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.menu)

                KairoTextField(title: "Note (optional)", prompt: "Context for the verifier", text: draft.candidateNote)
            }

            KairoCard {
                Text("Your consent")
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)
                Text("Kairo will share only the selected Career claim fields and selected evidence with the verification workflow. The request first enters Kairo admin review; it is not marked verified by this action.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("I consent to share the record fields shown above", isOn: draft.consentsToClaimFields)
                    .accessibilityIdentifier(KairoAccessibilityID.verificationInitiationClaimConsent)
                Toggle("I consent to share the selected evidence", isOn: draft.consentsToEvidence)
                    .accessibilityIdentifier(KairoAccessibilityID.verificationInitiationEvidenceConsent)
            }

            KairoPrimaryButton(
                title: model.isSubmitting ? "Sending request…" : "Send verification request",
                accessibilityIdentifier: KairoAccessibilityID.verificationInitiationSubmit,
                action: { Task { await model.submit() } }
            )
            .disabled(!draft.wrappedValue.canSubmit || model.isSubmitting)

            KairoSecondaryButton(
                title: "Choose another record",
                action: { model.draft = nil }
            )
            .disabled(model.isSubmitting)
        }
    }

    private func successContent(_ result: VerificationInitiationResult) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoCard {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(KairoColors.success)
                Text("Verification requested")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)
                Text(result.reusedExistingRequest
                    ? "Kairo found the existing request and refreshed its authoritative status."
                    : "Your request was submitted for Kairo review. Career and Verify will refresh from the backend.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            KairoPrimaryButton(
                title: "View request",
                accessibilityIdentifier: KairoAccessibilityID.verificationInitiationViewRequest,
                action: {
                    onSuccess(result.requestID)
                    dismiss()
                }
            )
        }
    }
}

struct VerificationInitiationPresentationError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    static func map(_ error: Error, fallbackTitle: String) -> Self {
        if let serviceError = error as? VerificationInitiationServiceError {
            return .init(title: fallbackTitle, message: serviceError.localizedDescription)
        }
        if let sessionError = error as? SessionServiceError {
            return .init(title: "Sign in required", message: sessionError.localizedDescription)
        }
        if let decodingError = error as? DecodingError {
            return .init(
                title: "Response unavailable",
                message: "Kairo could not read the verification response. No verified status was applied. Retry after refreshing. (\(decodingError.localizedDescription))"
            )
        }
        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError):
                return map(apiError, fallbackTitle: fallbackTitle)
            case .transport(let message) where message.localizedCaseInsensitiveContains("timed out"):
                return .init(title: "Request timed out", message: "The server did not confirm the request. Retry to reconcile with the authoritative backend state.")
            case .transport:
                return .init(title: "Network unavailable", message: "Kairo could not reach the verification service. Check your connection and retry.")
            case .invalidResponse:
                return .init(title: "Invalid response", message: "The server did not return a usable verification response. No verified status was applied.")
            case .invalidURL, .unavailableInDemoMode:
                return .init(title: fallbackTitle, message: networkError.localizedDescription)
            }
        }
        return .init(title: fallbackTitle, message: error.localizedDescription)
    }

    private static func map(_ error: APIError, fallbackTitle: String) -> Self {
        let lowercased = error.message.lowercased()
        if lowercased.contains("organization") && (lowercased.contains("resolve") || lowercased.contains("unresolved")) {
            return .init(title: "Organisation unresolved", message: "Kairo could not resolve this organisation yet. Check the contact and retry later.")
        }
        if lowercased.contains("upload is not complete") || lowercased.contains("completed") && lowercased.contains("evidence") {
            return .init(title: "Evidence upload incomplete", message: "Finish uploading a supporting document, refresh Career, and retry.")
        }

        switch error.statusCode {
        case 400:
            return .init(title: "Request needs attention", message: error.message)
        case 401:
            return .init(title: "Sign in required", message: "Your session expired. Sign in again before retrying.")
        case 403:
            return .init(title: "Request not allowed", message: "This account cannot start verification for the selected record.")
        case 404:
            return .init(title: "Record not found", message: "The Career record or request changed. Refresh and choose it again.")
        case 409:
            return .init(title: "Request already exists", message: "A verification request already exists for this record. Refresh Verify to view its current status.")
        case 422:
            let details = error.fieldErrors
                .sorted(by: { $0.key < $1.key })
                .flatMap { field, messages in messages.map { "\(field): \($0)" } }
                .joined(separator: "\n")
            return .init(title: "Check verification details", message: details.isEmpty ? error.message : details)
        case 429:
            return .init(title: "Too many attempts", message: "Wait a moment before retrying this verification request.")
        case 500...599:
            return .init(title: "Verification service unavailable", message: "The server could not complete the request. Retry to reconcile before making any changes.")
        default:
            return .init(title: fallbackTitle, message: error.message)
        }
    }
}
