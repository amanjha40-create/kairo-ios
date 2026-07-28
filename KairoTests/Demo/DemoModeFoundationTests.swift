import Foundation
import XCTest
@testable import Kairo

@MainActor
final class DemoModeFoundationTests: XCTestCase {
    func test_demoDependenciesNeverReturnLiveNetworkData() async {
        let configuration = AppConfiguration(
            buildConfiguration: .demo,
            environment: .development,
            isDemoModeEnabled: true,
            apiBaseURL: URL(string: "https://dev-api.kairo.invalid")!,
            keychainService: "com.kairoid.Kairo.tests"
        )
        let dependencies = AppDependencies.make(configuration: configuration)

        do {
            _ = try await dependencies.networkClient.send(NetworkRequest(path: "/candidate"))
            XCTFail("Expected Demo Mode networking to be disabled.")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .unavailableInDemoMode)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_demoDependenciesUseInMemoryTokenStore() {
        let configuration = AppConfiguration(
            buildConfiguration: .demo,
            environment: .development,
            isDemoModeEnabled: true,
            apiBaseURL: URL(string: "https://dev-api.kairo.invalid")!,
            keychainService: "com.kairoid.Kairo.tests"
        )
        let dependencies = AppDependencies.make(configuration: configuration)

        XCTAssertTrue(dependencies.tokenStore is InMemoryTokenStore)
        XCTAssertTrue(dependencies.networkClient is DemoNetworkClient)
    }

    func test_inMemoryTokenStoreRoundTripsTokens() async throws {
        let store = InMemoryTokenStore()

        try await store.save("demo-token", for: .accessToken)
        let savedToken = try await store.readToken(for: .accessToken)
        XCTAssertEqual(savedToken, "demo-token")

        try await store.deleteToken(for: .accessToken)
        let deletedToken = try await store.readToken(for: .accessToken)
        XCTAssertNil(deletedToken)
    }
}
