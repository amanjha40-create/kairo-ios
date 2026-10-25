import Foundation

nonisolated enum DigiLockerConnectionState: String, Decodable, Equatable, Sendable {
    case pending
    case active
    case reconnectRequired = "reconnect_required"
    case disconnected

    var title: String {
        switch self {
        case .active: "Connected"
        case .pending: "Connection pending"
        case .reconnectRequired: "Reconnect required"
        case .disconnected: "Not connected"
        }
    }
}

nonisolated struct DigiLockerStatusDTO: Decodable, Equatable, Sendable {
    let connected: Bool
    let status: DigiLockerConnectionState
    let connectedAt: Date?
    let consentValidUntil: Date?
    let scopes: [String]

    init(connected: Bool, status: DigiLockerConnectionState, connectedAt: Date? = nil,
         consentValidUntil: Date? = nil, scopes: [String] = []) {
        self.connected = connected
        self.status = status
        self.connectedAt = connectedAt
        self.consentValidUntil = consentValidUntil
        self.scopes = scopes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        connected = try container.decode(Bool.self, forKey: .connected)
        status = try container.decode(DigiLockerConnectionState.self, forKey: .status)
        connectedAt = try container.decodeIfPresent(Date.self, forKey: .connectedAt)
        consentValidUntil = try container.decodeIfPresent(Date.self, forKey: .consentValidUntil)
        scopes = try container.decodeIfPresent([String].self, forKey: .scopes) ?? []
        guard connected == (status == .active) else {
            throw DecodingError.dataCorruptedError(
                forKey: .status,
                in: container,
                debugDescription: "DigiLocker connected flag and state disagree."
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case connected, status, connectedAt, consentValidUntil, scopes
    }
}

nonisolated enum DigiLockerIdentityState: String, Decodable, Equatable, Sendable {
    case verified
    case unverified
}

nonisolated enum DigiLockerSource: String, Decodable, Equatable, Sendable {
    case kairo
    case digilocker
}

nonisolated enum DigiLockerMatchResult: String, Decodable, Equatable, Sendable {
    case verifiedMatch = "VERIFIED_MATCH"
    case partialMatch = "PARTIAL_MATCH"
    case mismatch = "MISMATCH"
    case unableToVerify = "UNABLE_TO_VERIFY"
}

nonisolated enum DigiLockerMismatchReason: String, Decodable, Equatable, Sendable {
    case nameMismatch = "NAME_MISMATCH"
    case dateOfBirthMismatch = "DOB_MISMATCH"
    case nameAndDateOfBirthMismatch = "NAME_AND_DOB_MISMATCH"
    case requiredFieldMissing = "REQUIRED_FIELD_MISSING"
    case other = "OTHER"

    var safeMessage: String {
        switch self {
        case .nameMismatch: "Name does not match your KairoID profile"
        case .dateOfBirthMismatch: "Date of birth does not match your KairoID profile"
        case .nameAndDateOfBirthMismatch: "Name and date of birth do not match your KairoID profile"
        case .requiredFieldMissing: "Required details are missing for verification"
        case .other: "Review your profile and document details"
        }
    }
}

nonisolated struct DigiLockerTrustSourceDTO: Decodable, Equatable, Sendable, Identifiable {
    let source: DigiLockerSource
    let documentType: String
    let current: Bool
    let matchResult: DigiLockerMatchResult
    let reason: DigiLockerMismatchReason?

    var id: String { "\(source.rawValue).\(documentType)" }
}

nonisolated struct DigiLockerIdentityTrustDTO: Decodable, Equatable, Sendable {
    let state: DigiLockerIdentityState
    let sources: [DigiLockerTrustSourceDTO]
}

nonisolated struct DigiLockerVerificationDTO: Decodable, Equatable, Sendable, Identifiable {
    let documentType: String
    let source: DigiLockerSource
    let current: Bool
    let matchResult: DigiLockerMatchResult
    let matchReason: DigiLockerMismatchReason?
    let integrityResult: String
    let verifiedAt: Date?

    var id: String { "\(source.rawValue).\(documentType)" }

    var isVerified: Bool {
        guard current, matchResult == .verifiedMatch else { return false }
        guard documentType == "EAADHAAR" else { return true }
        guard source == .digilocker, integrityResult == "verified", let verifiedAt else { return false }
        return verifiedAt.timeIntervalSince1970.isFinite
            && verifiedAt.timeIntervalSince1970 > 0 && verifiedAt <= Date()
    }
}

nonisolated struct DigiLockerVerificationHistoryDTO: Decodable, Equatable, Sendable {
    let items: [DigiLockerVerificationDTO]
    let identityVerified: Bool
    let documentOutcomes: [DigiLockerDocumentOutcomeDTO]

    init(
        items: [DigiLockerVerificationDTO],
        identityVerified: Bool,
        documentOutcomes: [DigiLockerDocumentOutcomeDTO] = []
    ) {
        self.items = items
        self.identityVerified = identityVerified
        self.documentOutcomes = documentOutcomes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([DigiLockerVerificationDTO].self, forKey: .items)
        identityVerified = try container.decode(Bool.self, forKey: .identityVerified)
        documentOutcomes = try container.decodeIfPresent(
            [DigiLockerDocumentOutcomeDTO].self,
            forKey: .documentOutcomes
        ) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case items, identityVerified, documentOutcomes
    }
}

nonisolated enum DigiLockerDocumentOutcomeStatus: String, Decodable, Equatable, Sendable {
    case alreadyVerified = "already_verified"
    case verified
    case needsReview = "needs_review"
    case failed
}

nonisolated struct DigiLockerDocumentOutcomeDTO: Decodable, Equatable, Sendable {
    let documentType: String
    let status: DigiLockerDocumentOutcomeStatus
    let verificationID: String?
    let errorCode: String?
    let retryable: Bool
}

/// Intentionally decodes only the two fields needed for display and eligibility.
/// Provider names, descriptions, references, and URIs never enter app state.
nonisolated struct DigiLockerIssuedDocumentDTO: Decodable, Equatable, Sendable, Identifiable {
    let documentType: String
    let supported: Bool

    var id: String { documentType }

    private enum CodingKeys: String, CodingKey {
        case documentType = "doctype"
        case supported
    }
}

nonisolated struct DigiLockerIssuedDocumentsDTO: Decodable, Equatable, Sendable {
    let items: [DigiLockerIssuedDocumentDTO]
}

nonisolated struct DigiLockerConnectResponseDTO: Decodable, Equatable, Sendable {
    let authorizationURL: String
    let expiresAt: Date
    let connectionState: DigiLockerConnectionState

    private enum CodingKeys: String, CodingKey {
        case authorizationURL = "authorizationUrl"
        case expiresAt
        case connectionState
    }
}

nonisolated struct DigiLockerVerifyRequestDTO: Encodable, Equatable, Sendable {
    let documentTypes: [String]
    let consent = true
    let consentVersion = "v1"
}

nonisolated enum DigiLockerDocumentType: String, CaseIterable, Hashable, Sendable {
    case pan = "PANCR"
    case drivingLicence = "DRVLC"

    var title: String {
        switch self {
        case .pan: "PAN"
        case .drivingLicence: "Driving Licence"
        }
    }
}

nonisolated enum DigiLockerPresentation {
    static func documentTitle(_ type: String) -> String {
        switch type {
        case DigiLockerDocumentType.pan.rawValue: "PAN"
        case DigiLockerDocumentType.drivingLicence.rawValue: "Driving Licence"
        case "EAADHAAR": "e-Aadhaar"
        case "identity": "Identity"
        case "DGCER": "Degree"
        case "HSCER": "Class XII certificate"
        case "SSCER": "Class X certificate"
        case "HSMRK": "Class XII marksheet"
        case "SSMRK": "Class X marksheet"
        default: "Issued document"
        }
    }

    static func resultTitle(_ result: DigiLockerMatchResult, current: Bool) -> String {
        if result == .verifiedMatch { return current ? "Verified" : "Review required" }
        return switch result {
        case .partialMatch: "Partially verified"
        case .mismatch: "Needs review"
        case .unableToVerify: "Unable to verify"
        case .verifiedMatch: "Verified"
        }
    }

    static func safeReason(_ reason: DigiLockerMismatchReason?) -> String {
        reason?.safeMessage ?? "Review your profile and document details"
    }
}

/// Normalize unrecognized free-form types before any provider string reaches app state.
private nonisolated enum DigiLockerDecodedDocumentType: String, Decodable {
    case identity, pan = "PANCR", drivingLicence = "DRVLC", aadhaar = "EAADHAAR"
    case degree = "DGCER", classXII = "HSCER", classX = "SSCER"
    case classXIIMarksheet = "HSMRK", classXMarksheet = "SSMRK"

    static func decode<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) throws -> String {
        guard let value = try? container.decode(Self.self, forKey: key) else {
            return "unknown"
        }
        return value.rawValue
    }
}

extension DigiLockerTrustSourceDTO {
    private nonisolated enum CodingKeys: String, CodingKey { case source, documentType, current, matchResult, reason }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(DigiLockerSource.self, forKey: .source)
        documentType = try DigiLockerDecodedDocumentType.decode(from: container, forKey: .documentType)
        current = try container.decode(Bool.self, forKey: .current)
        matchResult = try container.decode(DigiLockerMatchResult.self, forKey: .matchResult)
        reason = try container.decodeIfPresent(DigiLockerMismatchReason.self, forKey: .reason)
    }
}

extension DigiLockerVerificationDTO {
    private nonisolated enum CodingKeys: String, CodingKey {
        case documentType, source, current, matchResult, matchReason, integrityResult, verifiedAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentType = try DigiLockerDecodedDocumentType.decode(from: container, forKey: .documentType)
        source = try container.decode(DigiLockerSource.self, forKey: .source)
        current = try container.decode(Bool.self, forKey: .current)
        matchResult = try container.decode(DigiLockerMatchResult.self, forKey: .matchResult)
        matchReason = try container.decodeIfPresent(DigiLockerMismatchReason.self, forKey: .matchReason)
        let integrity = try container.decode(String.self, forKey: .integrityResult)
        integrityResult = ["verified", "failed", "unverified"].contains(integrity) ? integrity : "unknown"
        do { verifiedAt = try container.decodeIfPresent(Date.self, forKey: .verifiedAt) }
        catch { throw DigiLockerServiceError.invalidResponse }
    }
}

extension DigiLockerIssuedDocumentDTO {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentType = try DigiLockerDecodedDocumentType.decode(from: container, forKey: .documentType)
        let declaredSupported = try container.decode(Bool.self, forKey: .supported)
        supported = documentType != "unknown" && declaredSupported
    }
}
