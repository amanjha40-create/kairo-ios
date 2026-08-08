import Foundation

struct VerifyOverview: Equatable, Sendable {
    let requests: [VerifyRequestRecord]
}

struct VerifyRequestRecord: Identifiable, Equatable, Sendable {
    let id: String
    let routeID: String?
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
    let consentedFields: [String]
    let consentedEvidenceScope: [String]
    let evidenceSummary: VerifyEvidenceSummaryRecord
    let timeline: [VerifyTimelineEventRecord]
}

struct VerifyEvidenceSummaryRecord: Equatable, Sendable {
    let totalItems: Int
    let documentItems: Int
    let fieldKeys: [String]
}

struct VerifyTimelineEventRecord: Identifiable, Equatable, Sendable {
    let id: String
    let eventType: String
    let eventSource: String
    let previousStatus: VerifyVerificationStatus?
    let newStatus: VerifyVerificationStatus?
    let createdAt: Date
}

extension VerifyRequestRecord {
    nonisolated init(
        detail: VerificationRequestResponseDTO,
        fallbackID: String,
        routeIDOverride: String? = nil,
        timeline: [VerificationRequestTimelineEventDTO]
    ) {
        let kind = VerifyVerificationKind(rawBackendValue: detail.requestType)
        let typeTitle = kind.map { "\($0.title) verification" } ?? Self.humanizedType(from: detail.requestType)
        let organizationName = Self.organizationName(from: detail)
        let routeID = routeIDOverride ?? detail.routingID

        self.init(
            id: routeID ?? fallbackID,
            routeID: routeID,
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
            consentedFields: detail.consentedFields,
            consentedEvidenceScope: detail.consentedEvidenceScope,
            evidenceSummary: .init(dto: detail.evidenceSummary),
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

extension VerifyEvidenceSummaryRecord {
    init(dto: VerificationRequestEvidenceSummaryDTO) {
        self.init(
            totalItems: dto.totalItems,
            documentItems: dto.documentItems,
            fieldKeys: dto.fieldKeys
        )
    }
}

extension VerifyTimelineEventRecord {
    init(dto: VerificationRequestTimelineEventDTO) {
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
    init?(rawBackendValue: String) {
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
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
