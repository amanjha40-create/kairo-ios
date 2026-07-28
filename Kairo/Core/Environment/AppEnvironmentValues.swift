import SwiftUI

private struct MissingNetworkClient: NetworkClient {
    func send(_ request: NetworkRequest) async throws -> Data {
        _ = request
        fatalError("Missing network client injection.")
    }
}

private actor MissingTokenStore: TokenStore {
    func save(_ token: String, for key: TokenKey) async throws {
        _ = (token, key)
        fatalError("Missing token store injection.")
    }

    func readToken(for key: TokenKey) async throws -> String? {
        _ = key
        fatalError("Missing token store injection.")
    }

    func deleteToken(for key: TokenKey) async throws {
        _ = key
        fatalError("Missing token store injection.")
    }
}

private struct AppConfigurationKey: EnvironmentKey {
    static let defaultValue = AppConfiguration(
        buildConfiguration: .development,
        environment: .development,
        isDemoModeEnabled: false,
        apiBaseURL: URL(string: "https://dev-api.kairo.invalid")!,
        keychainService: "com.kairoid.Kairo.preview"
    )
}

private struct NetworkClientKey: EnvironmentKey {
    static let defaultValue: any NetworkClient = MissingNetworkClient()
}

private struct TokenStoreKey: EnvironmentKey {
    static let defaultValue: any TokenStore = MissingTokenStore()
}

extension EnvironmentValues {
    var appConfiguration: AppConfiguration {
        get { self[AppConfigurationKey.self] }
        set { self[AppConfigurationKey.self] = newValue }
    }

    var networkClient: any NetworkClient {
        get { self[NetworkClientKey.self] }
        set { self[NetworkClientKey.self] = newValue }
    }

    var tokenStore: any TokenStore {
        get { self[TokenStoreKey.self] }
        set { self[TokenStoreKey.self] = newValue }
    }
}
