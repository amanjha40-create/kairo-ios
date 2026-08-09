import CryptoKit
import Foundation
import UniformTypeIdentifiers

protocol ResumeImportServiceProtocol: Sendable {
    func prepareSelection(from pickedURL: URL) throws -> ResumeImportPreparedSelection
    func cleanupSelection(at temporaryFileURL: URL)
    func restoreLatestWorkflow() async throws -> ResumeImportWorkflowSnapshot?
    func upload(selection: ResumeImportPreparedSelection) async throws -> ResumeRecord
    func startProcessing(resumeID: String) async throws -> ResumeProcessJob
    func processingStatus(resumeID: String) async throws -> ResumeProcessJob
    func loadOrCreateReviewSession(resumeID: String) async throws -> ResumeReviewSession
    func refreshReviewSession(reviewID: String) async throws -> ResumeReviewSession
    func updateReviewItem(
        reviewID: String,
        itemID: String,
        payload: ResumeReviewItemUpdateRequestDTO
    ) async throws -> ResumeReviewSession
    func validateReview(reviewID: String, expectedVersion: Int) async throws -> ResumeReviewPlan
    func importReview(
        reviewID: String,
        expectedVersion: Int,
        idempotencyKey: String
    ) async throws -> ResumeImportBatch
    func latestImportStatus(reviewID: String) async throws -> ResumeImportBatch
    func reconcileImportRecovery(reviewID: String) async throws -> ResumeImportRecoveryState
    func completeOnboardingIfNeeded() async throws -> ResumeImportCompletionResult
}

enum ResumeImportServiceError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedFileType
    case emptyFile
    case fileTooLarge(maximumBytes: Int)
    case inaccessibleFile
    case storageUploadFailed
    case importBlocked(message: String)
    case onboardingIncomplete(OnboardingStatusResponseDTO)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            "Choose a PDF or DOCX file."
        case .emptyFile:
            "That file is empty. Choose another resume."
        case .fileTooLarge:
            "Your resume must be 10 MB or smaller."
        case .inaccessibleFile:
            "Kairo couldn't read that file. Choose another resume to continue."
        case .storageUploadFailed:
            "Kairo couldn't upload that resume. Check your connection and try again."
        case .importBlocked(let message):
            message
        case .onboardingIncomplete:
            "Kairo saved your resume import, but onboarding is still incomplete. Please try again."
        }
    }
}

