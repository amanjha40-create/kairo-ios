import Foundation

nonisolated struct VerificationRequestCollectionEnvelopeDTO<Element: Decodable & Equatable & Sendable>: Decodable, Equatable, Sendable {
    let items: [Element]

    nonisolated init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let items = try? container.decode([Element].self) {
            self.items = items
            return
        }

        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        let itemsKey = VerificationDynamicCodingKey("items")
        if let decoded = try container.decodeIfPresent([Element].self, forKey: itemsKey) {
            items = decoded
            return
        }

        throw DecodingError.keyNotFound(
            itemsKey,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing items collection.")
        )
    }
}

nonisolated struct VerificationRequestResponseDTO: Decodable, Equatable, Sendable {
    let publicID: String?
    let trustInvitationPublicID: String?
    let employmentID: String?
    let educationID: String?
    let subjectName: String?
    let subjectEmail: String?
    let targetOrganizationName: String?
    let targetOrganizationEmail: String?
    let requestType: String
    let status: String
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
    let organizationSummary: VerificationRequestOrganizationSummaryDTO?
    let verificationTarget: VerificationRequestTargetDTO?
    let employmentClaim: VerificationRequestEmploymentClaimDTO?
    let educationClaim: VerificationRequestEducationClaimDTO?
    let evidenceSummary: VerificationRequestEvidenceSummaryDTO

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        publicID = try container.decodeFirstPresentString(forKeys: ["public_id"])
        trustInvitationPublicID = try container.decodeFirstPresentString(forKeys: ["trust_invitation_public_id"])
        employmentID = try container.decodeFirstPresentString(forKeys: ["employment_id"])
        educationID = try container.decodeFirstPresentString(forKeys: ["education_id"])
        subjectName = try container.decodeFirstPresentString(forKeys: ["subject_name"])
        subjectEmail = try container.decodeFirstPresentString(forKeys: ["subject_email"])
        targetOrganizationName = try container.decodeFirstPresentString(forKeys: ["target_organization_name"])
        targetOrganizationEmail = try container.decodeFirstPresentString(forKeys: ["target_organization_email"])
        requestType = try container.decodeRequiredString(forKeys: ["request_type"], debugName: "verification request type")
        status = try container.decodeRequiredString(forKeys: ["status"], debugName: "verification request status")
        priority = try container.decodeFirstPresentString(forKeys: ["priority"]) ?? "normal"
        dueDate = try container.decodeFirstPresentDate(forKeys: ["due_date"])
        createdAt = try container.decodeRequiredDate(forKeys: ["created_at"], debugName: "verification request created at")
        updatedAt = try container.decodeRequiredDate(forKeys: ["updated_at"], debugName: "verification request updated at")
        candidateResponse = try container.decodeFirstPresentString(forKeys: ["candidate_response"])
        candidateResponseSubmittedAt = try container.decodeFirstPresentDate(forKeys: ["candidate_response_submitted_at"])
        acceptedAt = try container.decodeFirstPresentDate(forKeys: ["accepted_at"])
        consentedAt = try container.decodeFirstPresentDate(forKeys: ["consented_at"])
        consentVersion = try container.decodeFirstPresentString(forKeys: ["consent_version"])
        consentedFields = try container.decodeFirstPresentValue(forKeys: ["consented_fields"]) ?? []
        consentedEvidenceScope = try container.decodeFirstPresentValue(forKeys: ["consented_evidence_scope"]) ?? []
        reviewStatus = try container.decodeFirstPresentString(forKeys: ["review_status"])
        organizationSummary = try container.decodeFirstPresentValue(forKeys: ["organization_summary"])
        verificationTarget = try container.decodeFirstPresentValue(forKeys: ["verification_target"])
        employmentClaim = try container.decodeFirstPresentValue(forKeys: ["employment_claim"])
        educationClaim = try container.decodeFirstPresentValue(forKeys: ["education_claim"])
        evidenceSummary = try container.decodeFirstPresentValue(forKeys: ["evidence_summary"])
            ?? .init(totalItems: 0, documentItems: 0, fieldKeys: [])
    }

    var routingID: String? {
        publicID ?? trustInvitationPublicID
    }
}

