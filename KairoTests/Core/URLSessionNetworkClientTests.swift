import Foundation
import XCTest
@testable import Kairo

@MainActor
final class URLSessionNetworkClientTests: XCTestCase {
    func test_makeURLRequestBuildsPathAndQueryItems() throws {
        let client = URLSessionNetworkClient(
            baseURL: URL(string: "https://example.com/api")!,
            session: .shared,
            clientMetadata: .init(
                packageName: "com.kairoid.Kairo",
                versionCode: "16",
                versionName: "1.0"
            )
        )

        let request = try client.makeURLRequest(
            for: NetworkRequest(
                path: "/candidate/profile",
                method: .post,
                headers: ["Authorization": "Bearer token"],
                queryItems: [URLQueryItem(name: "page", value: "1")],
                body: Data("payload".utf8)
            )
        )

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/candidate/profile?page=1")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-KairoID-Platform"), "ios")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-KairoID-Package"), "com.kairoid.Kairo")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-KairoID-Version-Code"), "16")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-KairoID-Version-Name"), "1.0")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-KairoID-Capabilities"),
            "nullable-employment-type-v1"
        )
        XCTAssertEqual(request.httpBody, Data("payload".utf8))
    }

    func test_clientMetadataOverridesCallerSpoofing() throws {
        let client = URLSessionNetworkClient(
            baseURL: URL(string: "https://example.com/api")!,
            session: .shared,
            clientMetadata: .init(
                packageName: "com.kairoid.Kairo",
                versionCode: "16",
                versionName: "1.0"
            )
        )

        let request = try client.makeURLRequest(
            for: NetworkRequest(
                path: "/employments/",
                headers: ["X-KairoID-Capabilities": "untrusted-capability"]
            )
        )

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-KairoID-Capabilities"),
            "nullable-employment-type-v1"
        )
    }

    func test_makeURLRequestPreservesExplicitTrailingSlash() throws {
        let client = URLSessionNetworkClient(
            baseURL: URL(string: "https://example.com/api/v1")!,
            session: .shared
        )

        let request = try client.makeURLRequest(
            for: NetworkRequest(path: "/employments/")
        )

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/v1/employments/")
    }
}
