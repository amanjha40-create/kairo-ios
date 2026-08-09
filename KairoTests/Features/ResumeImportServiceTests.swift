import Foundation
import XCTest
@testable import Kairo

final class ResumeImportServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_uploadIncludesConsentVersionUsesExactPDFMimeAndCompletesWithChecksumOnly() async throws {
        let service = try await makeService()
        let fileURL = try makeTemporaryResumeFile(
            named: "Aman_Jha_Resume.pdf",
            contents: Data("candidate resume".utf8)
        )
        let selection = ResumeImportPreparedSelection(
            file: try ResumeImportFile.make(from: fileURL, fileSizeOverride: 16),
            temporaryFileURL: fileURL
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("POST", "staging-api.kairoid.com", "/api/v1/resumes/upload-intent"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["original_filename"] as? String, "Aman_Jha_Resume.pdf")
                XCTAssertEqual(body["content_type"] as? String, "application/pdf")
                XCTAssertEqual(body["byte_size"] as? Int, 16)
                XCTAssertEqual(
                    body["consent_version"] as? String,
                    AppConfiguration.resumeImportConsentVersion
                )
                XCTAssertEqual(Set(body.keys), [
                    "original_filename",
                    "content_type",
                    "byte_size",
                    "consent_version"
                ])
                return (try Self.response(for: request, statusCode: 200), Self.uploadIntentPayload)
            case ("PUT", "uploads.example.com", "/candidate/resume_123"):
                XCTAssertEqual(request.url?.scheme?.lowercased(), "https")
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Content-Type"),
                    "application/pdf"
                )
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                XCTAssertNil(request.value(forHTTPHeaderField: "X-Request-ID"))
                XCTAssertNil(request.value(forHTTPHeaderField: "X-Correlation-ID"))
                return (try Self.response(for: request, statusCode: 200), Data())
            case ("POST", "staging-api.kairoid.com", "/api/v1/resumes/resume_123/complete-upload"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["checksum_sha256"] as? String, Self.expectedChecksum)
                XCTAssertEqual(Set(body.keys), ["checksum_sha256"])
                return (try Self.response(for: request, statusCode: 200), Self.completedResumePayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let resume = try await service.upload(selection: selection)

        XCTAssertEqual(resume.id, "resume_123")
        XCTAssertEqual(resume.processingStatus, .uploaded)
    }

