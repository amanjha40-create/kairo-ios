import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Task {
            do {
                let (response, data) = try await MockURLProtocolStorage.shared.response(for: request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

actor MockURLProtocolStorage {
    static let shared = MockURLProtocolStorage()

    typealias Handler = @Sendable (URLRequest) async throws -> (HTTPURLResponse, Data)

    private var handler: Handler?
    private var recordedRequests: [URLRequest] = []

    func setHandler(_ handler: Handler?) {
        self.handler = handler
    }

    func reset() {
        handler = nil
        recordedRequests = []
    }

    func response(for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        recordedRequests.append(request)

        guard let handler else {
            throw URLError(.badServerResponse)
        }

        return try await handler(request)
    }

    func requests() -> [URLRequest] {
        recordedRequests
    }
}

func makeMockedURLSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}