nonisolated struct VerificationRequestOrganizationSummaryDTO: Decodable, Equatable, Sendable {
    let publicID: String
    let name: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        publicID = try container.decodeRequiredString(
            forKeys: ["public_id"],
            debugName: "verification organization public id"
        )
        name = try container.decodeRequiredString(
            forKeys: ["name"],
            debugName: "verification organization name"
        )
    }
}

nonisolated struct VerificationRequestTargetDTO: Decodable, Equatable, Sendable {
    let organizationName: String?
    let organizationEmail: String?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        organizationName = try container.decodeFirstPresentString(forKeys: ["organization_name"])
        organizationEmail = try container.decodeFirstPresentString(forKeys: ["organization_email"])
    }
}

nonisolated struct VerificationRequestEmploymentClaimDTO: Decodable, Equatable, Sendable {
    let employerName: String?
    let role: String?
    let startDate: Date?
    let endDate: Date?
    let employmentType: String?
    let workLocationCountry: String?
    let workLocationRegion: String?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        employerName = try container.decodeFirstPresentString(forKeys: ["employer_name"])
        role = try container.decodeFirstPresentString(forKeys: ["role"])
        startDate = try container.decodeFirstPresentDate(forKeys: ["start_date"])
        endDate = try container.decodeFirstPresentDate(forKeys: ["end_date"])
        employmentType = try container.decodeFirstPresentString(forKeys: ["employment_type"])
        workLocationCountry = try container.decodeFirstPresentString(forKeys: ["work_location_country"])
        workLocationRegion = try container.decodeFirstPresentString(forKeys: ["work_location_region"])
    }
}

nonisolated struct VerificationRequestEducationClaimDTO: Decodable, Equatable, Sendable {
    let institutionName: String?
    let degree: String?
    let fieldOfStudy: String?
    let startDate: Date?
    let endDate: Date?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        institutionName = try container.decodeFirstPresentString(forKeys: ["institution_name"])
        degree = try container.decodeFirstPresentString(forKeys: ["degree"])
        fieldOfStudy = try container.decodeFirstPresentString(forKeys: ["field_of_study"])
        startDate = try container.decodeFirstPresentDate(forKeys: ["start_date"])
        endDate = try container.decodeFirstPresentDate(forKeys: ["end_date"])
    }
}

nonisolated struct VerificationRequestEvidenceSummaryDTO: Decodable, Equatable, Sendable {
    let totalItems: Int
    let documentItems: Int
    let fieldKeys: [String]
}

nonisolated struct VerificationRequestTimelineResponseDTO: Decodable, Equatable, Sendable {
    let verificationRequestPublicID: String
    let items: [VerificationRequestTimelineEventDTO]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let offset: Int
    let limit: Int

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        verificationRequestPublicID = try container.decodeRequiredString(
            forKeys: ["verification_request_public_id"],
            debugName: "verification request timeline id"
        )
        items = try container.decodeFirstPresentValue(forKeys: ["items"]) ?? []
        total = try container.decodeFirstPresentValue(forKeys: ["total"]) ?? items.count
        page = try container.decodeFirstPresentValue(forKeys: ["page"]) ?? 1
        pageSize = try container.decodeFirstPresentValue(forKeys: ["page_size"]) ?? items.count
        totalPages = try container.decodeFirstPresentValue(forKeys: ["total_pages"]) ?? 1
        offset = try container.decodeFirstPresentValue(forKeys: ["offset"]) ?? 0
        limit = try container.decodeFirstPresentValue(forKeys: ["limit"]) ?? items.count
    }
}

nonisolated struct VerificationRequestTimelineEventDTO: Decodable, Equatable, Sendable {
    let publicID: String
    let eventType: String
    let eventSource: String
    let previousStatus: String?
    let newStatus: String?
    let createdAt: Date

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        publicID = try container.decodeRequiredString(forKeys: ["public_id"], debugName: "verification timeline event id")
        eventType = try container.decodeRequiredString(forKeys: ["event_type"], debugName: "verification timeline event type")
        eventSource = try container.decodeRequiredString(forKeys: ["event_source"], debugName: "verification timeline event source")
        previousStatus = try container.decodeFirstPresentString(forKeys: ["previous_status"])
        newStatus = try container.decodeFirstPresentString(forKeys: ["new_status"])
        createdAt = try container.decodeRequiredDate(forKeys: ["created_at"], debugName: "verification timeline created at")
    }
}