    func test_prepareSelectionCopiesReadableFileIntoTemporaryLocation() async throws {
        let service = try await makeService()
        let sourceURL = try makeTemporaryResumeFile(
            named: "Aman_Jha_Resume.pdf",
            contents: Data("candidate resume".utf8)
        )

        let selection = try service.prepareSelection(from: sourceURL)

        XCTAssertEqual(selection.file.fileName, "Aman_Jha_Resume.pdf")
        XCTAssertEqual(selection.file.byteSize, 16)
        XCTAssertNotEqual(selection.temporaryFileURL, sourceURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: selection.temporaryFileURL.path))
    }

    func test_prepareSelectionMapsUnreadableMetadataFailureToInaccessibleFile() async throws {
        let service = try await makeService()
        let missingURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString).pdf"
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: missingURL.path))

        XCTAssertThrowsError(try service.prepareSelection(from: missingURL)) { error in
            XCTAssertEqual(error as? ResumeImportServiceError, .inaccessibleFile)
        }
    }

    func test_uploadUsesExactDOCXMimeForIntentAndS3Put() async throws {
        let service = try await makeService()
        let fileURL = try makeTemporaryResumeFile(
            named: "Aman_Jha_Resume.docx",
            contents: Data("candidate resume".utf8)
        )
        let selection = ResumeImportPreparedSelection(
            file: try ResumeImportFile.make(from: fileURL, fileSizeOverride: 16),
            temporaryFileURL: fileURL
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("POST", "staging-api.kairoid.com", "/api/v1/resumes/upload-intent"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(
                    body["content_type"] as? String,
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                )
                return (try Self.response(for: request, statusCode: 200), Self.uploadIntentPayload)
            case ("PUT", "uploads.example.com", "/candidate/resume_123"):
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Content-Type"),
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                )
                return (try Self.response(for: request, statusCode: 200), Data())
            case ("POST", "staging-api.kairoid.com", "/api/v1/resumes/resume_123/complete-upload"):
                return (try Self.response(for: request, statusCode: 200), Self.completedDOCXResumePayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let resume = try await service.upload(selection: selection)

        XCTAssertEqual(resume.contentType, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    }

    func test_uploadRejectsNonHTTPSPresignedURL() async throws {
        let service = try await makeService()
        let fileURL = try makeTemporaryResumeFile(
            named: "Aman_Jha_Resume.pdf",
            contents: Data("candidate resume".utf8)
        )
        let selection = ResumeImportPreparedSelection(
            file: try ResumeImportFile.make(from: fileURL, fileSizeOverride: 16),
            temporaryFileURL: fileURL
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("POST", "staging-api.kairoid.com", "/api/v1/resumes/upload-intent"):
                return (try Self.response(for: request, statusCode: 200), Self.httpUploadIntentPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        await XCTAssertThrowsErrorAsync(try await service.upload(selection: selection)) { error in
            XCTAssertEqual(error as? ResumeImportServiceError, .storageUploadFailed)
        }
    }

    func test_uploadSucceedsWhenUploadIntentOmitsObjectKey() async throws {
        let service = try await makeService()
        let fileURL = try makeTemporaryResumeFile(
            named: "Aman_Jha_Resume.pdf",
            contents: Data("candidate resume".utf8)
        )
        let selection = ResumeImportPreparedSelection(
            file: try ResumeImportFile.make(from: fileURL, fileSizeOverride: 16),
            temporaryFileURL: fileURL
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("POST", "staging-api.kairoid.com", "/api/v1/resumes/upload-intent"):
                return (try Self.response(for: request, statusCode: 200), Self.uploadIntentPayloadWithoutObjectKey)
            case ("PUT", "uploads.example.com", "/candidate/resume_123"):
                return (try Self.response(for: request, statusCode: 200), Data())
            case ("POST", "staging-api.kairoid.com", "/api/v1/resumes/resume_123/complete-upload"):
                return (try Self.response(for: request, statusCode: 200), Self.completedResumePayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let resume = try await service.upload(selection: selection)

        XCTAssertEqual(resume.id, "resume_123")
        XCTAssertEqual(resume.processingStatus, .uploaded)
    }

    func test_loadOrCreateReviewSessionUsesCreateOrReturnPOST() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/resumes/resume_123/review-session"):
                return (try Self.response(for: request, statusCode: 200), Self.reviewSessionPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let session = try await service.loadOrCreateReviewSession(resumeID: "resume_123")
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            ["POST /api/v1/resumes/resume_123/review-session"]
        )
        XCTAssertEqual(session.id, "review_123")
    }

    func test_restoreLatestWorkflowUsesReviewGETForRecovery() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resumes"):
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            case ("GET", "/api/v1/resumes/resume_123/review-session"):
                return (try Self.response(for: request, statusCode: 200), Self.reviewSessionPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let workflow = try await service.restoreLatestWorkflow()

        XCTAssertEqual(workflow?.resume.id, "resume_123")
        XCTAssertEqual(workflow?.reviewSession?.id, "review_123")
        XCTAssertNil(workflow?.importBatch)
    }

    func test_validateUsesSessionVersion() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/resume-reviews/review_123/validate"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["expected_version"] as? Int, 7)
                XCTAssertEqual(Set(body.keys), ["expected_version"])
                return (try Self.response(for: request, statusCode: 200), Self.reviewPlanPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let plan = try await service.validateReview(reviewID: "review_123", expectedVersion: 7)

        XCTAssertEqual(plan.sessionID, "review_123")
        XCTAssertEqual(plan.version, 8)
    }

    func test_importUsesSessionVersionConfirmedTrueAndStableIdempotencyKey() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/resume-reviews/review_123/import"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["expected_version"] as? Int, 8)
                XCTAssertEqual(body["idempotency_key"] as? String, "import-123")
                XCTAssertEqual(body["confirmed"] as? Bool, true)
                XCTAssertEqual(
                    Set(body.keys),
                    ["expected_version", "idempotency_key", "confirmed"]
                )
                return (try Self.response(for: request, statusCode: 200), Self.importBatchPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let batch = try await service.importReview(
            reviewID: "review_123",
            expectedVersion: 8,
            idempotencyKey: "import-123"
        )

        XCTAssertEqual(batch.id, "batch_123")
        XCTAssertEqual(batch.status, "processing")
    }

    func test_completeOnboardingIfNeededSkipsCompletionWhenAlreadyComplete() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case ("GET", "/api/v1/onboarding/status"):
                return (try Self.response(for: request, statusCode: 200), Self.completedOnboardingPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let result = try await service.completeOnboardingIfNeeded()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/users/me",
                "GET /api/v1/onboarding/status"
            ]
        )
        XCTAssertTrue(result.onboardingStatus.isOnboardingComplete)
    }

    func test_completeOnboardingIfNeededCompletesOnlyWhenRequirementsAreSatisfied() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case ("GET", "/api/v1/onboarding/status"):
                let callCount = await MockURLProtocolStorage.shared.requests().filter {
                    $0.url?.path == "/api/v1/onboarding/status"
                }.count
                return (
                    try Self.response(for: request, statusCode: 200),
                    callCount == 1 ? Self.incompleteOnboardingReadyToCompletePayload : Self.completedOnboardingPayload
                )
            case ("POST", "/api/v1/users/me/complete-onboarding"):
                return (try Self.response(for: request, statusCode: 204), Data())
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let result = try await service.completeOnboardingIfNeeded()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/users/me",
                "GET /api/v1/onboarding/status",
                "POST /api/v1/users/me/complete-onboarding",
                "GET /api/v1/users/me",
                "GET /api/v1/onboarding/status"
            ]
        )
        XCTAssertTrue(result.onboardingStatus.isOnboardingComplete)
    }

    func test_completeOnboardingIfNeededDoesNotPostWhenBackendStillRequiresMoreData() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case ("GET", "/api/v1/onboarding/status"):
                return (try Self.response(for: request, statusCode: 200), Self.incompleteOnboardingMissingRequirementsPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let result = try await service.completeOnboardingIfNeeded()

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/users/me",
                "GET /api/v1/onboarding/status"
            ]
        )
        XCTAssertEqual(result.onboardingStatus.currentStep, "complete_profile")
        XCTAssertEqual(result.onboardingStatus.missingRequirements, ["headline"])
        XCTAssertFalse(result.onboardingStatus.isOnboardingComplete)
    }

    func test_reconcileImportRecoveryTreatsCompletedImportAsCompleteWithoutRetryingImport() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resume-reviews/review_123"):
                return (try Self.response(for: request, statusCode: 200), Self.importedReviewSessionPayload)
            case ("GET", "/api/v1/resume-reviews/review_123/import-status"):
                return (try Self.response(for: request, statusCode: 200), Self.completedImportBatchWithIncompleteClaimsPayload)
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case ("GET", "/api/v1/onboarding/status"):
                return (try Self.response(for: request, statusCode: 200), Self.incompleteOnboardingMissingRequirementsPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let recovery = try await service.reconcileImportRecovery(reviewID: "review_123")
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(recovery.disposition, .importCompleted)
        XCTAssertEqual(recovery.reviewSession.status, .imported)
        XCTAssertEqual(recovery.importBatch?.resolvedStatus, .completed)
        XCTAssertEqual(recovery.importBatch?.incompleteCount, 5)
        XCTAssertEqual(
            recovery.completionResult?.onboardingStatus.missingRequirements,
            ["headline"]
        )
        XCTAssertFalse(recovery.completionResult?.isOnboardingComplete ?? true)
        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/resume-reviews/review_123",
                "GET /api/v1/resume-reviews/review_123/import-status",
                "GET /api/v1/users/me",
                "GET /api/v1/onboarding/status"
            ]
        )
    }

    func test_reconcileImportRecoveryResumesPollingWhenAuthoritativeBatchIsStillProcessing() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resume-reviews/review_123"):
                return (try Self.response(for: request, statusCode: 200), Self.importingReviewSessionPayload)
            case ("GET", "/api/v1/resume-reviews/review_123/import-status"):
                return (try Self.response(for: request, statusCode: 200), Self.importBatchPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let recovery = try await service.reconcileImportRecovery(reviewID: "review_123")

        XCTAssertEqual(recovery.disposition, .importInProgress)
        XCTAssertEqual(recovery.reviewSession.status, .importing)
        XCTAssertEqual(recovery.importBatch?.resolvedStatus, .processing)
        XCTAssertNil(recovery.completionResult)
    }

    func test_reconcileImportRecoveryTreatsPartialImportAsTerminalWithoutRetry() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resume-reviews/review_123"):
                return (try Self.response(for: request, statusCode: 200), Self.importingReviewSessionPayload)
            case ("GET", "/api/v1/resume-reviews/review_123/import-status"):
                return (try Self.response(for: request, statusCode: 200), Self.partiallyCompletedImportBatchPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let recovery = try await service.reconcileImportRecovery(reviewID: "review_123")

        XCTAssertEqual(recovery.disposition, .importPartiallyCompleted)
        XCTAssertEqual(recovery.importBatch?.resolvedStatus, .partiallyCompleted)
        XCTAssertEqual(recovery.importBatch?.importedCount, 7)
        XCTAssertEqual(recovery.importBatch?.failedCount, 1)
        XCTAssertNil(recovery.completionResult)
    }

    func test_reconcileImportRecoveryAllowsSafeRetryWhenNoImportBatchExists() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resume-reviews/review_123"):
                return (try Self.response(for: request, statusCode: 200), Self.importingReviewSessionPayload)
            case ("GET", "/api/v1/resume-reviews/review_123/import-status"):
                return (
                    try Self.response(for: request, statusCode: 404),
                    Self.apiErrorPayload(code: "not_found", message: "No import batch exists.")
                )
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let recovery = try await service.reconcileImportRecovery(reviewID: "review_123")

        XCTAssertEqual(recovery.disposition, .noImportToResume)
        XCTAssertNil(recovery.importBatch)
        XCTAssertNil(recovery.completionResult)
    }

    @MainActor
    private func makeService() async throws -> ResumeImportService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let mockedSession = makeMockedURLSession()
        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: mockedSession
        )
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.resumeImport"
        )
        let sessionService = SessionService(
            configuration: configuration,
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let authService = AuthService(
            configuration: configuration,
            networkClient: networkClient,
            sessionService: sessionService
        )
        return ResumeImportService(
            sessionService: sessionService,
            authService: authService,
            consentVersion: configuration.currentResumeImportConsentVersion,
            storageSession: mockedSession
        )
    }

    private func makeTemporaryResumeFile(named fileName: String, contents: Data) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(fileName)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: fileURL)
        return fileURL
    }

    private static func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
    }

    private static let uploadIntentPayload = Data(
        """
        {
          "resume_id": "resume_123",
          "upload_url": "https://uploads.example.com/candidate/resume_123?signature=redacted",
          "expires_in": 900,
          "object_key": "candidate/resume_123"
        }
        """.utf8
    )

    private static let httpUploadIntentPayload = Data(
        """
        {
          "resume_id": "resume_123",
          "upload_url": "http://uploads.example.com/candidate/resume_123?signature=redacted",
          "expires_in": 900,
          "object_key": "candidate/resume_123"
        }
        """.utf8
    )

    private static let uploadIntentPayloadWithoutObjectKey = Data(
        """
        {
          "resume_id": "resume_123",
          "upload_url": "https://uploads.example.com/candidate/resume_123?signature=redacted",
          "expires_in": 900
        }
        """.utf8
    )

    private static let resumeListPayload = Data(
        """
        {
          "items": [
            {
              "id": "resume_123",
              "original_filename": "Aman_Jha_Resume.pdf",
              "content_type": "application/pdf",
              "file_size_bytes": 16,
              "upload_status": "uploaded",
              "processing_status": "needs_review",
              "created_at": "2026-08-08T10:00:00Z",
              "updated_at": "2026-08-08T10:00:05Z"
            }
          ],
          "total": 1,
          "page": 1,
          "page_size": 10,
          "total_pages": 1,
          "offset": 0,
          "limit": 10
        }
        """.utf8
    )

    private static let completedResumePayload = Data(
        """
        {
          "id": "resume_123",
          "original_filename": "Aman_Jha_Resume.pdf",
          "content_type": "application/pdf",
          "file_size_bytes": 16,
          "upload_status": "uploaded",
          "processing_status": "uploaded",
          "created_at": "2026-08-08T10:00:00Z",
          "updated_at": "2026-08-08T10:00:05Z"
        }
        """.utf8
    )

    private static let completedDOCXResumePayload = Data(
        """
        {
          "id": "resume_123",
          "original_filename": "Aman_Jha_Resume.docx",
          "content_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          "file_size_bytes": 16,
          "upload_status": "uploaded",
          "processing_status": "uploaded",
          "created_at": "2026-08-08T10:00:00Z",
          "updated_at": "2026-08-08T10:00:05Z"
        }
        """.utf8
    )

    private static let reviewSessionPayload = Data(
        """
        {
          "id": "review_123",
          "resume_id": "resume_123",
          "parsed_result_id": "parsed_123",
          "status": "reviewing",
          "schema_version": "resume_review_v1",
          "version": 4,
          "items": [
            {
              "id": "item_profile",
              "claim_type": "profile",
              "source_claim_id": "claim_profile",
              "original_payload": { "full_name": "Aman Jha", "email": "aman@example.com" },
              "edited_payload": { "full_name": "Aman Jha", "email": "aman@example.com" },
              "selected": true,
              "review_status": "draft",
              "duplicate_status": "no_match",
              "duplicate_candidates": [],
              "conflict_warnings": [],
              "import_action": "create_new",
              "target_record_id": null,
              "imported_record_type": null,
              "imported_record_id": null,
              "source_reference": "page_1",
              "confidence": 0.98,
              "version": 2
            }
          ],
          "created_at": "2026-08-08T10:00:10Z",
          "updated_at": "2026-08-08T10:00:20Z"
        }
        """.utf8
    )

    private static let importingReviewSessionPayload = Data(
        """
        {
          "id": "review_123",
          "resume_id": "resume_123",
          "parsed_result_id": "parsed_123",
          "status": "importing",
          "schema_version": "resume_review_v1",
          "version": 2,
          "items": [
            {
              "id": "item_profile",
              "claim_type": "profile",
              "source_claim_id": "claim_profile",
              "original_payload": { "full_name": "Aman Jha", "email": "aman@example.com" },
              "edited_payload": { "full_name": "Aman Jha", "email": "aman@example.com" },
              "selected": true,
              "review_status": "validated",
              "duplicate_status": "no_match",
              "duplicate_candidates": [],
              "conflict_warnings": [],
              "import_action": "create_new",
              "target_record_id": null,
              "imported_record_type": null,
              "imported_record_id": null,
              "source_reference": "page_1",
              "confidence": 0.98,
              "version": 1
            }
          ],
          "created_at": "2026-08-08T10:00:10Z",
          "updated_at": "2026-08-08T10:00:20Z"
        }
        """.utf8
    )

    private static let importedReviewSessionPayload = Data(
        """
        {
          "id": "review_123",
          "resume_id": "resume_123",
          "parsed_result_id": "parsed_123",
          "status": "imported",
          "schema_version": "resume_review_v1",
          "version": 3,
          "items": [
            {
              "id": "item_profile",
              "claim_type": "profile",
              "source_claim_id": "claim_profile",
              "original_payload": { "full_name": "Aman Jha", "email": "aman@example.com" },
              "edited_payload": { "full_name": "Aman Jha", "email": "aman@example.com" },
              "selected": true,
              "review_status": "imported",
              "duplicate_status": "no_match",
              "duplicate_candidates": [],
              "conflict_warnings": [],
              "import_action": "create_new",
              "target_record_id": null,
              "imported_record_type": "profile",
              "imported_record_id": "profile_123",
              "source_reference": "page_1",
              "confidence": 0.98,
              "version": 1
            }
          ],
          "created_at": "2026-08-08T10:00:10Z",
          "updated_at": "2026-08-08T10:00:20Z"
        }
        """.utf8
    )

    private static let reviewPlanPayload = Data(
        """
        {
          "session_id": "review_123",
          "ready": true,
          "version": 8,
          "items": [
            {
              "item_id": "item_profile",
              "claim_type": "profile",
              "action": "create",
              "target_model": "profile",
              "duplicate_status": "no_match",
              "target_record_id": null,
              "fields_to_create": ["full_name", "email"],
              "fields_ignored": [],
              "blockers": [],
              "warnings": [],
              "verified_record_protected": false
            }
          ]
        }
        """.utf8
    )

    private static let importBatchPayload = Data(
        """
        {
          "id": "batch_123",
          "review_session_id": "review_123",
          "status": "processing",
          "total_count": 1,
          "imported_count": 0,
          "linked_count": 0,
          "skipped_count": 0,
          "failed_count": 0,
          "blocked_count": 0,
          "incomplete_count": 0,
          "entity_counts": {
            "profile": {
              "detected": 1,
              "imported": 0,
              "incomplete": 0,
              "failed": 0
            }
          },
          "results": [],
          "created_at": "2026-08-08T10:00:20Z",
          "updated_at": "2026-08-08T10:00:25Z"
        }
        """.utf8
    )

    private static let partiallyCompletedImportBatchPayload = Data(
        """
        {
          "id": "batch_123",
          "review_session_id": "review_123",
          "status": "partially_completed",
          "total_count": 12,
          "imported_count": 7,
          "linked_count": 0,
          "skipped_count": 0,
          "failed_count": 1,
          "blocked_count": 0,
          "incomplete_count": 4,
          "entity_counts": {
            "profile": {
              "detected": 1,
              "imported": 1,
              "incomplete": 0,
              "failed": 0
            }
          },
          "results": [],
          "created_at": "2026-08-08T10:00:20Z",
          "updated_at": "2026-08-08T10:00:25Z"
        }
        """.utf8
    )

    private static let completedImportBatchWithIncompleteClaimsPayload = Data(
        """
        {
          "id": "batch_123",
          "review_session_id": "review_123",
          "status": "completed",
          "total_count": 12,
          "imported_count": 12,
          "linked_count": 0,
          "skipped_count": 0,
          "failed_count": 0,
          "blocked_count": 0,
          "incomplete_count": 5,
          "entity_counts": {
            "profile": {
              "detected": 1,
              "imported": 1,
              "incomplete": 0,
              "failed": 0
            }
          },
          "results": [],
          "created_at": "2026-08-08T10:00:20Z",
          "updated_at": "2026-08-08T10:00:25Z"
        }
        """.utf8
    )

    private static let userPayload = Data(
        """
        {
          "id": "user_123",
          "email": "aman@example.com",
          "full_name": "Aman Jha",
          "role": "user",
          "is_active": true,
          "created_at": "2026-08-08T10:00:00Z"
        }
        """.utf8
    )

    private static let incompleteOnboardingReadyToCompletePayload = Data(
        """
        {
          "current_step": "resume_import_or_quick_profile",
          "email_verified": true,
          "phone_verified": true,
          "passport_ready": false,
          "completed_steps": ["verify_email", "verify_phone"],
          "missing_requirements": [],
          "next_recommended_step": "resume_import_or_quick_profile",
          "completion_percentage": 80,
          "is_onboarding_complete": false
        }
        """.utf8
    )

    private static let incompleteOnboardingMissingRequirementsPayload = Data(
        """
        {
          "current_step": "complete_profile",
          "email_verified": true,
          "phone_verified": true,
          "passport_ready": false,
          "completed_steps": ["verify_email", "verify_phone"],
          "missing_requirements": ["headline"],
          "next_recommended_step": "complete_profile",
          "completion_percentage": 80,
          "is_onboarding_complete": false
        }
        """.utf8
    )

    private static let completedOnboardingPayload = Data(
        """
        {
          "current_step": "complete",
          "email_verified": true,
          "phone_verified": true,
          "passport_ready": true,
          "completed_steps": ["verify_email", "verify_phone", "resume_import_or_quick_profile"],
          "missing_requirements": [],
          "next_recommended_step": null,
          "completion_percentage": 100,
          "is_onboarding_complete": true
        }
        """.utf8
    )

    private static func apiErrorPayload(code: String, message: String) -> Data {
        Data(
            """
            {
              "error": {
                "code": "\(code)",
                "message": "\(message)"
              }
            }
            """.utf8
        )
    }

    private static let expectedChecksum =
        "6187fc89f6284ba7170b2f93e82d4ebf6769ed2ffe1e476978404cb996f70134"
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure @escaping () async throws -> T,
    _ errorHandler: @escaping (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw.")
    } catch {
        errorHandler(error)
    }
}
