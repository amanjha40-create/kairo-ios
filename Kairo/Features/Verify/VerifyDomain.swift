import Foundation

nonisolated struct VerifyOverview: Equatable, Sendable {
    let requests: [VerifyRequestRecord]
}

nonisolated struct VerifyRequestRecord: Identifiable, Equatable, Sendable {
    let id: String
    let routeID: String?
    var subjectIDs: [String] = []
    let kind: VerifyVerificationKind?
    let typeTitle: String
    let organizationName: String
    let requesterName: String
    let requestedItem: String
    let status: VerifyVerificationStatus
    let priority: String
    let dueDate: Date?
    let createdAt: Date
    let updatedAt: Date
    let candidateResponse: String?
    let candidateResponseSubmittedAt: Date?
    let acceptedAt: Date?
    let consentedAt: Date?
    let consentVersion: String?
    let consentedFields: [String]
    let consentedEvidenceScope: [String]
    let reviewStatus: String?
    let evidenceSummary: VerifyEvidenceSummaryRecord
    let verificationContact: VerifyContactRecord?
    let evidence: [VerifyEvidenceRecord]
    let corrections: [VerifyCorrectionRecord]
    let timeline: [VerifyTimelineEventRecord]

    nonisolated init(
        id: String,
        routeID: String?,
        subjectIDs: [String] = [],
        kind: VerifyVerificationKind?,
        typeTitle: String,
        organizationName: String,
        requesterName: String,
        requestedItem: String,
        status: VerifyVerificationStatus,
        priority: String,
        dueDate: Date?,
        createdAt: Date,
        updatedAt: Date,
        candidateResponse: String?,
        candidateResponseSubmittedAt: Date?,
        acceptedAt: Date?,
        consentedAt: Date? = nil,
        consentVersion: String? = nil,
        consentedFields: [String],
        consentedEvidenceScope: [String],
        reviewStatus: String? = nil,
        evidenceSummary: VerifyEvidenceSummaryRecord,
        verificationContact: VerifyContactRecord? = nil,
        evidence: [VerifyEvidenceRecord] = [],
        corrections: [VerifyCorrectionRecord] = [],
        timeline: [VerifyTimelineEventRecord]
    ) {
        self.id = id
        self.routeID = routeID
        self.subjectIDs = subjectIDs
        self.kind = kind
        self.typeTitle = typeTitle
        self.organizationName = organizationName
        self.requesterName = requesterName
        self.requestedItem = requestedItem
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.candidateResponse = candidateResponse
        self.candidateResponseSubmittedAt = candidateResponseSubmittedAt
        self.acceptedAt = acceptedAt
        self.consentedAt = consentedAt
        self.consentVersion = consentVersion
        self.consentedFields = consentedFields
        self.consentedEvidenceScope = consentedEvidenceScope
        self.reviewStatus = reviewStatus
        self.evidenceSummary = evidenceSummary
        self.verificationContact = verificationContact
        self.evidence = evidence
        self.corrections = corrections
        self.timeline = timeline
    }
}

nonisolated struct VerifyEvidenceSummaryRecord: Equatable, Sendable {
    let totalItems: Int
    let documentItems: Int
    let fieldKeys: [String]
}

nonisolated struct VerifyTimelineEventRecord: Identifiable, Equatable, Sendable {
    let id: String
    let eventType: String
    let eventSource: String
    let previousStatus: VerifyVerificationStatus?
    let newStatus: VerifyVerificationStatus?
    let createdAt: Date
}

nonisolated struct VerifyContactRecord: Equatable, Sendable {
    let id: String
    let name: String?
    let email: String
    let role: String?
    let type: String
    let candidateNote: String?
    let reviewStatus: String
    let reviewNotes: String?
    let reviewedAt: Date?
}

nonisolated struct VerifyEvidenceRecord: Identifiable, Equatable, Sendable {
    let id: String
    let evidenceType: String
    let fieldKey: String
    let status: String
    let documentType: String?
    let originalFilename: String?
    let fileSize: Int?
    let uploadStatus: String?
    let downloadURL: URL?
}

nonisolated struct VerifyCorrectionRecord: Identifiable, Equatable, Sendable {
    let id: String
    let fieldKey: String
    let requestText: String
    let guidance: [String]
    let status: String
    let createdAt: Date
}

extension VerifyRequestRecord {
    nonisolated init(
        detail: VerificationRequestResponseDTO,
        fallbackID: String,
        routeIDOverride: String? = nil,
        verificationContact: VerificationContactResponseDTO? = nil,
        evidence: [VerificationEvidenceResponseDTO] = [],
        corrections: [VerificationCorrectionResponseDTO] = [],
        timeline: [VerificationRequestTimelineEventDTO]
    ) {
        let kind = VerifyVerificationKind(rawBackendValue: detail.requestType)
        let typeTitle = kind.map { "\($0.title) verification" } ?? Self.humanizedType(from: detail.requestType)
        let organizationName = Self.organizationName(from: detail)
        let routeID = routeIDOverride ?? detail.routingID

        self.init(
            id: routeID ?? fallbackID,
            routeID: routeID,
            subjectIDs: [detail.employmentID, detail.educationID].compactMap { $0 },
            kind: kind,
            typeTitle: typeTitle,
            organizationName: organizationName,
            requesterName: Self.requesterName(from: detail, fallbackOrganization: organizationName),
            requestedItem: Self.requestedItem(from: detail, kind: kind),
            status: .init(rawBackendValue: detail.status),
            priority: detail.priority,
            dueDate: detail.dueDate,
            createdAt: detail.createdAt,
            updatedAt: detail.updatedAt,
            candidateResponse: detail.candidateResponse,
            candidateResponseSubmittedAt: detail.candidateResponseSubmittedAt,
            acceptedAt: detail.acceptedAt,
            consentedAt: detail.consentedAt,
            consentVersion: detail.consentVersion,
            consentedFields: detail.consentedFields,
            consentedEvidenceScope: detail.consentedEvidenceScope,
            reviewStatus: detail.reviewStatus,
            evidenceSummary: .init(dto: detail.evidenceSummary),
            verificationContact: verificationContact.map(VerifyContactRecord.init(dto:)),
            evidence: evidence.map(VerifyEvidenceRecord.init(dto:)),
            corrections: corrections.map(VerifyCorrectionRecord.init(dto:)),
            timeline: timeline.map(VerifyTimelineEventRecord.init(dto:))
        )
    }

