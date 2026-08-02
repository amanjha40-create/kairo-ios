import Foundation

struct URLSessionNetworkClient: NetworkClient {
    let baseURL: URL
    let session: URLSession

    func send(_ request: NetworkRequest) async throws -> Data {
        let urlRequest = try makeURLRequest(for: request)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                if let apiError = APIError.decode(from: data, statusCode: httpResponse.statusCode) {
                    throw NetworkError.api(apiError)
                }

                throw NetworkError.invalidResponse
            }

            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }
    }

    func makeURLRequest(for request: NetworkRequest) throws -> URLRequest {
        let relativePath = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var resolvedURL = baseURL

        if !relativePath.isEmpty {
            for component in relativePath.split(separator: "/") {
                resolvedURL.appendPathComponent(String(component))
            }
        }

        guard var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }

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
}