nonisolated struct VerificationInformationSubmissionRequestDTO: Encodable, Equatable, Sendable {
    let response: String
}

nonisolated struct VerificationSubmitForReviewRequestDTO: Encodable, Equatable, Sendable {
    let consentedFields: [String]
    let consentedEvidenceScope: [String]
    let consentVersion: String?
}

nonisolated struct VerificationContactResponseDTO: Decodable, Equatable, Sendable {
    let publicID: String
    let contactName: String?
    let contactEmail: String
    let contactRole: String?
    let contactType: String
    let candidateNote: String?
    let reviewStatus: String
    let reviewNotes: String?
    let reviewedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        publicID = try container.decodeRequiredString(forKeys: ["public_id"], debugName: "verification contact id")
        contactName = try container.decodeFirstPresentString(forKeys: ["contact_name"])
        contactEmail = try container.decodeRequiredString(forKeys: ["contact_email"], debugName: "verification contact email")
        contactRole = try container.decodeFirstPresentString(forKeys: ["contact_role"])
        contactType = try container.decodeRequiredString(forKeys: ["contact_type"], debugName: "verification contact type")
        candidateNote = try container.decodeFirstPresentString(forKeys: ["candidate_note"])
        reviewStatus = try container.decodeRequiredString(forKeys: ["review_status"], debugName: "verification contact review status")
        reviewNotes = try container.decodeFirstPresentString(forKeys: ["review_notes"])
        reviewedAt = try container.decodeFirstPresentDate(forKeys: ["reviewed_at"])
        createdAt = try container.decodeRequiredDate(forKeys: ["created_at"], debugName: "verification contact created at")
        updatedAt = try container.decodeRequiredDate(forKeys: ["updated_at"], debugName: "verification contact updated at")
    }
}

nonisolated struct VerificationEvidenceResponseDTO: Decodable, Equatable, Sendable {
    let publicID: String
    let evidenceType: String
    let fieldKey: String
    let documentID: String?
    let employmentDocumentID: String?
    let educationDocumentID: String?
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let documentType: String?
    let originalFilename: String?
    let mimeType: String?
    let fileSize: Int?
    let uploadStatus: String?
    let downloadURL: URL?
    let downloadURLExpiresInSeconds: Int?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        publicID = try container.decodeRequiredString(forKeys: ["public_id"], debugName: "verification evidence id")
        evidenceType = try container.decodeRequiredString(forKeys: ["evidence_type"], debugName: "verification evidence type")
        fieldKey = try container.decodeRequiredString(forKeys: ["field_key"], debugName: "verification evidence field")
        documentID = try container.decodeFirstPresentString(forKeys: ["document_id"])
        employmentDocumentID = try container.decodeFirstPresentString(forKeys: ["employment_document_id"])
        educationDocumentID = try container.decodeFirstPresentString(forKeys: ["education_document_id"])
        status = try container.decodeRequiredString(forKeys: ["status"], debugName: "verification evidence status")
        createdAt = try container.decodeRequiredDate(forKeys: ["created_at"], debugName: "verification evidence created at")
        updatedAt = try container.decodeRequiredDate(forKeys: ["updated_at"], debugName: "verification evidence updated at")
        documentType = try container.decodeFirstPresentString(forKeys: ["document_type"])
        originalFilename = try container.decodeFirstPresentString(forKeys: ["original_filename"])
        mimeType = try container.decodeFirstPresentString(forKeys: ["mime_type"])
        fileSize = try container.decodeFirstPresentValue(forKeys: ["file_size"])
        uploadStatus = try container.decodeFirstPresentString(forKeys: ["upload_status"])
        downloadURL = try container.decodeFirstPresentValue(forKeys: ["download_url"])
        downloadURLExpiresInSeconds = try container.decodeFirstPresentValue(forKeys: ["download_url_expires_in_seconds"])
    }
}

