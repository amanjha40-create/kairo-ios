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

    var selectedDocuments: [VerificationEvidenceDocument] {
        documents.filter { selectedDocumentIDs.contains($0.id) }
    }

    var canSubmit: Bool {
        !selectedDocuments.isEmpty
            && Self.looksLikeEmail(contactEmail)
            && consentsToClaimFields
            && consentsToEvidence
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

nonisolated struct VerificationInitiationResult: Equatable, Sendable {
    let requestID: String
    let status: VerifyVerificationStatus
    let reusedExistingRequest: Bool
}

nonisolated enum VerificationInitiationServiceError: Error, Equatable, LocalizedError, Sendable {
    case noEligibleSubject
    case noCompletedEvidence
    case missingRequestIdentifier
    case unsupportedSubject

    var errorDescription: String? {
        switch self {
        case .noEligibleSubject:
            "No eligible employment or education record is available."
        case .noCompletedEvidence:
            "Add and finish uploading at least one supporting document before requesting verification."
        case .missingRequestIdentifier:
            "The server created a request without a usable identifier. Refresh Verify before retrying."
        case .unsupportedSubject:
            "The current backend supports employment and education verification only."
        }
    }
}
