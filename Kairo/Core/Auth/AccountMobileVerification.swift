import Foundation

nonisolated struct EmptyMobileVerificationRequest: Encodable, Sendable {}

nonisolated struct AccountMobileVerificationRequest: Encodable, Sendable {
    let code: String
}

nonisolated enum AccountMobileVerificationError: Error {
    case invalidCode
    case emailRequired
}

nonisolated struct AccountMobileVerificationResponse: Decodable, Equatable, Sendable {
    enum State: String, Decodable, Sendable {
        case codeSent = "code_sent"
        case verified
        case phoneRequired = "phone_required"
    }

    let state: State
    let phoneVerified: Bool
    let resendAfterSeconds: Int
    let expiresInSeconds: Int

    var isConsistent: Bool {
        phoneVerified == (state == .verified) &&
        resendAfterSeconds >= 0 && expiresInSeconds >= 0
    }
}
