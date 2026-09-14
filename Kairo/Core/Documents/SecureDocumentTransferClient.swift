import CryptoKit
import Foundation
import UniformTypeIdentifiers

nonisolated struct SecureDocumentSelection: Equatable, Sendable {
    let filename: String
    let contentType: String
    let data: Data

    var checksumSHA256: String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated enum SecureDocumentTransferError: Error, LocalizedError, Equatable, Sendable {
    case emptyFile
    case fileTooLarge(maximumMegabytes: Int)
    case unsupportedFileType
    case invalidUploadURL
    case storageUploadFailed
    case invalidDownloadURL

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            "Choose a non-empty file."
        case .fileTooLarge(let maximumMegabytes):
            "Choose a file no larger than \(maximumMegabytes) MB."
        case .unsupportedFileType:
            "Choose a PDF, JPEG, PNG, or WebP file."
        case .invalidUploadURL:
            "KairoID received an invalid secure upload destination."
        case .storageUploadFailed:
            "The secure document upload did not complete. Try again."
        case .invalidDownloadURL:
            "KairoID received an invalid secure document destination."
        }
    }
}

actor SecureDocumentTransferClient {
    static let careerContentTypes: Set<String> = [
        "application/pdf",
        "image/jpeg",
        "image/png"
    ]

    static let vaultContentTypes: Set<String> = careerContentTypes.union(["image/webp"])

    private let session: URLSession

    init(session: URLSession = SecureDocumentTransferClient.makeEphemeralSession()) {
        self.session = session
    }

    func prepare(
        fileURL: URL,
        maximumBytes: Int,
        allowedContentTypes: Set<String>
    ) throws -> SecureDocumentSelection {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        guard !data.isEmpty else {
            throw SecureDocumentTransferError.emptyFile
        }
        guard data.count <= maximumBytes else {
            throw SecureDocumentTransferError.fileTooLarge(
                maximumMegabytes: maximumBytes / (1_024 * 1_024)
            )
        }

        let contentType = (
            try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType
        ) ?? Self.mimeType(for: fileURL.pathExtension)

        guard allowedContentTypes.contains(contentType) else {
            throw SecureDocumentTransferError.unsupportedFileType
        }

        return SecureDocumentSelection(
            filename: fileURL.lastPathComponent,
            contentType: contentType,
            data: data
        )
    }

    func upload(
        _ selection: SecureDocumentSelection,
        to uploadURL: URL,
        requiredHeaders: [String: String]
    ) async throws {
        guard uploadURL.scheme?.lowercased() == "https" else {
            throw SecureDocumentTransferError.invalidUploadURL
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        for (header, value) in requiredHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue(selection.contentType, forHTTPHeaderField: "Content-Type")
        }

        let (_, response) = try await session.upload(for: request, from: selection.data)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw SecureDocumentTransferError.storageUploadFailed
        }
    }

    nonisolated static func validatedDownloadURL(_ url: URL) throws -> URL {
        guard url.scheme?.lowercased() == "https" else {
            throw SecureDocumentTransferError.invalidDownloadURL
        }
        return url
    }

    private nonisolated static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "pdf": "application/pdf"
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        case "webp": "image/webp"
        default: "application/octet-stream"
        }
    }

    private nonisolated static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        return URLSession(configuration: configuration)
    }
}
