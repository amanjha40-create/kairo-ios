import CoreGraphics
import Foundation

nonisolated struct PassportPDFArtifact: Identifiable, Equatable, Sendable {
    let id: UUID
    let fileURL: URL
    let filename: String
    let byteCount: Int

    init(
        id: UUID = UUID(),
        fileURL: URL,
        filename: String,
        byteCount: Int
    ) {
        self.id = id
        self.fileURL = fileURL
        self.filename = filename
        self.byteCount = byteCount
    }
}

nonisolated enum PassportPDFExportError: Error, Equatable, LocalizedError, Sendable {
    case invalidContentType
    case emptyDocument
    case malformedDocument
    case temporaryStorageUnavailable
    case unavailableInDemoMode

    var errorDescription: String? {
        switch self {
        case .invalidContentType:
            "Kairo received an unexpected file type instead of a Passport PDF."
        case .emptyDocument:
            "Kairo received an empty Passport PDF."
        case .malformedDocument:
            "Kairo received a Passport PDF that could not be opened safely."
        case .temporaryStorageUnavailable:
            "Kairo could not prepare temporary storage for the Passport PDF."
        case .unavailableInDemoMode:
            "PDF export is unavailable in Demo Mode because Demo Mode never calls the live Passport service."
        }
    }
}

protocol PassportPDFExportServiceProtocol: Sendable {
    func exportPassportPDF() async throws -> PassportPDFArtifact
    func removeArtifact(_ artifact: PassportPDFArtifact) async
    func removeAllArtifacts() async
}

actor PassportPDFExportService: PassportPDFExportServiceProtocol {
    nonisolated static let fallbackFilename = "Kairo-Trust-Passport.pdf"

    private let sessionService: any SessionServiceProtocol
    private let exportDirectoryURL: URL

    init(
        sessionService: any SessionServiceProtocol,
        temporaryDirectory: URL? = nil
    ) {
        self.sessionService = sessionService
        exportDirectoryURL = (temporaryDirectory ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("KairoPassportPDFExports", isDirectory: true)

        // A previous process may have ended before its presentation callback ran.
        try? FileManager.default.removeItem(at: exportDirectoryURL)
    }

    func exportPassportPDF() async throws -> PassportPDFArtifact {
        removeAllArtifactsImmediately()

        let response = try await sessionService.sendAuthenticatedResponse(
            NetworkRequest(
                path: "/passport/me/pdf",
                headers: ["Accept": "application/pdf"]
            )
        )

        try Self.validate(response: response)

        let filename = Self.safeFilename(
            from: response.headerValue(for: "Content-Disposition")
        )
        let artifactDirectory = exportDirectoryURL
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = artifactDirectory.appendingPathComponent(filename, isDirectory: false)

        do {
            try FileManager.default.createDirectory(
                at: artifactDirectory,
                withIntermediateDirectories: true
            )
            try response.data.write(to: fileURL, options: [.atomic])

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableFileURL = fileURL
            try? mutableFileURL.setResourceValues(resourceValues)

            let writtenData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            guard writtenData.count == response.data.count,
                  Self.isValidPDF(writtenData) else {
                try? FileManager.default.removeItem(at: artifactDirectory)
                throw PassportPDFExportError.temporaryStorageUnavailable
            }

            return PassportPDFArtifact(
                fileURL: fileURL,
                filename: filename,
                byteCount: writtenData.count
            )
        } catch let error as PassportPDFExportError {
            throw error
        } catch {
            try? FileManager.default.removeItem(at: artifactDirectory)
            throw PassportPDFExportError.temporaryStorageUnavailable
        }
    }

    func removeArtifact(_ artifact: PassportPDFArtifact) async {
        let artifactDirectory = artifact.fileURL.deletingLastPathComponent()
        guard artifactDirectory.deletingLastPathComponent() == exportDirectoryURL else { return }
        try? FileManager.default.removeItem(at: artifactDirectory)
    }

    func removeAllArtifacts() async {
        removeAllArtifactsImmediately()
    }

    nonisolated static func safeFilename(from contentDisposition: String?) -> String {
        guard let candidate = filenameCandidate(from: contentDisposition) else {
            return fallbackFilename
        }

        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 120,
              !trimmed.hasPrefix("."),
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              !trimmed.contains(":"),
              trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              URL(fileURLWithPath: trimmed).pathExtension.lowercased() == "pdf"
        else {
            return fallbackFilename
        }

        return trimmed
    }

    private func removeAllArtifactsImmediately() {
        try? FileManager.default.removeItem(at: exportDirectoryURL)
    }

    private nonisolated static func validate(response: NetworkResponse) throws {
        guard let contentType = response.headerValue(for: "Content-Type")?
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              contentType == "application/pdf" else {
            throw PassportPDFExportError.invalidContentType
        }

        guard !response.data.isEmpty else {
            throw PassportPDFExportError.emptyDocument
        }

        guard isValidPDF(response.data) else {
            throw PassportPDFExportError.malformedDocument
        }
    }

    private nonisolated static func isValidPDF(_ data: Data) -> Bool {
        let signature = Data("%PDF-".utf8)
        guard data.count >= signature.count,
              data.prefix(signature.count) == signature,
              let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              document.numberOfPages > 0 else {
            return false
        }

        return true
    }

    private nonisolated static func filenameCandidate(from contentDisposition: String?) -> String? {
        guard let contentDisposition else { return nil }

        let parameters = contentDisposition
            .split(separator: ";", omittingEmptySubsequences: true)
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if let encoded = parameters.first(where: { $0.lowercased().hasPrefix("filename*=") }) {
            let value = String(encoded.dropFirst("filename*=".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let encodedFilename = value.split(separator: "'", maxSplits: 2).last.map(String.init) ?? value
            return encodedFilename.removingPercentEncoding
        }

        guard let plain = parameters.first(where: { $0.lowercased().hasPrefix("filename=") }) else {
            return nil
        }

        return String(plain.dropFirst("filename=".count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

actor UnavailablePassportPDFExportService: PassportPDFExportServiceProtocol {
    func exportPassportPDF() async throws -> PassportPDFArtifact {
        throw PassportPDFExportError.unavailableInDemoMode
    }

    func removeArtifact(_ artifact: PassportPDFArtifact) async {
        _ = artifact
    }

    func removeAllArtifacts() async {}
}
