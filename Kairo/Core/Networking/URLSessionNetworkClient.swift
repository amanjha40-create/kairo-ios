import Foundation

struct URLSessionNetworkClient: NetworkClient {
    let baseURL: URL
    let session: URLSession

    func send(_ request: NetworkRequest) async throws -> Data {
        try await sendResponse(request).data
    }

    func sendResponse(_ request: NetworkRequest) async throws -> NetworkResponse {
        let urlRequest = try makeURLRequest(for: request)
        #if DEBUG
        NetworkDiagnostics.logRequest(
            method: request.method.rawValue,
            url: urlRequest.url!,
            requestID: urlRequest.value(forHTTPHeaderField: "X-Request-ID"),
            correlationID: urlRequest.value(forHTTPHeaderField: "X-Correlation-ID")
        )
        #endif

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            NetworkDiagnostics.logResponse(
                url: urlRequest.url!,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                requestID: urlRequest.value(forHTTPHeaderField: "X-Request-ID"),
                correlationID: urlRequest.value(forHTTPHeaderField: "X-Correlation-ID")
            )
            #endif

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                if let apiError = APIError.decode(from: data, statusCode: httpResponse.statusCode) {
                    throw NetworkError.api(apiError)
                }

                throw NetworkError.invalidResponse
            }

            let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, entry in
                guard let key = entry.key as? String else { return }
                result[key] = String(describing: entry.value)
            }

            return NetworkResponse(
                data: data,
                statusCode: httpResponse.statusCode,
                headers: headers
            )
        } catch let error as NetworkError {
            throw error
        } catch {
            #if DEBUG
            NetworkDiagnostics.logTransportError(
                url: urlRequest.url!,
                requestID: urlRequest.value(forHTTPHeaderField: "X-Request-ID"),
                correlationID: urlRequest.value(forHTTPHeaderField: "X-Correlation-ID"),
                error: error
            )
            #endif
            throw NetworkError.transport(error.localizedDescription)
        }
    }

    func makeURLRequest(for request: NetworkRequest) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }

        components.percentEncodedPath = resolvedPath(for: request.path, basePath: components.percentEncodedPath)
        components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        return urlRequest
    }

    private func resolvedPath(for requestPath: String, basePath: String) -> String {
        let normalizedBasePath: String
        if basePath == "/" {
            normalizedBasePath = ""
        } else if basePath.hasSuffix("/") {
            normalizedBasePath = String(basePath.dropLast())
        } else {
            normalizedBasePath = basePath
        }

        let normalizedRequestPath: String
        if requestPath.isEmpty {
            normalizedRequestPath = ""
        } else if requestPath.hasPrefix("/") {
            normalizedRequestPath = requestPath
        } else {
            normalizedRequestPath = "/\(requestPath)"
        }

        let combinedPath = normalizedBasePath + normalizedRequestPath
        return combinedPath.isEmpty ? "/" : combinedPath
    }
}
