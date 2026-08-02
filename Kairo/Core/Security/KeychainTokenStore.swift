import Foundation
import Security

actor KeychainTokenStore: TokenStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func save(_ token: String, for key: TokenKey) async throws {
        guard let data = token.data(using: .utf8) else {
            throw SecureStorageError.invalidData
        }

        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureStorageError.unexpectedStatus(status)
        }
    }

    func readToken(for key: TokenKey) async throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw SecureStorageError.unexpectedStatus(status)
        }

        guard
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw SecureStorageError.invalidData
        }

        return token
    }

    func deleteToken(for key: TokenKey) async throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for key: TokenKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
