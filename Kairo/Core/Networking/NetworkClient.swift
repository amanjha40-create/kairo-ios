import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct NetworkRequest: Sendable {
    let path: String
    var method: HTTPMethod = .get
    var headers: [String: String] = [:]
    var queryItems: [URLQueryItem] = []
    var body: Data?

    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
    }
}

enum NetworkError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case unavailableInDemoMode
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The request URL could not be constructed."
        case .invalidResponse:
            "The server response was invalid."
        case .httpStatus(let code):
            "The server responded with HTTP status \(code)."
        case .unavailableInDemoMode:
            "Networking is disabled while Demo Mode is enabled."
        case .transport(let message):
            message
        }
    }
}

protocol NetworkClient: Sendable {
    func send(_ request: NetworkRequest) async throws -> Data
}

extension NetworkClient {
    func decode<T: Decodable>(
        _ type: T.Type,
        from request: NetworkRequest,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await send(request)
        return try decoder.decode(type, from: data)
    }
}
