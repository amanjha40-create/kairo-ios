import Foundation

nonisolated struct DigiLockerAadhaarAvailabilityDTO: Decodable, Equatable, Sendable {
    let available: Bool
    let entitlementConfirmed: Bool

    init(available: Bool, entitlementConfirmed: Bool = false) {
        self.available = available
        self.entitlementConfirmed = false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        available = try container.decode(Bool.self, forKey: .available)
        entitlementConfirmed = try container.decode(Bool.self, forKey: .entitlementConfirmed)
        guard !entitlementConfirmed else { throw DigiLockerAadhaarState.uncertain }
    }

    private enum CodingKeys: String, CodingKey { case available, entitlementConfirmed }
}

/// Carries only finite presentation states, never a provider response or error description.
nonisolated enum DigiLockerAadhaarState: Error, Equatable, Sendable, LocalizedError, CaseIterable {
    case idle, checking, available, verifying, verified, needsReview
    case notLinked, unavailable, accessUnavailable, reconnectRequired, integrityFailure, uncertain

    var isBusy: Bool { self == .checking || self == .verifying }

    var message: String {
        switch self {
        case .idle: "Check whether e-Aadhaar is linked to your DigiLocker account."
        case .checking: "Checking e-Aadhaar availability."
        case .available: "e-Aadhaar is available. Your consent is required to verify it."
        case .verifying: "Verifying e-Aadhaar."
        case .verified: "e-Aadhaar identity verified."
        case .needsReview: "e-Aadhaar verification needs review. Review your saved result and profile details."
        case .notLinked: "e-Aadhaar is not linked to your DigiLocker account."
        case .unavailable: "e-Aadhaar verification is not available right now. PAN and Driving Licence verification remain separate."
        case .accessUnavailable: "DigiLocker access to e-Aadhaar is unavailable."
        case .reconnectRequired: "Reconnect DigiLocker before checking again."
        case .integrityFailure: "Could not safely verify e-Aadhaar. No new verification was confirmed."
        case .uncertain: "Could not confirm the result. Check saved results before another attempt."
        }
    }

    var errorDescription: String? { message }

    static func from(error: Error) -> Self {
        if let state = error as? Self { return state }
        if let failure = error as? DigiLockerBackendError {
            return from(statusCode: failure.statusCode, code: failure.code)
        }
        if case .api(let failure) = error as? NetworkError {
            return from(statusCode: failure.statusCode, code: nil)
        }
        if let failure = error as? APIError {
            return from(statusCode: failure.statusCode, code: nil)
        }
        if error is SessionServiceError { return .reconnectRequired }
        return .uncertain
    }

    static func from(statusCode: Int, code: DigiLockerBackendErrorCode?) -> Self {
        switch code {
        case .aadhaarNotLinked: return .notLinked
        case .insufficientScope, .accountUnavailable: return .accessUnavailable
        case .invalidToken, .reconnectRequired, .connectionAccessUnavailable: return .reconnectRequired
        case .integrityFailed: return .integrityFailure
        case .notConfigured, nil: break
        }
        switch statusCode {
        case 401: return .reconnectRequired
        case 403: return .accessUnavailable
        case 404: return .unavailable
        default: return .uncertain
        }
    }
}

nonisolated enum DigiLockerBackendErrorCode: String, Decodable, Equatable, Sendable {
    case aadhaarNotLinked = "digilocker_aadhaar_not_linked"
    case insufficientScope = "digilocker_insufficient_scope"
    case accountUnavailable = "digilocker_account_unavailable"
    case invalidToken = "digilocker_invalid_token"
    case reconnectRequired = "digilocker_reconnect_required"
    case connectionAccessUnavailable = "digilocker_access_unavailable"
    case integrityFailed = "digilocker_integrity_failed"
    case notConfigured = "digilocker_not_configured"
}

nonisolated struct DigiLockerBackendError: Error, Equatable, Sendable, LocalizedError {
    let statusCode: Int
    let code: DigiLockerBackendErrorCode?

    var errorDescription: String? { DigiLockerAadhaarState.from(error: self).message }

    static func decode(from data: Data, statusCode: Int) -> Self {
        let envelope = try? APIJSONCoder.makeDecoder().decode(Envelope.self, from: data)
        return .init(statusCode: statusCode, code: envelope?.error?.code ?? envelope?.code)
    }

    private struct Envelope: Decodable {
        let code: DigiLockerBackendErrorCode?
        let error: Detail?
        private enum CodingKeys: String, CodingKey { case code, error }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            code = try? container.decode(DigiLockerBackendErrorCode.self, forKey: .code)
            error = try? container.decode(Detail.self, forKey: .error)
        }
    }

    private struct Detail: Decodable {
        let code: DigiLockerBackendErrorCode?
        private enum CodingKeys: String, CodingKey { case code }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            code = try? container.decode(DigiLockerBackendErrorCode.self, forKey: .code)
        }
    }
}

nonisolated struct DigiLockerAadhaarVerifyRequestDTO: Encodable {
    let consent = true
    let consentVersion = "v1"
}

/// Validate provenance at the dedicated endpoint, then retain only safe display metadata.
nonisolated struct DigiLockerAadhaarVerificationResponseDTO: Decodable {
    let verification: DigiLockerVerificationDTO

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .sourceType) == "eaadhaar" else {
            throw DigiLockerAadhaarState.uncertain
        }
        verification = try DigiLockerVerificationDTO(from: decoder)
        guard verification.documentType == "EAADHAAR", verification.source == .digilocker else {
            throw DigiLockerAadhaarState.uncertain
        }
        guard verification.integrityResult == "verified" else {
            throw DigiLockerAadhaarState.integrityFailure
        }
    }

    private enum CodingKeys: String, CodingKey { case sourceType }
}
