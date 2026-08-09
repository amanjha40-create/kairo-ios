import Foundation
import XCTest
@testable import Kairo

final class APIConfigurationTests: XCTestCase {
    func test_developmentEnvironmentUsesLocalhostAPI() {
        XCTAssertEqual(
            APIConfiguration.baseURL(for: .development),
            URL(string: "http://localhost:8000/api/v1")
        )
    }

    func test_stagingEnvironmentUsesStagingAPI() {
        XCTAssertEqual(
            APIConfiguration.baseURL(for: .staging),
            URL(string: "https://staging-api.kairoid.com/api/v1")
        )
    }

    func test_productionEnvironmentUsesProductionAPI() {
        XCTAssertEqual(
            APIConfiguration.baseURL(for: .production),
            URL(string: "https://api.kairoid.com/api/v1")
        )
    }
}
