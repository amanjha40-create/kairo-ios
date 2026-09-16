import Foundation
import UniformTypeIdentifiers

nonisolated enum ProtectedDocumentError: Error, LocalizedError, Equatable, Sendable {
    case unavailable, unsupportedType, tooLarge, invalidBytes, connection

    var errorDescription: String? {
        switch self {
        case .unavailable: "This document is unavailable. Refresh and try again."
        case .unsupportedType: "This document type cannot be previewed securely."
        case .tooLarge: "This document exceeds the 50 MB preview limit."
        case .invalidBytes: "The document response was incomplete or invalid."
        case .connection: "The document could not be loaded. Check your connection and try again."
        }
    }
}

nonisolated struct ProtectedDocumentContent: Sendable {
    static let maximumBytes = 50 * 1_024 * 1_024
    let data: Data
    let contentType: String
    let filename: String
    var fileExtension: String { UTType(mimeType: contentType)?.preferredFilenameExtension ?? "pdf" }

    init(response: NetworkResponse) throws {
        guard response.statusCode == 200 else { throw ProtectedDocumentError.unavailable }
        contentType = try Self.validateHeaders(response.headers)
        guard !response.data.isEmpty else { throw ProtectedDocumentError.invalidBytes }
        guard response.data.count <= Self.maximumBytes else { throw ProtectedDocumentError.tooLarge }
        if let length = response.headerValue(for: "Content-Length"), Int(length) != response.data.count {
            throw ProtectedDocumentError.invalidBytes
        }
        data = response.data
        filename = Self.safeFilename(response.headerValue(for: "Content-Disposition"), mime: contentType)
    }

    static func validateHeaders(_ headers: [String: String]) throws -> String {
        let headers = headers.reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
        if let length = headers["content-length"] {
            guard let count = Int(length), count >= 0 else { throw ProtectedDocumentError.invalidBytes }
            guard count <= maximumBytes else { throw ProtectedDocumentError.tooLarge }
        }
        let mime = headers["content-type"]?.split(separator: ";").first?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard SecureDocumentTransferClient.vaultContentTypes.contains(mime) else {
            throw ProtectedDocumentError.unsupportedType
        }
        return mime
    }

    private static func safeFilename(_ disposition: String?, mime: String) -> String {
        let suffix = UTType(mimeType: mime)?.preferredFilenameExtension ?? "pdf"
        let fallback = "Document.\(suffix)"
        let parameters = disposition?.split(separator: ";").dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        var candidate: String?
        if let encoded = parameters.first(where: { $0.lowercased().hasPrefix("filename*=") }) {
            let value = String(encoded.dropFirst(10)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            candidate = value.split(separator: "'", maxSplits: 2).last.flatMap { String($0).removingPercentEncoding }
        } else if let plain = parameters.first(where: { $0.lowercased().hasPrefix("filename=") }) {
            candidate = String(plain.dropFirst(9)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        guard let name = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty, name.count <= 200, !name.hasPrefix("."),
              !name.contains("/"), !name.contains("\\"), !name.contains(":"),
              name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              UTType(filenameExtension: URL(fileURLWithPath: name).pathExtension)?.preferredMIMEType == mime
        else { return fallback }
        return name
    }
}

/// A dedicated ephemeral, bounded byte stream. Never logs request URLs or server bodies.
nonisolated enum ProtectedDocumentTransport {
    static func configuration(protocolClasses: [AnyClass]? = nil) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.protocolClasses = protocolClasses
        return configuration
    }

    static func send(_ request: URLRequest, protocolClasses: [AnyClass]? = nil,
                     maximumBytes: Int = ProtectedDocumentContent.maximumBytes) async throws -> NetworkResponse {
        guard request.url?.scheme?.lowercased() == "https" else { throw ProtectedDocumentError.unavailable }
        let session = URLSession(configuration: configuration(protocolClasses: protocolClasses),
                                 delegate: NoDocumentRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw ProtectedDocumentError.unavailable }
            // Do not read or display error bodies, Location headers, or storage URLs.
            guard http.statusCode == 200 else {
                if let error = APIError.decode(from: Data(), statusCode: http.statusCode) {
                    throw NetworkError.api(error)
                }
                throw ProtectedDocumentError.unavailable
            }
            let headers = http.allHeaderFields.reduce(into: [String: String]()) {
                if let key = $1.key as? String { $0[key.lowercased()] = String(describing: $1.value) }
            }
            _ = try ProtectedDocumentContent.validateHeaders(headers)
            var data = Data()
            for try await byte in bytes {
                guard data.count < min(maximumBytes, ProtectedDocumentContent.maximumBytes) else { throw ProtectedDocumentError.tooLarge }
                data.append(byte)
            }
            try Task.checkCancellation()
            return NetworkResponse(data: data, statusCode: http.statusCode, headers: headers)
        } catch is CancellationError { throw CancellationError() }
        catch let error as NetworkError { throw error }
        catch let error as ProtectedDocumentError { throw error }
        catch { throw ProtectedDocumentError.connection }
    }
}

nonisolated final class NoDocumentRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

/// Owns only files created here; session transitions invalidate in-flight preview generations.
@MainActor
final class DocumentPreviewFileStore {
    static let shared = DocumentPreviewFileStore()
    static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]
    private(set) var generation = UUID()
    private var files: Set<URL> = []

    func write(_ content: ProtectedDocumentContent, generation: UUID) throws -> URL {
        guard generation == self.generation else { throw CancellationError() }
        try Task.checkCancellation()
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairoid-document-\(UUID().uuidString).\(content.fileExtension)")
        do {
            try content.data.write(to: file, options: Self.writeOptions)
            var excludedFile = file
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try excludedFile.setResourceValues(values)
            files.insert(file)
            return file
        } catch {
            try? FileManager.default.removeItem(at: file)
            throw error
        }
    }

    func remove(_ file: URL) {
        guard files.remove(file) != nil else { return }
        try? FileManager.default.removeItem(at: file)
    }

    func clear() {
        generation = UUID()
        for file in files { try? FileManager.default.removeItem(at: file) }
        files.removeAll()
    }
}