    private nonisolated static func organizationName(from detail: VerificationRequestResponseDTO) -> String {
        if let name = detail.organizationSummary.map(\.name)?.nonEmpty {
            return name
        }

        if let name = detail.verificationTarget?.organizationName?.nonEmpty {
            return name
        }

        if let name = detail.targetOrganizationName?.nonEmpty {
            return name
        }

        return "Organisation unavailable"
    }

    private nonisolated static func requesterName(
        from detail: VerificationRequestResponseDTO,
        fallbackOrganization: String
    ) -> String {
        if let name = detail.organizationSummary.map(\.name)?.nonEmpty {
            return name
        }

        if let name = detail.targetOrganizationName?.nonEmpty {
            return name
        }

        if let name = detail.verificationTarget?.organizationName?.nonEmpty {
            return name
        }

        return fallbackOrganization
    }

    private nonisolated static func requestedItem(
        from detail: VerificationRequestResponseDTO,
        kind: VerifyVerificationKind?
    ) -> String {
        switch kind {
        case .employment:
            let company = detail.employmentClaim?.employerName?.nonEmpty
            let role = detail.employmentClaim?.role?.nonEmpty
            let parts = [role, company].compactMap { $0 }
            if !parts.isEmpty {
                return parts.joined(separator: " at ")
            }
        case .education:
            let degree = detail.educationClaim?.degree?.nonEmpty
            let institution = detail.educationClaim?.institutionName?.nonEmpty
            let parts = [degree, institution].compactMap { $0 }
            if !parts.isEmpty {
                return parts.joined(separator: " at ")
            }
        case .certification:
            if let name = detail.targetOrganizationName?.nonEmpty {
                return name
            }
        case .project:
            break
        case .none:
            break
        }

        return Self.humanizedType(from: detail.requestType)
    }

    private nonisolated static func humanizedType(from rawValue: String) -> String {
        rawValue
            .split(separator: "_")
            .map { token in
                token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

extension VerifyContactRecord {
    nonisolated init(dto: VerificationContactResponseDTO) {
        self.init(
            id: dto.publicID,
            name: dto.contactName,
            email: dto.contactEmail,
            role: dto.contactRole,
            type: dto.contactType,
            candidateNote: dto.candidateNote,
            reviewStatus: dto.reviewStatus,
            reviewNotes: dto.reviewNotes,
            reviewedAt: dto.reviewedAt
        )
    }
}

extension VerifyEvidenceRecord {
    nonisolated init(dto: VerificationEvidenceResponseDTO) {
        let safeDownloadURL: URL?
        if let url = dto.downloadURL, url.scheme?.lowercased() == "https" {
            safeDownloadURL = url
        } else {
            safeDownloadURL = nil
        }
        self.init(
            id: dto.publicID,
            evidenceType: dto.evidenceType,
            fieldKey: dto.fieldKey,
            status: dto.status,
            documentType: dto.documentType,
            originalFilename: dto.originalFilename,
            fileSize: dto.fileSize,
            uploadStatus: dto.uploadStatus,
            downloadURL: safeDownloadURL
        )
    }
}

extension VerifyCorrectionRecord {
    nonisolated init(dto: VerificationCorrectionResponseDTO) {
        self.init(
            id: dto.publicID,
            fieldKey: dto.fieldKey,
            requestText: dto.requestText,
            guidance: dto.guidance
                .sorted(by: { $0.key < $1.key })
                .compactMap { key, value in
                    value.displayText.map {
                        "\(key.replacingOccurrences(of: "_", with: " ").capitalized): \($0)"
                    }
                },
            status: dto.status,
            createdAt: dto.createdAt
        )
    }
}

extension VerifyEvidenceSummaryRecord {
    nonisolated init(dto: VerificationRequestEvidenceSummaryDTO) {
        self.init(
            totalItems: dto.totalItems,
            documentItems: dto.documentItems,
            fieldKeys: dto.fieldKeys
        )
    }
}

extension VerifyTimelineEventRecord {
    nonisolated init(dto: VerificationRequestTimelineEventDTO) {
        self.init(
            id: dto.publicID,
            eventType: dto.eventType,
            eventSource: dto.eventSource,
            previousStatus: dto.previousStatus.map(VerifyVerificationStatus.init(rawBackendValue:)),
            newStatus: dto.newStatus.map(VerifyVerificationStatus.init(rawBackendValue:)),
            createdAt: dto.createdAt
        )
    }
}

extension VerifyVerificationKind {
    nonisolated init?(rawBackendValue: String) {
        switch rawBackendValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
        case "employment":
            self = .employment
        case "education":
            self = .education
        case "certification":
            self = .certification
        case "project":
            self = .project
        default:
            return nil
        }
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
