import Foundation

/// Capability-bearing JSON never enters diagnostics, cookie storage, URL caches, or redirects.
nonisolated enum PrivateDocumentPackTransport {
    static func send(_ request: URLRequest, protocolClasses: [AnyClass]? = nil) async throws -> NetworkResponse {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.protocolClasses = protocolClasses
        let session = URLSession(configuration: configuration, delegate: NoDocumentRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                // Do not read error bodies: they may echo inputs or credentials.
                if let error = APIError.decode(from: Data(), statusCode: http.statusCode) { throw NetworkError.api(error) }
                throw NetworkError.invalidResponse
            }
            guard http.mimeType == "application/json", response.expectedContentLength <= 8 * 1_024 * 1_024 else { throw NetworkError.invalidResponse }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 8 * 1_024 * 1_024 else { throw NetworkError.invalidResponse }
                data.append(byte)
            }
            try Task.checkCancellation()
            return NetworkResponse(data: data, statusCode: http.statusCode)
        } catch is CancellationError { throw CancellationError() }
        catch let error as NetworkError { throw error }
        catch { throw NetworkError.transport("Private request could not be completed.") }
    }
}
