import Foundation
import Security

nonisolated enum TokenKey: String, CaseIterable, Sendable {
    case accessToken
    case refreshToken
    case signupSessionID
}

nonisolated enum SecureStorageError: Error, Equatable, LocalizedError, Sendable {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            "Secure storage returned OSStatus \(status)."
        case .invalidData:
            "Secure storage returned invalid token data."
        }
    }
}

nonisolated protocol TokenStore: Sendable {
    func save(_ token: String, for key: TokenKey) async throws
    func readToken(for key: TokenKey) async throws -> String?
    func deleteToken(for key: TokenKey) async throws
}

extension TokenStore {
    func deleteAllTokens() async throws {
        for key in TokenKey.allCases {
            try await deleteToken(for: key)
        }
    }
}

actor InMemoryTokenStore: TokenStore {
    private var storage: [TokenKey: String] = [:]

    func save(_ token: String, for key: TokenKey) async throws {
        storage[key] = token
    }

    func readToken(for key: TokenKey) async throws -> String? {
        return storage[key]
    }

    func deleteToken(for key: TokenKey) async throws {
        storage.removeValue(forKey: key)
    }
}
