import Foundation

nonisolated struct EmptyMobileVerificationRequest: Encodable, Sendable {}

nonisolated struct AccountMobileVerificationRequest: Encodable, Sendable {
    let code: String
}

nonisolated enum AccountMobileVerificationError: Error {
    case invalidCode
    case invalidPhone
    case emailRequired
}

nonisolated struct AccountMobileProfileRequest: Encodable, Sendable {
    let phone: String

    // Do not silently truncate input or discard letters. Ten local digits use
    // the same India default as the existing signup UI; international input
    // must explicitly include its country code.
    static func normalizedPhone(_ input: String) -> String? {
        let compact = input.filter { !$0.isWhitespace && !"()-".contains($0) }
        guard !compact.isEmpty else { return nil }
        let explicitCountry = compact.hasPrefix("+")
        let digits = explicitCountry ? String(compact.dropFirst()) : compact
        guard digits.allSatisfy({ $0.isASCII && $0.isNumber }),
              digits.first != "0" else { return nil }
        if explicitCountry {
            guard (8...15).contains(digits.count) else { return nil }
            return "+" + digits
        }
        guard digits.count == 10 else { return nil }
        return "+91" + digits
    }
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
