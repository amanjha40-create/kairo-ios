import Foundation

nonisolated struct TokenResponseDTO: Decodable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    let expiresIn: Int?

    nonisolated init(
        accessToken: String,
        refreshToken: String,
        tokenType: String?,
        expiresIn: Int?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
    }
}

nonisolated struct RefreshRequestDTO: Encodable, Equatable, Sendable {
    let refreshToken: String

    nonisolated init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}