nonisolated struct VerificationCorrectionResponseDTO: Decodable, Equatable, Sendable {
    let publicID: String
    let evidencePublicID: String?
    let fieldKey: String
    let requestText: String
    let guidance: [String: VerificationJSONValue]
    let status: String
    let createdAt: Date
    let updatedAt: Date

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VerificationDynamicCodingKey.self)
        publicID = try container.decodeRequiredString(forKeys: ["public_id"], debugName: "verification correction id")
        evidencePublicID = try container.decodeFirstPresentString(forKeys: ["evidence_public_id"])
        fieldKey = try container.decodeRequiredString(forKeys: ["field_key"], debugName: "verification correction field")
        requestText = try container.decodeRequiredString(forKeys: ["request_text"], debugName: "verification correction request")
        guidance = try container.decodeFirstPresentValue(forKeys: ["guidance"]) ?? [:]
        status = try container.decodeRequiredString(forKeys: ["status"], debugName: "verification correction status")
        createdAt = try container.decodeRequiredDate(forKeys: ["created_at"], debugName: "verification correction created at")
        updatedAt = try container.decodeRequiredDate(forKeys: ["updated_at"], debugName: "verification correction updated at")
    }
}

nonisolated indirect enum VerificationJSONValue: Decodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: VerificationJSONValue])
    case array([VerificationJSONValue])
    case null

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: VerificationJSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([VerificationJSONValue].self))
        }
    }

    nonisolated var displayText: String? {
        switch self {
        case .string(let value):
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        case .number(let value):
            value.formatted()
        case .bool(let value):
            value ? "Yes" : "No"
        case .array(let values):
            values.compactMap(\.displayText).joined(separator: ", ")
        case .object(let values):
            values.sorted(by: { $0.key < $1.key }).compactMap { key, value in
                value.displayText.map { "\(Self.humanized(key)): \($0)" }
            }.joined(separator: "; ")
        case .null:
            nil
        }
    }

    private nonisolated static func humanized(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct VerificationDynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    nonisolated init(_ string: String) {
        stringValue = string
        intValue = nil
    }

    nonisolated init?(stringValue: String) {
        self.init(stringValue)
    }

    nonisolated init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == VerificationDynamicCodingKey {
    nonisolated func decodeRequiredString(
        forKeys keys: [String],
        debugName: String
    ) throws -> String {
        if let value = try decodeFirstPresentString(forKeys: keys) {
            return value
        }

        throw DecodingError.keyNotFound(
            VerificationDynamicCodingKey(keys.first ?? debugName),
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing \(debugName).")
        )
    }

    nonisolated func decodeFirstPresentString(forKeys keys: [String]) throws -> String? {
        for key in candidateKeys(for: keys) {
            if let value = try decodeIfPresent(String.self, forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }

        return nil
    }

    nonisolated func decodeRequiredDate(
        forKeys keys: [String],
        debugName: String
    ) throws -> Date {
        if let value = try decodeFirstPresentDate(forKeys: keys) {
            return value
        }

        throw DecodingError.keyNotFound(
            VerificationDynamicCodingKey(keys.first ?? debugName),
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing \(debugName).")
        )
    }

    nonisolated func decodeFirstPresentDate(forKeys keys: [String]) throws -> Date? {
        for key in candidateKeys(for: keys) {
            if let value = try decodeIfPresent(Date.self, forKey: key) {
                return value
            }
        }

        return nil
    }

    nonisolated func decodeFirstPresentValue<T: Decodable>(forKeys keys: [String]) throws -> T? {
        for key in candidateKeys(for: keys) {
            if let value = try decodeIfPresent(T.self, forKey: key) {
                return value
            }
        }

        return nil
    }

    private nonisolated func candidateKeys(for rawKeys: [String]) -> [VerificationDynamicCodingKey] {
        var seen = Set<String>()
        var keys: [VerificationDynamicCodingKey] = []

        for rawKey in rawKeys {
            for candidate in [rawKey, rawKey.kairoConvertedFromSnakeCase] {
                guard seen.insert(candidate).inserted else { continue }
                keys.append(VerificationDynamicCodingKey(candidate))
            }
        }

        return keys
    }
}

private extension String {
    nonisolated var kairoConvertedFromSnakeCase: String {
        guard contains("_") else { return self }

        let parts = split(separator: "_", omittingEmptySubsequences: false)
        guard let first = parts.first else { return self }

        let rest = parts.dropFirst().map { part -> String in
            guard let firstCharacter = part.first else { return "" }
            return String(firstCharacter).uppercased() + part.dropFirst()
        }

        return String(first) + rest.joined()
    }
}