actor ResumeImportService: ResumeImportServiceProtocol {
    private enum Constants {
        static let restoreListLimit = 10
    }

    private let sessionService: any SessionServiceProtocol
    private let authService: any AuthServiceProtocol
    private let consentVersion: String
    private let decoder = APIJSONCoder.makeDecoder()
    private let encoder = APIJSONCoder.makeEncoder()
    private let storageSession: URLSession

    init(
        sessionService: any SessionServiceProtocol,
        authService: any AuthServiceProtocol,
        consentVersion: String = AppConfiguration.resumeImportConsentVersion,
        storageSession: URLSession = .shared
    ) {
        self.sessionService = sessionService
        self.authService = authService
        self.consentVersion = consentVersion
        self.storageSession = storageSession
    }

    nonisolated func prepareSelection(from pickedURL: URL) throws -> ResumeImportPreparedSelection {
        let file: ResumeImportFile
        do {
            file = try ResumeImportFile.make(from: pickedURL)
        } catch let error as ResumeImportSelectionError {
            throw error
        } catch {
            throw ResumeImportServiceError.inaccessibleFile
        }

        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "KairoResumeImports",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let temporaryFileURL = tempDirectory.appendingPathComponent(
            "\(UUID().uuidString).\(file.fileExtension)",
            isDirectory: false
        )

        do {
            if FileManager.default.fileExists(atPath: temporaryFileURL.path) {
                try FileManager.default.removeItem(at: temporaryFileURL)
            }
            try FileManager.default.copyItem(at: pickedURL, to: temporaryFileURL)
        } catch {
            throw ResumeImportServiceError.inaccessibleFile
        }

        return ResumeImportPreparedSelection(
            file: file,
            temporaryFileURL: temporaryFileURL
        )
    }

    nonisolated func cleanupSelection(at temporaryFileURL: URL) {
        try? FileManager.default.removeItem(at: temporaryFileURL)
    }

    func restoreLatestWorkflow() async throws -> ResumeImportWorkflowSnapshot? {
        let page = try await loadResumes(offset: 0, limit: Constants.restoreListLimit)
        guard
            let latestResume = page.items
                .map(ResumeImportMapper.map)
                .filter({ $0.uploadStatus != .deleted && $0.processingStatus != .deleted })
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first
        else {
            return nil
        }

        let reviewSession: ResumeReviewSession?
        if latestResume.processingStatus == .needsReview {
            reviewSession = try? await reviewSessionByResume(resumeID: latestResume.id)
        } else {
            reviewSession = nil
        }

        let importBatch: ResumeImportBatch?
        if let reviewSession,
           reviewSession.status == .importing ||
           reviewSession.status == .imported ||
           reviewSession.status == .partiallyImported {
            importBatch = try? await latestImportStatus(reviewID: reviewSession.id)
        } else {
            importBatch = nil
        }

        return ResumeImportWorkflowSnapshot(
            resume: latestResume,
            reviewSession: reviewSession,
            importBatch: importBatch
        )
    }

    func upload(selection: ResumeImportPreparedSelection) async throws -> ResumeRecord {
        let intent = try await createUploadIntent(for: selection.file)
        try await uploadToStorage(
            fileURL: selection.temporaryFileURL,
            uploadURL: intent.uploadURL,
            contentType: selection.file.mimeType
        )
        let checksum = try checksumHex(for: selection.temporaryFileURL)
        let completed: ResumeRecordDTO = try await send(
            NetworkRequest(
                path: "/resumes/\(intent.resumeID)/complete-upload",
                method: .post,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try encoder.encode(
                    ResumeCompleteUploadRequestDTO(checksumSHA256: checksum)
                )
            ),
            responseType: ResumeRecordDTO.self
        )
        return ResumeImportMapper.map(completed)
    }

    func startProcessing(resumeID: String) async throws -> ResumeProcessJob {
        let dto: ResumeProcessDTO = try await send(
            NetworkRequest(
                path: "/resumes/\(resumeID)/process",
                method: .post,
                headers: ["Accept": "application/json"]
            ),
            responseType: ResumeProcessDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    func processingStatus(resumeID: String) async throws -> ResumeProcessJob {
        let dto: ResumeProcessDTO = try await send(
            NetworkRequest(
                path: "/resumes/\(resumeID)/status",
                headers: ["Accept": "application/json"]
            ),
            responseType: ResumeProcessDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    func loadOrCreateReviewSession(resumeID: String) async throws -> ResumeReviewSession {
        let dto: ResumeReviewSessionDTO = try await send(
            NetworkRequest(
                path: "/resumes/\(resumeID)/review-session",
                method: .post,
                headers: ["Accept": "application/json"]
            ),
            responseType: ResumeReviewSessionDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    func refreshReviewSession(reviewID: String) async throws -> ResumeReviewSession {
        let dto: ResumeReviewSessionDTO = try await send(
            NetworkRequest(
                path: "/resume-reviews/\(reviewID)",
                headers: ["Accept": "application/json"]
            ),
            responseType: ResumeReviewSessionDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    func updateReviewItem(
        reviewID: String,
        itemID: String,
        payload: ResumeReviewItemUpdateRequestDTO
    ) async throws -> ResumeReviewSession {
        _ = try await send(
            NetworkRequest(
                path: "/resume-reviews/\(reviewID)/items/\(itemID)",
                method: .patch,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try encoder.encode(payload)
            ),
            responseType: ResumeReviewItemDTO.self
        )

        return try await refreshReviewSession(reviewID: reviewID)
    }

    func validateReview(reviewID: String, expectedVersion: Int) async throws -> ResumeReviewPlan {
        let dto: ResumeReviewPlanDTO = try await send(
            NetworkRequest(
                path: "/resume-reviews/\(reviewID)/validate",
                method: .post,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try encoder.encode(
                    ResumeReviewValidateRequestDTO(expectedVersion: expectedVersion)
                )
            ),
            responseType: ResumeReviewPlanDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    func importReview(
        reviewID: String,
        expectedVersion: Int,
        idempotencyKey: String
    ) async throws -> ResumeImportBatch {
        let dto: ResumeImportBatchDTO = try await send(
            NetworkRequest(
                path: "/resume-reviews/\(reviewID)/import",
                method: .post,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try encoder.encode(
                    ResumeReviewImportRequestDTO(
                        expectedVersion: expectedVersion,
                        idempotencyKey: idempotencyKey,
                        confirmed: true
                    )
                )
            ),
            responseType: ResumeImportBatchDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    func latestImportStatus(reviewID: String) async throws -> ResumeImportBatch {
        let dto: ResumeImportBatchDTO = try await send(
            NetworkRequest(
                path: "/resume-reviews/\(reviewID)/import-status",
                headers: ["Accept": "application/json"]
            ),
            responseType: ResumeImportBatchDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    func reconcileImportRecovery(reviewID: String) async throws -> ResumeImportRecoveryState {
        let reviewSession = try await refreshReviewSession(reviewID: reviewID)
        let importBatch = try await authoritativeImportBatch(for: reviewSession)

        switch reviewSession.status {
        case .imported:
            let completionResult = try await completeOnboardingIfNeeded()
            return ResumeImportRecoveryState(
                reviewSession: reviewSession,
                importBatch: importBatch,
                completionResult: completionResult,
                disposition: .importCompleted
            )
        case .partiallyImported:
            return ResumeImportRecoveryState(
                reviewSession: reviewSession,
                importBatch: importBatch,
                completionResult: nil,
                disposition: .importPartiallyCompleted
            )
        case .importing:
            guard let importBatch else {
                return ResumeImportRecoveryState(
                    reviewSession: reviewSession,
                    importBatch: nil,
                    completionResult: nil,
                    disposition: .noImportToResume
                )
            }

            if importBatch.isCompletedWithoutHardFailures {
                let completionResult = try await completeOnboardingIfNeeded()
                return ResumeImportRecoveryState(
                    reviewSession: reviewSession,
                    importBatch: importBatch,
                    completionResult: completionResult,
                    disposition: .importCompleted
                )
            }

            if importBatch.isPartiallyCompleted {
                return ResumeImportRecoveryState(
                    reviewSession: reviewSession,
                    importBatch: importBatch,
                    completionResult: nil,
                    disposition: .importPartiallyCompleted
                )
            }

            return ResumeImportRecoveryState(
                reviewSession: reviewSession,
                importBatch: importBatch,
                completionResult: nil,
                disposition: .importInProgress
            )
        case .draft, .reviewing, .readyToImport, .cancelled, .failed, .unknown:
            return ResumeImportRecoveryState(
                reviewSession: reviewSession,
                importBatch: importBatch,
                completionResult: nil,
                disposition: .noImportToResume
            )
        }
    }

    func completeOnboardingIfNeeded() async throws -> ResumeImportCompletionResult {
        let currentUser = try await authService.currentUser().asDomainModel()
        let status = try await authService.onboardingStatus()

        if status.isOnboardingComplete {
            return ResumeImportCompletionResult(
                user: currentUser,
                onboardingStatus: status
            )
        }

        guard status.missingRequirements.isEmpty else {
            return ResumeImportCompletionResult(
                user: currentUser,
                onboardingStatus: status
            )
        }

        if !status.isOnboardingComplete {
            _ = try await sessionService.sendAuthenticated(
                NetworkRequest(
                    path: "/users/me/complete-onboarding",
                    method: .post,
                    headers: ["Accept": "application/json"]
                )
            )
        }

        let refreshedUser = try await authService.currentUser().asDomainModel()
        let refreshedStatus = try await authService.onboardingStatus()

        guard refreshedStatus.isOnboardingComplete else {
            throw ResumeImportServiceError.onboardingIncomplete(refreshedStatus)
        }

        return ResumeImportCompletionResult(
            user: refreshedUser,
            onboardingStatus: refreshedStatus
        )
    }

    private func authoritativeImportBatch(
        for reviewSession: ResumeReviewSession
    ) async throws -> ResumeImportBatch? {
        switch reviewSession.status {
        case .importing, .imported, .partiallyImported:
            do {
                return try await latestImportStatus(reviewID: reviewSession.id)
            } catch let error as NetworkError {
                if case .api(let apiError) = error, apiError.code == .notFound {
                    return nil
                }
                throw error
            }
        case .draft, .reviewing, .readyToImport, .cancelled, .failed, .unknown:
            return nil
        }
    }

    private func createUploadIntent(for file: ResumeImportFile) async throws -> ResumeUploadIntent {
        let dto: ResumeUploadIntentDTO = try await send(
            NetworkRequest(
                path: "/resumes/upload-intent",
                method: .post,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try encoder.encode(
                    ResumeUploadIntentRequestDTO(
                        originalFilename: file.fileName,
                        contentType: file.mimeType,
                        byteSize: file.byteSize,
                        consentVersion: consentVersion
                    )
                )
            ),
            responseType: ResumeUploadIntentDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    private func reviewSessionByResume(resumeID: String) async throws -> ResumeReviewSession {
        let dto: ResumeReviewSessionDTO = try await send(
            NetworkRequest(
                path: "/resumes/\(resumeID)/review-session",
                headers: ["Accept": "application/json"]
            ),
            responseType: ResumeReviewSessionDTO.self
        )
        return ResumeImportMapper.map(dto)
    }

    private func loadResumes(offset: Int, limit: Int) async throws -> ResumeListResponseDTO {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/resumes",
                headers: ["Accept": "application/json"],
                queryItems: [
                    URLQueryItem(name: "offset", value: String(offset)),
                    URLQueryItem(name: "limit", value: String(limit))
                ]
            )
        )
        return try decoder.decode(ResumeListResponseDTO.self, from: data)
    }

    private func send<Response: Decodable>(
        _ request: NetworkRequest,
        responseType: Response.Type
    ) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(request)
        return try decoder.decode(responseType, from: data)
    }

    private func uploadToStorage(
        fileURL: URL,
        uploadURL: URL,
        contentType: String
    ) async throws {
        guard uploadURL.scheme?.lowercased() == "https" else {
            throw ResumeImportServiceError.storageUploadFailed
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = HTTPMethod.put.rawValue
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await storageSession.upload(for: request, fromFile: fileURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode) else {
                throw ResumeImportServiceError.storageUploadFailed
            }
        } catch {
            if let serviceError = error as? ResumeImportServiceError {
                throw serviceError
            }
            throw ResumeImportServiceError.storageUploadFailed
        }
    }

    private func checksumHex(for fileURL: URL) throws -> String {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw ResumeImportServiceError.inaccessibleFile
        }

        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

actor DemoResumeImportService: ResumeImportServiceProtocol {
    nonisolated func prepareSelection(from pickedURL: URL) throws -> ResumeImportPreparedSelection {
        let file = try ResumeImportFile.make(from: pickedURL)
        return ResumeImportPreparedSelection(file: file, temporaryFileURL: pickedURL)
    }

    nonisolated func cleanupSelection(at temporaryFileURL: URL) {
        _ = temporaryFileURL
    }

    func restoreLatestWorkflow() async throws -> ResumeImportWorkflowSnapshot? {
        nil
    }

    func upload(selection: ResumeImportPreparedSelection) async throws -> ResumeRecord {
        _ = selection
        throw NetworkError.unavailableInDemoMode
    }

    func startProcessing(resumeID: String) async throws -> ResumeProcessJob {
        _ = resumeID
        throw NetworkError.unavailableInDemoMode
    }

    func processingStatus(resumeID: String) async throws -> ResumeProcessJob {
        _ = resumeID
        throw NetworkError.unavailableInDemoMode
    }

    func loadOrCreateReviewSession(resumeID: String) async throws -> ResumeReviewSession {
        _ = resumeID
        throw NetworkError.unavailableInDemoMode
    }

    func refreshReviewSession(reviewID: String) async throws -> ResumeReviewSession {
        _ = reviewID
        throw NetworkError.unavailableInDemoMode
    }

    func updateReviewItem(
        reviewID: String,
        itemID: String,
        payload: ResumeReviewItemUpdateRequestDTO
    ) async throws -> ResumeReviewSession {
        _ = (reviewID, itemID, payload)
        throw NetworkError.unavailableInDemoMode
    }

    func validateReview(reviewID: String, expectedVersion: Int) async throws -> ResumeReviewPlan {
        _ = (reviewID, expectedVersion)
        throw NetworkError.unavailableInDemoMode
    }

    func importReview(
        reviewID: String,
        expectedVersion: Int,
        idempotencyKey: String
    ) async throws -> ResumeImportBatch {
        _ = (reviewID, expectedVersion, idempotencyKey)
        throw NetworkError.unavailableInDemoMode
    }

    func latestImportStatus(reviewID: String) async throws -> ResumeImportBatch {
        _ = reviewID
        throw NetworkError.unavailableInDemoMode
    }

    func reconcileImportRecovery(reviewID: String) async throws -> ResumeImportRecoveryState {
        _ = reviewID
        throw NetworkError.unavailableInDemoMode
    }

    func completeOnboardingIfNeeded() async throws -> ResumeImportCompletionResult {
        throw NetworkError.unavailableInDemoMode
    }
}
