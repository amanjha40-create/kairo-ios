import Foundation
import Security

enum TokenKey: String, CaseIterable, Sendable {
    case accessToken
    case refreshToken
}

enum SecureStorageError: Error, Equatable, LocalizedError {
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

protocol TokenStore: Sendable {
    func save(_ token: String, for key: TokenKey) async throws
    func readToken(for key: TokenKey) async throws -> String?
    func deleteToken(for key: TokenKey) async throws
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
