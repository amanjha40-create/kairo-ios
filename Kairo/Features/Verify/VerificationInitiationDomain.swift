import Foundation

nonisolated enum VerificationInitiationKind: String, CaseIterable, Equatable, Sendable {
    case employment
    case education

    var title: String {
        switch self {
        case .employment: "Employment"
        case .education: "Education"
        }
    }

    var contactHeading: String { self == .education ? "Institution contact" : "Employer contact" }
    var contactEmailPrompt: String { self == .education ? "registrar@institution.edu" : "hr@organisation.com" }
    var contactRolePrompt: String { self == .education ? "Registrar or authorised representative" : "HR manager" }
    var contactTypes: [VerificationContactType] {
        self == .education ? [.authorizedRepresentative, .other] : VerificationContactType.allCases
    }
    var workflowDescription: String {
        self == .education
            ? "Request review of your institution, qualification and study dates. Add an institution contact and select education evidence. KairoID reviews the request before institution verification; sending it does not mark your education verified."
            : "Request review of your employer, role and employment dates. Select at least two completed primary documents and provide an employer contact. KairoID reviews the request before organisation verification."
    }
}

nonisolated struct VerificationInitiationSubject: Identifiable, Equatable, Sendable {
    let id: String
    let kind: VerificationInitiationKind
    let title: String
    let subtitle: String
    let verificationStatus: CareerRecordVerificationStatus
    let hasActiveRequest: Bool

    var isEligible: Bool {
        verificationStatus == .notVerified && !hasActiveRequest
    }

    var eligibilityMessage: String? {
        if verificationStatus == .unavailable { return "Status unavailable" }
        if verificationStatus == .verified {
            return "Already verified"
        }
        if verificationStatus == .pending || hasActiveRequest {
            return "Verification already in progress"
        }
        return nil
    }
}

nonisolated struct VerificationInitiationPreset: Identifiable, Equatable, Sendable {
    let kind: VerificationInitiationKind
    let subjectID: String?

    var id: String { "\(kind.rawValue).\(subjectID ?? "any")" }

    static func employment(id: String? = nil) -> Self {
        .init(kind: .employment, subjectID: id)
    }

    static func education(id: String? = nil) -> Self {
        .init(kind: .education, subjectID: id)
    }
}

nonisolated struct VerificationInitiationEligibility: Equatable, Sendable {
    let subjects: [VerificationInitiationSubject]

    var eligibleSubjects: [VerificationInitiationSubject] {
        subjects.filter(\.isEligible)
    }

    func subject(matching preset: VerificationInitiationPreset) -> VerificationInitiationSubject? {
        if let subjectID = preset.subjectID {
            return subjects.first { $0.kind == preset.kind && $0.id == subjectID }
        }
        return eligibleSubjects.first { $0.kind == preset.kind }
    }
}

nonisolated struct VerificationEvidenceDocument: Identifiable, Equatable, Sendable {
    let id: String
    let documentType: String
    let filename: String
    let isUploadComplete: Bool
    var evidenceRole: EmploymentEvidenceRole? = nil
    var requiresCompletionValidation = false

    var displayType: String {
        documentType
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

nonisolated enum VerificationContactType: String, CaseIterable, Equatable, Sendable {
    case hr
    case manager
    case founder
    case authorizedRepresentative = "authorized_representative"
    case other

    var title: String {
        switch self {
        case .hr: "HR"
        case .manager: "Manager"
        case .founder: "Founder"
        case .authorizedRepresentative: "Authorised representative"
        case .other: "Other"
        }
    }
}

nonisolated struct VerificationInitiationDraft: Equatable, Sendable {
    let subject: VerificationInitiationSubject
    var documents: [VerificationEvidenceDocument]
    var selectedDocumentIDs: Set<String> = []
    var contactName = ""
    var contactEmail = ""
    var contactRole = ""
    var contactType: VerificationContactType = .hr
    var candidateNote = ""
    var consentsToClaimFields = false
    var consentsToEvidence = false
    var employmentEligibility: EmploymentEvidenceEligibility? = nil

    var selectedPrimaryCount: Int {
        Set(selectedDocuments.filter { $0.isUploadComplete && $0.evidenceRole == .primary }.map(\.id)).count
    }

    var evidenceGroups: [VerificationEvidenceGroup] {
        guard subject.kind == .employment else { return [.init(title: "Education documents", documents: documents)] }
        return [
            .init(title: "Primary evidence — at least two required", documents: documents.filter { $0.evidenceRole == .primary }),
            .init(title: "Supporting evidence — optional", documents: documents.filter { $0.evidenceRole == .supporting }),
            .init(title: "Unclassified evidence — not counted", documents: documents.filter { $0.evidenceRole == nil })
        ].filter { !$0.documents.isEmpty }
    }

    var selectedDocuments: [VerificationEvidenceDocument] {
        documents.filter { selectedDocumentIDs.contains($0.id) }
    }

    var canSubmit: Bool {
        evidenceReady
            && Self.looksLikeEmail(contactEmail)
            && consentsToClaimFields
            && consentsToEvidence
    }

    var evidenceReady: Bool {
        guard selectedDocuments.count <= 20 else { return false }
        let completed = selectedDocuments.filter(\.isUploadComplete)
        if subject.kind == .education {
            return !selectedDocuments.isEmpty && selectedDocuments.allSatisfy {
                $0.isUploadComplete || $0.requiresCompletionValidation
            }
        }
        let primaryIDs = Set(completed.filter { $0.evidenceRole == .primary }.map(\.id))
        return employmentEligibility?.canContinue == true && primaryIDs.count >= 2
    }

    var consentedFields: [String] {
        switch subject.kind {
        case .employment:
            [
                "employment.employer_name",
                "employment.role",
                "employment.start_date",
                "employment.end_date",
                "employment.employment_type",
                "employment.work_location_country",
                "employment.work_location_region"
            ]
        case .education:
            [
                "education.institution_name",
                "education.degree",
                "education.field_of_study",
                "education.start_date",
                "education.end_date"
            ]
        }
    }

    var consentedEvidenceScope: [String] {
        Array(Set(selectedDocuments.map(\.documentType))).sorted()
    }

    private static func looksLikeEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
    }
}

nonisolated struct VerificationEvidenceGroup: Identifiable, Equatable, Sendable {
    let title: String
    let documents: [VerificationEvidenceDocument]
    var id: String { title }
}

nonisolated struct VerificationInitiationResult: Equatable, Sendable {
    let requestID: String
    let status: VerifyVerificationStatus
    let reusedExistingRequest: Bool
}

nonisolated enum VerificationInitiationServiceError: Error, Equatable, LocalizedError, Sendable {
    case noEligibleSubject
    case noCompletedEvidence
    case insufficientPrimaryEvidence
    case missingRequestIdentifier
    case unsupportedSubject

    var errorDescription: String? {
        switch self {
        case .noEligibleSubject:
            "No eligible employment or education record is available."
        case .noCompletedEvidence:
            "Add and finish uploading at least one supporting document before requesting verification."
        case .insufficientPrimaryEvidence:
            "Add and select at least two distinct completed primary employment documents. Supporting and unclassified legacy files do not count."
        case .missingRequestIdentifier:
            "The server created a request without a usable identifier. Refresh Verify before retrying."
        case .unsupportedSubject:
            "The current backend supports employment and education verification only."
        }
    }
}
