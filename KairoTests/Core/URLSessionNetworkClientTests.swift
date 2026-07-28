import Foundation
import XCTest
@testable import Kairo

final class URLSessionNetworkClientTests: XCTestCase {
    func test_makeURLRequestBuildsPathAndQueryItems() throws {
        let client = URLSessionNetworkClient(
            baseURL: URL(string: "https://example.com/api")!,
            session: .shared
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
        XCTAssertEqual(request.httpBody, Data("payload".utf8))
    }
}
