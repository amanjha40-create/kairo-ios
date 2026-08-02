import Foundation

nonisolated struct RegisterRequestDTO: Encodable, Equatable, Sendable {
    let fullName: String?
    let email: String
    let phone: String
    let password: String

    nonisolated init(
        fullName: String?,
        email: String,
        phone: String,
        password: String
    ) {
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.password = password
    }
}

nonisolated struct SignupStartResponseDTO: Decodable, Equatable, Sendable {
    let signupSessionID: String
    let emailMasked: String
    let phoneMasked: String
    let emailVerified: Bool
    let phoneVerified: Bool
    let emailResendAfterSeconds: Int
    let phoneResendAfterSeconds: Int
    let expiresInSeconds: Int
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case signupSessionID
        case emailMasked
        case phoneMasked
        case emailVerified
        case phoneVerified
        case emailResendAfterSeconds
        case phoneResendAfterSeconds
        case expiresInSeconds
        case message
    }

    nonisolated init(
        signupSessionID: String,
        emailMasked: String,
        phoneMasked: String,
        emailVerified: Bool = false,
        phoneVerified: Bool = false,
        emailResendAfterSeconds: Int,
        phoneResendAfterSeconds: Int,
        expiresInSeconds: Int,
        message: String? = nil
    ) {
        self.signupSessionID = signupSessionID
        self.emailMasked = emailMasked
        self.phoneMasked = phoneMasked
        self.emailVerified = emailVerified
        self.phoneVerified = phoneVerified
        self.emailResendAfterSeconds = emailResendAfterSeconds
        self.phoneResendAfterSeconds = phoneResendAfterSeconds
        self.expiresInSeconds = expiresInSeconds
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        signupSessionID = try container.decode(String.self, forKey: .signupSessionID)
        emailMasked = try container.decode(String.self, forKey: .emailMasked)
        phoneMasked = try container.decode(String.self, forKey: .phoneMasked)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? false
        phoneVerified = try container.decodeIfPresent(Bool.self, forKey: .phoneVerified) ?? false
        emailResendAfterSeconds = try container.decode(Int.self, forKey: .emailResendAfterSeconds)
        phoneResendAfterSeconds = try container.decode(Int.self, forKey: .phoneResendAfterSeconds)
        expiresInSeconds = try container.decode(Int.self, forKey: .expiresInSeconds)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

nonisolated struct SendEmailCodeRequestDTO: Encodable, Equatable, Sendable {
    let signupSessionID: String

    nonisolated init(signupSessionID: String) {
        self.signupSessionID = signupSessionID
    }
}

nonisolated struct VerifyEmailCodeRequestDTO: Encodable, Equatable, Sendable {
    let signupSessionID: String
    let code: String

    nonisolated init(signupSessionID: String, code: String) {
        self.signupSessionID = signupSessionID
        self.code = code
    }
}

nonisolated struct SendPhoneCodeRequestDTO: Encodable, Equatable, Sendable {
    let signupSessionID: String

    nonisolated init(signupSessionID: String) {
        self.signupSessionID = signupSessionID
    }
}

nonisolated struct VerifyPhoneCodeRequestDTO: Encodable, Equatable, Sendable {
    let signupSessionID: String
    let code: String

    nonisolated init(signupSessionID: String, code: String) {
        self.signupSessionID = signupSessionID
        self.code = code
    }
}

nonisolated struct SignupCompleteRequestDTO: Encodable, Equatable, Sendable {
    let signupSessionID: String

    nonisolated init(signupSessionID: String) {
        self.signupSessionID = signupSessionID
    }
}

nonisolated struct LoginRequestDTO: Encodable, Equatable, Sendable {
    let email: String
    let password: String

    nonisolated init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}
