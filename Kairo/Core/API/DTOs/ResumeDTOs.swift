import Foundation

nonisolated enum JSONValue: Decodable, Encodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value."
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

nonisolated struct ResumeListResponseDTO: Decodable, Equatable, Sendable {
    let items: [ResumeRecordDTO]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let offset: Int
    let limit: Int

    private enum CodingKeys: String, CodingKey {
        case items
        case total
        case page
        case pageSize
        case totalPages
        case offset
        case limit
    }
}

nonisolated struct ResumeRecordDTO: Decodable, Equatable, Sendable {
    let id: String
    let originalFilename: String
    let contentType: String
    let fileSizeBytes: Int
    let uploadStatus: String
    let processingStatus: String
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case originalFilename
        case contentType
        case fileSizeBytes
        case uploadStatus
        case processingStatus
        case createdAt
        case updatedAt
    }
}

nonisolated struct ResumeUploadIntentRequestDTO: Encodable, Equatable, Sendable {
    let originalFilename: String
    let contentType: String
    let byteSize: Int
    let consentVersion: String

    private enum CodingKeys: String, CodingKey {
        case originalFilename
        case contentType
        case byteSize
        case consentVersion
    }
}

nonisolated struct ResumeUploadIntentDTO: Decodable, Equatable, Sendable {
    let resumeID: String
    let uploadURL: URL
    let expiresIn: Int
    let objectKey: String

    private enum CodingKeys: String, CodingKey {
        case resumeID = "resumeId"
        case uploadURL = "uploadUrl"
        case expiresIn
        case objectKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resumeID = try container.decode(String.self, forKey: .resumeID)
        uploadURL = try container.decode(URL.self, forKey: .uploadURL)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        objectKey = try container.decodeIfPresent(String.self, forKey: .objectKey) ?? ""
    }
}

nonisolated struct ResumeCompleteUploadRequestDTO: Encodable, Equatable, Sendable {
    let checksumSHA256: String

    private enum CodingKeys: String, CodingKey {
        case checksumSHA256
    }
}

nonisolated struct ResumeProcessDTO: Decodable, Equatable, Sendable {
    let resumeID: String
    let jobID: String
    let status: String

    private enum CodingKeys: String, CodingKey {
        case resumeID = "resumeId"
        case jobID = "jobId"
        case status
    }
}

nonisolated struct ResumeParsedResultDTO: Decodable, Equatable, Sendable {
    let resumeID: String
    let jobID: String
    let schemaVersion: String
    let status: String
    let structuredResult: [String: JSONValue]
    let warnings: [String]

    private enum CodingKeys: String, CodingKey {
        case resumeID = "resumeId"
        case jobID = "jobId"
        case schemaVersion
        case status
        case structuredResult
        case warnings
    }
}

nonisolated struct ResumeReviewSessionDTO: Decodable, Equatable, Sendable {
    let id: String
    let resumeID: String
    let parsedResultID: String
    let status: String
    let schemaVersion: String
    let version: Int
    let items: [ResumeReviewItemDTO]
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case resumeID = "resumeId"
        case parsedResultID = "parsedResultId"
        case status
        case schemaVersion
        case version
        case items
        case createdAt
        case updatedAt
    }
}

nonisolated struct ResumeReviewItemDTO: Decodable, Equatable, Sendable {
    let id: String
    let claimType: String
    let sourceClaimID: String
    let originalPayload: [String: JSONValue]
    let editedPayload: [String: JSONValue]
    let selected: Bool
    let reviewStatus: String
    let duplicateStatus: String
    let duplicateCandidates: [[String: JSONValue]]
    let conflictWarnings: [String]
    let importAction: String
    let targetRecordID: String?
    let importedRecordType: String?
    let importedRecordID: String?
    let sourceReference: String?
    let confidence: Double?
    let version: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case claimType
        case sourceClaimID = "sourceClaimId"
        case originalPayload
        case editedPayload
        case selected
        case reviewStatus
        case duplicateStatus
        case duplicateCandidates
        case conflictWarnings
        case importAction
        case targetRecordID = "targetRecordId"
        case importedRecordType
        case importedRecordID = "importedRecordId"
        case sourceReference
        case confidence
        case version
    }
}

nonisolated struct ResumeReviewItemUpdateRequestDTO: Encodable, Equatable, Sendable {
    let expectedVersion: Int
    let selected: Bool?
    let importAction: String?
    let targetRecordID: String?
    let editedPayload: [String: JSONValue]?

    private enum CodingKeys: String, CodingKey {
        case expectedVersion
        case selected
        case importAction
        case targetRecordID = "targetRecordId"
        case editedPayload
    }
}

nonisolated struct ResumeReviewPlanDTO: Decodable, Equatable, Sendable {
    let sessionID: String
    let ready: Bool
    let version: Int
    let items: [ResumeReviewPlanItemDTO]

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case ready
        case version
        case items
    }
}

nonisolated struct ResumeReviewPlanItemDTO: Decodable, Equatable, Sendable {
    let itemID: String
    let claimType: String
    let action: String
    let targetModel: String?
    let duplicateStatus: String
    let targetRecordID: String?
    let fieldsToCreate: [String]
    let fieldsIgnored: [String]
    let blockers: [String]
    let warnings: [String]
    let verifiedRecordProtected: Bool

    private enum CodingKeys: String, CodingKey {
        case itemID = "itemId"
        case claimType
        case action
        case targetModel
        case duplicateStatus
        case targetRecordID = "targetRecordId"
        case fieldsToCreate
        case fieldsIgnored
        case blockers
        case warnings
        case verifiedRecordProtected
    }
}

nonisolated struct ResumeReviewValidateRequestDTO: Encodable, Equatable, Sendable {
    let expectedVersion: Int

    private enum CodingKeys: String, CodingKey {
        case expectedVersion
    }
}

nonisolated struct ResumeReviewImportRequestDTO: Encodable, Equatable, Sendable {
    let expectedVersion: Int
    let idempotencyKey: String
    let confirmed: Bool

    private enum CodingKeys: String, CodingKey {
        case expectedVersion
        case idempotencyKey
        case confirmed
    }
}

nonisolated struct ResumeImportBatchDTO: Decodable, Equatable, Sendable {
    let id: String
    let reviewSessionID: String
    let status: String
    let totalCount: Int
    let importedCount: Int
    let linkedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let blockedCount: Int
    let incompleteCount: Int
    let entityCounts: [String: ResumeImportEntitySummaryDTO]
    let results: [ResumeImportResultDTO]
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case reviewSessionID = "reviewSessionId"
        case status
        case totalCount
        case importedCount
        case linkedCount
        case skippedCount
        case failedCount
        case blockedCount
        case incompleteCount
        case entityCounts
        case results
        case createdAt
        case updatedAt
    }
}

nonisolated struct ResumeImportEntitySummaryDTO: Decodable, Equatable, Sendable {
    let detected: Int
    let imported: Int
    let incomplete: Int
    let failed: Int
}

nonisolated struct ResumeImportResultDTO: Decodable, Equatable, Sendable {
    let reviewItemID: String
    let outcome: String
    let recordType: String?
    let recordID: String?
    let sanitizedErrorCode: String?
    let warnings: [String]

    private enum CodingKeys: String, CodingKey {
        case reviewItemID = "reviewItemId"
        case outcome
        case recordType
        case recordID = "recordId"
        case sanitizedErrorCode
        case warnings
    }
}
