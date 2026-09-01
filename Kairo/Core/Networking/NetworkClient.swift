import Foundation

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

nonisolated struct NetworkRequest: Sendable {
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

nonisolated struct NetworkResponse: Equatable, Sendable {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    init(
        data: Data,
        statusCode: Int,
        headers: [String: String] = [:]
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers.reduce(into: [:]) { result, entry in
            result[entry.key.lowercased()] = entry.value
        }
    }

    func headerValue(for name: String) -> String? {
        headers[name.lowercased()]
    }
}

enum NetworkError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case api(APIError)
    case unavailableInDemoMode
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The request URL could not be constructed."
        case .invalidResponse:
            "The server response was invalid."
        case .api(let error):
            error.message
        case .unavailableInDemoMode:
            "Networking is disabled while Demo Mode is enabled."
        case .transport(let message):
            message
        }
    }
}

protocol NetworkClient: Sendable {
    func send(_ request: NetworkRequest) async throws -> Data
    func sendResponse(_ request: NetworkRequest) async throws -> NetworkResponse
}

extension NetworkClient {
    func sendResponse(_ request: NetworkRequest) async throws -> NetworkResponse {
        NetworkResponse(data: try await send(request), statusCode: 200)
    }

    func sendJSON<Body: Encodable>(
        path: String,
        method: HTTPMethod,
        body: Body,
        headers: [String: String] = [:]
    ) async throws -> Data {
        var requestHeaders = headers
        requestHeaders["Content-Type"] = requestHeaders["Content-Type"] ?? "application/json"
        requestHeaders["Accept"] = requestHeaders["Accept"] ?? "application/json"

        let request = NetworkRequest(
            path: path,
            method: method,
            headers: requestHeaders,
            body: try APIJSONCoder.makeEncoder().encode(body)
        )
        return try await send(request)
    }

    func decode<T: Decodable>(
        _ type: T.Type,
        from request: NetworkRequest,
        decoder: JSONDecoder? = nil
    ) async throws -> T {
        let data = try await send(request)
        return try (decoder ?? APIJSONCoder.makeDecoder()).decode(type, from: data)
    }
}
