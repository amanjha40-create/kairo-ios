import SwiftUI

/// Opt-in local-development QA only; all services below are in-memory and have
/// no transport, credentials, Keychain, file bytes, or provider implementation.
struct LocalBatch3EvidenceQA: View {
    private let mode = ProcessInfo.processInfo.environment["KAIRO_BATCH3_SURFACE"] ?? "employment"
    @State private var service = LocalBatch3Documents()
    @StateObject private var digiLocker = DigiLockerStore(service: LocalBatch3DigiLocker())

    var body: some View {
        Group {
            if mode.hasPrefix("digilocker") {
                DigiLockerHubView().environmentObject(digiLocker)
            } else if mode == "educationVerification" {
                VerificationInitiationSheet(service: LocalBatch3Verification(), preset: .education(id: "synthetic")) { _ in }
            } else {
                CareerDocumentsView(presentation: .init(parent: parent),
                    syntheticSelection: URL(fileURLWithPath: "/synthetic-evidence.pdf"))
                    .environment(\.careerDocumentService, service)
            }
        }
    }
    private var parent: CareerDocumentParent {
        switch mode {
        case "certification": .certification(id: "synthetic", title: "Synthetic certification")
        case "education": .education(id: "synthetic", title: "Synthetic institution")
        default: .employment(id: "synthetic", title: "Synthetic employer", canUpload: true, canDelete: true)
        }
    }
}

private actor LocalBatch3DigiLocker: DigiLockerServiceProtocol {
    private let mode = ProcessInfo.processInfo.environment["KAIRO_BATCH3_SURFACE"] ?? "digilocker"
    func status() async throws -> DigiLockerStatusDTO {
        if mode == "digilockerError" { throw DigiLockerServiceError.invalidResponse }
        return .init(connected: mode == "digilockerConnected", status: mode == "digilockerConnected" ? .active : .disconnected)
    }
    func connect() async throws -> DigiLockerConnectResponseDTO { throw DigiLockerServiceError.invalidResponse }
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO { .init(items: []) }
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO { .init(items: [], identityVerified: false) }
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO { .init(state: .unverified, sources: []) }
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO { throw NetworkError.unavailableInDemoMode }
    func aadhaarAvailability() async throws -> DigiLockerAadhaarAvailabilityDTO { .init(available: false) }
}

private actor LocalBatch3Documents: CareerDocumentServiceProtocol {
    private var attempts = 0
    private var replaced = false
    func listDocuments(for parent: CareerDocumentParent) async throws -> [CareerDocument] {
        if parent.hasSingleAttachment { return [document("certificate", .primary)] }
        if case .education = parent { return [document("education", nil)] }
        return [document("primary", .primary), document("supporting", .supporting), document("legacy", nil)]
            + (replaced ? [document("new", .primary)] : [])
    }
    private func document(_ id: String, _ role: EmploymentEvidenceRole?) -> CareerDocument {
        .init(id: id, documentType: "other", originalFilename: "synthetic-\(id).pdf", contentType: "application/pdf",
            byteSize: 120, verificationStatus: "pending_review", evidenceRole: role, checksumSha256: String(repeating: "a", count: 64))
    }
    func employmentEligibility(id: String) async throws -> EmploymentEvidenceEligibility {
        .init(eligiblePrimaryCount: replaced ? 2 : 1, minimumRequired: 2, eligible: replaced)
    }
    nonisolated func documentTypes(for parent: CareerDocumentParent) -> [CareerDocumentType] {
        if parent.hasSingleAttachment { return [.init(id: "certificate", label: "Certificate")] }
        if case .education = parent { return [.init(id: "transcript", label: "Transcript"), .init(id: "other", label: "Other")] }
        return [.init(id: "offer_letter", label: "Offer letter"), .init(id: "other", label: "Other"),
                .init(id: "bank_statement", label: "Bank statement"), .init(id: "government_id", label: "Government ID")]
    }
    func uploadDocument(fileURL: URL, documentType: String, to parent: CareerDocumentParent) async throws -> [CareerDocument] {
        attempts += 1
        try await Task.sleep(for: .seconds(1))
        if attempts == 1 { throw CareerDocumentServiceError.storageUploadFailed }
        replaced = true
        return try await listDocuments(for: parent)
    }
    func downloadURL(for document: CareerDocument, parent: CareerDocumentParent) async throws -> URL { throw NetworkError.unavailableInDemoMode }
    func deleteDocument(_ document: CareerDocument, parent: CareerDocumentParent) async throws -> [CareerDocument] { throw NetworkError.unavailableInDemoMode }
}

private actor LocalBatch3Verification: VerificationInitiationServiceProtocol {
    func loadEligibility() async throws -> VerificationInitiationEligibility {
        .init(subjects: [.init(id: "synthetic", kind: .education, title: "Synthetic institution", subtitle: "Synthetic degree",
            verificationStatus: .notVerified, hasActiveRequest: false)])
    }
    func loadEvidence(for subject: VerificationInitiationSubject) async throws -> [VerificationEvidenceDocument] {
        [.init(id: "synthetic", documentType: "transcript", filename: "synthetic-transcript.pdf", isUploadComplete: true)]
    }
    func submit(_ draft: VerificationInitiationDraft) async throws -> VerificationInitiationResult { throw NetworkError.unavailableInDemoMode }
}
