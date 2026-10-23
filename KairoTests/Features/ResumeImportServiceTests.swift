import Foundation
import XCTest
@testable import Kairo

final class ResumeImportServiceTests: XCTestCase {
    @MainActor
    func test_API43ProductionMockIntakeThroughCurrentEducationImportAndCanonicalCareerReload() async throws {
        let (service, career) = try await Self.makeServicesOnMainActor(environment: .production)
        var review = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.reviewSessionPayload) as? [String: Any])
        var item = try XCTUnwrap((review["items"] as? [[String: Any]])?.first)
        let claim: [String: Any] = ["claim_type": "education", "institution_name": "Synthetic Institute",
            "degree": "Synthetic degree", "is_current": true, "start_date": "2024-01-01", "end_date": NSNull()]
        item["claim_type"] = "education"
        item["original_payload"] = claim
        item["edited_payload"] = claim
        review["items"] = [item]
        let initialData = try JSONSerialization.data(withJSONObject: review)
        var updatedClaim = claim
        updatedClaim["degree"] = "Reviewed degree"
        updatedClaim["institution_catalogue_id"] = "synthetic-catalogue-id"
        updatedClaim["institution_catalogue_version"] = "test-v1"
        item["edited_payload"] = updatedClaim
        item["version"] = 3
        review["items"] = [item]
        review["version"] = 5
        let updatedData = try JSONSerialization.data(withJSONObject: review)
        let itemData = try JSONSerialization.data(withJSONObject: item)
        let parsed = String(decoding: Self.completedResumePayload, as: UTF8.self)
            .replacingOccurrences(of: "\"processing_status\": \"uploaded\"", with: "\"processing_status\": \"needs_review\"")
        let planData = Data(String(decoding: Self.reviewPlanPayload, as: UTF8.self)
            .replacingOccurrences(of: "\"profile\"", with: "\"education\"")
            .replacingOccurrences(of: "[\"full_name\", \"email\"]", with: "[\"institution_name\", \"degree\", \"is_current\"]").utf8)
        var batch = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.importBatchPayload) as? [String: Any])
        batch["status"] = "completed"
        batch["imported_count"] = 1
        batch["entity_counts"] = ["education": ["detected": 1, "imported": 1, "incomplete": 0, "failed": 0]]
        batch["results"] = [["review_item_id": "item_profile", "outcome": "imported", "record_type": "education",
                             "record_id": "synthetic-education", "warnings": []]]
        let batchData = try JSONSerialization.data(withJSONObject: batch)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.host, "api.kairoid.com", "Every request is intercepted; none reaches Production")
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resumes/resume_123"):
                return (try Self.response(for: request, statusCode: 200), Data(parsed.utf8))
            case ("GET", "/api/v1/resumes/resume_123/review-session"):
                return (try Self.response(for: request, statusCode: 200), initialData)
            case ("PATCH", "/api/v1/resume-reviews/review_123/items/item_profile"):
                let body = try requestJSONBody(from: request)
                let sent = try XCTUnwrap(body["edited_payload"] as? [String: Any])
                XCTAssertEqual(sent["degree"] as? String, "Reviewed degree")
                XCTAssertEqual(sent["institution_catalogue_id"] as? String, "synthetic-catalogue-id")
                XCTAssertEqual(sent["institution_catalogue_version"] as? String, "test-v1")
                XCTAssertEqual(sent["is_current"] as? Bool, true)
                XCTAssertTrue(sent["end_date"] is NSNull)
                return (try Self.response(for: request, statusCode: 200), itemData)
            case ("GET", "/api/v1/resume-reviews/review_123"):
                return (try Self.response(for: request, statusCode: 200), updatedData)
            case ("POST", "/api/v1/resume-reviews/review_123/validate"):
                XCTAssertEqual(try requestJSONBody(from: request)["expected_version"] as? Int, 5)
                return (try Self.response(for: request, statusCode: 200), planData)
            case ("POST", "/api/v1/resume-reviews/review_123/import"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["expected_version"] as? Int, 8)
                XCTAssertEqual(body["idempotency_key"] as? String, "synthetic-api43-idempotent")
                return (try Self.response(for: request, statusCode: 201), batchData)
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case ("GET", "/api/v1/educations"):
                let data = Data(#"[{"id":"synthetic-education","institution_name":"Synthetic Institute","institution_catalogue_id":"synthetic-catalogue-id","institution_catalogue_version":"test-v1","degree":"Reviewed degree","start_date":"2024-01-01","end_date":null,"is_currently_studying":true,"verification_status":"draft"}]"#.utf8)
                return (try Self.response(for: request, statusCode: 200), data)
            case ("GET", "/api/v1/employments"), ("GET", "/api/v1/certifications"),
                 ("GET", "/api/v1/projects"), ("GET", "/api/v1/skills"), ("GET", "/api/v1/portfolio"):
                return (try Self.response(for: request, statusCode: 200), Data("[]".utf8))
            default:
                XCTFail("Unexpected synthetic route")
                throw URLError(.badURL)
            }
        }
        let intake = try await service.restoreWorkflow(resumeID: "resume_123")
        let first = try XCTUnwrap(intake.reviewSession?.items.first)
        let edits = ResumeImportMapper.editedPayload(for: first, using: ["degree": "Reviewed degree",
            "institution_catalogue_id": "synthetic-catalogue-id", "institution_catalogue_version": "test-v1"])
        let saved = try await service.updateReviewItem(reviewID: "review_123", itemID: first.id,
            payload: ResumeImportMapper.editedPayloadUpdateRequest(for: first, editedPayload: edits))
        let plan = try await service.validateReview(reviewID: saved.id, expectedVersion: saved.version)
        XCTAssertTrue(plan.ready)
        let imported = try await service.importReview(reviewID: saved.id, expectedVersion: plan.version, idempotencyKey: "synthetic-api43-idempotent")
        let retried = try await service.importReview(reviewID: saved.id, expectedVersion: plan.version, idempotencyKey: "synthetic-api43-idempotent")
        XCTAssertEqual(imported.id, retried.id)
        let canonical = try await career.loadOverview()
        XCTAssertEqual(canonical.educations.count, 1)
        XCTAssertEqual(canonical.educations[0].degree, "Reviewed degree")
        XCTAssertEqual(canonical.educations[0].institutionCatalogueID, "synthetic-catalogue-id")
        XCTAssertEqual(canonical.educations[0].institutionCatalogueVersion, "test-v1")
        XCTAssertTrue(canonical.educations[0].isCurrentlyStudying)
        XCTAssertNil(canonical.educations[0].endDate)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertFalse(requests.contains { $0.httpMethod == "POST" && $0.url?.path == "/api/v1/educations" })
    }
    func test_API43ProductionEducationConflictIsVisibleBeforeImportWithoutPayloadRepair() async throws {
        let service = try await makeService(environment: .production)
        let blockedPlan = String(decoding: Self.reviewPlanPayload, as: UTF8.self)
            .replacingOccurrences(of: "\"ready\": true", with: "\"ready\": false")
            .replacingOccurrences(of: "\"blockers\": []", with: "\"blockers\": [\"current_claim_has_end_date\"]")
            .replacingOccurrences(of: "\"claim_type\": \"profile\"", with: "\"claim_type\": \"education\"")
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.host, "api.kairoid.com")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/resume-reviews/review_123/validate")
            return (try Self.response(for: request, statusCode: 200), Data(blockedPlan.utf8))
        }
        let plan = try await service.validateReview(reviewID: "review_123", expectedVersion: 7)
        XCTAssertFalse(plan.ready)
        XCTAssertEqual(plan.blockers, ["current_claim_has_end_date"])
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertFalse(requests.contains { $0.url?.path.hasSuffix("/import") == true })
    }

    func test_API43ProductionCurrentEducationEditPreservesNullEndAndCurrentFlag() async throws {
        let service = try await makeService(environment: .production)
        var review = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.reviewSessionPayload) as? [String: Any])
        var item = try XCTUnwrap((review["items"] as? [[String: Any]])?.first)
        let payload: [String: Any] = ["claim_type": "education", "institution_name": "Synthetic Institute",
            "degree": "Synthetic degree", "is_current": true, "start_date": "2024-01-01",
            "start_date_precision": "day", "end_date": NSNull(), "end_date_display": NSNull(),
            "end_date_precision": NSNull()]
        item["claim_type"] = "education"
        item["original_payload"] = payload
        item["edited_payload"] = payload
        review["items"] = [item]
        let reviewData = try JSONSerialization.data(withJSONObject: review)
        let itemData = try JSONSerialization.data(withJSONObject: item)
        let mapped = ResumeImportMapper.map(try APIJSONCoder.makeDecoder().decode(ResumeReviewSessionDTO.self, from: reviewData)).items[0]
        let edited = ResumeImportMapper.editedPayload(for: mapped, using: ["degree": "Updated synthetic degree"])
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.host, "api.kairoid.com")
            switch request.httpMethod {
            case "PATCH":
                let body = try requestJSONBody(from: request)
                let sent = try XCTUnwrap(body["edited_payload"] as? [String: Any])
                XCTAssertEqual(sent["is_current"] as? Bool, true)
                XCTAssertTrue(sent["end_date"] is NSNull)
                XCTAssertTrue(sent["end_date_display"] is NSNull)
                XCTAssertEqual(sent["start_date"] as? String, "2024-01-01")
                return (try Self.response(for: request, statusCode: 200), itemData)
            case "GET":
                return (try Self.response(for: request, statusCode: 200), reviewData)
            default:
                XCTFail("Only explicit edit/refetch allowed")
                throw URLError(.badURL)
            }
        }
        let result = try await service.updateReviewItem(reviewID: "review_123", itemID: mapped.id,
            payload: ResumeImportMapper.editedPayloadUpdateRequest(for: mapped, editedPayload: edited))
        XCTAssertEqual(result.items[0].editedPayload["is_current"], .bool(true))
        XCTAssertEqual(result.items[0].editedPayload["end_date"], .null)
    }

    func test_productionConfiguredCertificationEditSaveRefetchValidateAndImportWire() async throws {
        let service = try await makeService(environment: .production)
        var reviewJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.reviewSessionPayload) as? [String: Any])
        var itemJSON = try XCTUnwrap((reviewJSON["items"] as? [[String: Any]])?.first)
        let claim: [String: Any] = ["claim_type": "certification", "title": "Synthetic certificate", "issuing_organization": "Synthetic issuer", "issued_date": NSNull()]
        itemJSON["claim_type"] = "certification"
        itemJSON["original_payload"] = claim
        itemJSON["edited_payload"] = claim
        reviewJSON["items"] = [itemJSON]
        let reviewData = try JSONSerialization.data(withJSONObject: reviewJSON)
        let itemData = try JSONSerialization.data(withJSONObject: itemJSON)
        let item = ResumeImportMapper.map(try APIJSONCoder.makeDecoder().decode(ResumeReviewSessionDTO.self, from: reviewData)).items[0]
        let edited = ResumeImportMapper.editedPayload(for: item, using: ["issued_date": "2024-01-01"])
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.host, "api.kairoid.com", "Mock transport only; no live Production requests")
            switch (request.httpMethod, request.url?.path) {
            case ("PATCH", "/api/v1/resume-reviews/review_123/items/item_profile"):
                let body = try requestJSONBody(from: request)
                let payload = try XCTUnwrap(body["edited_payload"] as? [String: Any])
                XCTAssertEqual(payload["issued_date"] as? String, "2024-01-01")
                XCTAssertNil(payload["issue_date"])
                XCTAssertEqual(Set(payload.keys), ["claim_type", "title", "issuing_organization", "issued_date"])
                XCTAssertEqual(body["expected_version"] as? Int, 2)
                return (try Self.response(for: request, statusCode: 200), itemData)
            case ("GET", "/api/v1/resume-reviews/review_123"):
                return (try Self.response(for: request, statusCode: 200), reviewData)
            case ("POST", "/api/v1/resume-reviews/review_123/validate"):
                return (try Self.response(for: request, statusCode: 200), Self.reviewPlanPayload)
            case ("POST", "/api/v1/resume-reviews/review_123/import"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["expected_version"] as? Int, 8)
                XCTAssertEqual(body["confirmed"] as? Bool, true)
                return (try Self.response(for: request, statusCode: 200), Self.importBatchPayload)
            default:
                XCTFail("Unexpected synthetic route")
                throw URLError(.badURL)
            }
        }
        let review = try await service.updateReviewItem(reviewID: "review_123", itemID: item.id, payload: ResumeImportMapper.editedPayloadUpdateRequest(for: item, editedPayload: edited))
        let plan = try await service.validateReview(reviewID: review.id, expectedVersion: review.version)
        let batch = try await service.importReview(reviewID: review.id, expectedVersion: plan.version, idempotencyKey: "synthetic-batch1")
        XCTAssertEqual(batch.id, "batch_123")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 4)
    }
    func test_deleteUsesExactSelectedIDAuthenticationAnd204WithoutJSONDecode() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/api/v1/resumes/selected-previous")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertNil(request.httpBody)
            return (try Self.response(for: request, statusCode: 204), Data())
        }
        try await service.deleteResume(resumeID: "selected-previous")
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 1)
    }

    func test_deleteRejectsUnexpectedSuccessStatus() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(for: request, statusCode: 200), Data())
        }
        await XCTAssertThrowsErrorAsync(try await service.deleteResume(resumeID: "exact-id")) { error in
            XCTAssertEqual(error as? NetworkError, .invalidResponse)
        }
    }

    func test_delete401404AndServerFailureNeverReplayOrCallOtherEndpoints() async throws {
        for status in [401, 404, 503] {
            await MockURLProtocolStorage.shared.reset()
            let service = try await makeService()
            await MockURLProtocolStorage.shared.setHandler { request in
                XCTAssertEqual(request.httpMethod, "DELETE")
                XCTAssertEqual(request.url?.path, "/api/v1/resumes/selected-previous")
                return (try Self.response(for: request, statusCode: status), Data())
            }
            await XCTAssertThrowsErrorAsync(try await service.deleteResume(resumeID: "selected-previous")) { _ in }
            let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 1)
        }
    }

    func test_deleteTransportFailureDoesNotRetry() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { _ in throw URLError(.timedOut) }
        await XCTAssertThrowsErrorAsync(try await service.deleteResume(resumeID: "exact-id")) { _ in }
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 1)
    }

    func test_deleteDuplicateInFlightRequestsAreRejected() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            try await Task.sleep(for: .milliseconds(200))
            return (try Self.response(for: request, statusCode: 204), Data())
        }
        let first = Task { try await service.deleteResume(resumeID: "exact-id") }
        try await Task.sleep(for: .milliseconds(30))
        await XCTAssertThrowsErrorAsync(try await service.deleteResume(resumeID: "exact-id")) { _ in }
        try await first.value
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 1)
    }

    func test_abandonedSelectionCleanupRemovesOnlyPrivateCopy() async throws {
        let service = try await makeService()
        let original = try makeTemporaryResumeFile(named: "synthetic-cleanup.pdf", contents: Data("synthetic".utf8))
        let prepared = try service.prepareSelection(from: original)
        XCTAssertNotEqual(prepared.temporaryFileURL, original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.temporaryFileURL.path))
        service.cleanupSelection(at: prepared.temporaryFileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.temporaryFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }
    func test_authenticatedHistoryIsReadOnlyAndUsesBackendPagination() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            if request.url?.path == "/api/v1/resumes" {
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
                XCTAssertEqual(query?.first(where: { $0.name == "offset" })?.value, "20")
                XCTAssertEqual(query?.first(where: { $0.name == "limit" })?.value, "20")
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            }
            XCTAssertEqual(request.url?.path, "/api/v1/resumes/resume_123/review-session")
            return (try Self.response(for: request, statusCode: 200), Self.reviewSessionPayload)
        }
        let page = try await service.resumeHistory(offset: 20, limit: 20)
        XCTAssertEqual(page.entries.first?.resume.id, "resume_123")
        XCTAssertEqual(page.entries.first?.historyStatus, "Ready for review")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 2)
    }

    func test_historyDoesNotCreateMissingReview() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            if request.url?.path == "/api/v1/resumes" {
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            }
            return (try Self.response(for: request, statusCode: 404), Self.apiErrorPayload(code: "not_found", message: "Not found"))
        }
        let page = try await service.resumeHistory(offset: 0, limit: 20)
        XCTAssertEqual(page.entries.count, 1)
        XCTAssertNil(page.entries.first?.reviewSession)
    }

    func test_selectedPreviousResumeNeverRestoresLatestInstead() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/resumes/previous_resume")
            let payload = String(decoding: Self.completedResumePayload, as: UTF8.self)
                .replacingOccurrences(of: "resume_123", with: "previous_resume")
            return (try Self.response(for: request, statusCode: 200), Data(payload.utf8))
        }
        let selected = try await service.restoreWorkflow(resumeID: "previous_resume")
        XCTAssertEqual(selected.resume.id, "previous_resume")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func test_importedHistoryUsesAuthoritativeBatchWithoutOnboardingCalls() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            let data: Data
            switch request.url?.path {
            case "/api/v1/resumes": data = Self.resumeListPayload
            case "/api/v1/resumes/resume_123/review-session": data = Self.importedReviewSessionPayload
            case "/api/v1/resume-reviews/review_123/import-status": data = Self.importBatchPayload
            default: XCTFail("Unexpected history request"); throw URLError(.badURL)
            }
            return (try Self.response(for: request, statusCode: 200), data)
        }
        let page = try await service.resumeHistory(offset: 0, limit: 20)
        XCTAssertEqual(page.entries.first?.historyStatus, "Imported")
        XCTAssertEqual(page.entries.first?.isImported, true)
    }

    func test_authenticatedRecoveryNeverCompletesOnboardingOrChangesSession() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            let data: Data
            switch request.url?.path {
            case "/api/v1/resume-reviews/review_123": data = Self.importedReviewSessionPayload
            case "/api/v1/resume-reviews/review_123/import-status": data = Self.importBatchPayload
            default: XCTFail("Authenticated recovery must not call auth, onboarding, Trust or verification"); throw URLError(.badURL)
            }
            return (try Self.response(for: request, statusCode: 200), data)
        }
        let recovery = try await service.reconcileImportRecovery(reviewID: "review_123", context: .authenticated)
        XCTAssertEqual(recovery.disposition, .importCompleted)
        XCTAssertNil(recovery.completionResult)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 2)
    }

    func test_historyFailureDoesNotInventEmptySuccess() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(for: request, statusCode: 503), Self.apiErrorPayload(code: "internal_error", message: "Unavailable"))
        }
        await XCTAssertThrowsErrorAsync(try await service.resumeHistory(offset: 0, limit: 20)) { _ in }
    }

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

    func test_restoreLatestWorkflowCreatesMissingAuthoritativeReviewExactlyOnce() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resumes"):
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            case ("GET", "/api/v1/resumes/resume_123/review-session"):
                return (
                    try Self.response(for: request, statusCode: 404),
                    Self.apiErrorPayload(code: "not_found", message: "Review session not found.")
                )
            case ("POST", "/api/v1/resumes/resume_123/review-session"):
                return (try Self.response(for: request, statusCode: 201), Self.reviewSessionPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let workflow = try await service.restoreLatestWorkflow()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(workflow?.reviewSession?.id, "review_123")
        XCTAssertEqual(workflow?.reviewSession?.items.count, 1)
        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/resumes",
                "GET /api/v1/resumes/resume_123/review-session",
                "POST /api/v1/resumes/resume_123/review-session"
            ]
        )
    }

    func test_restoreLatestWorkflowRefetchesAfterCreateConflict() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resumes"):
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            case ("GET", "/api/v1/resumes/resume_123/review-session"):
                let requestCount = await MockURLProtocolStorage.shared.requests().filter {
                    $0.httpMethod == "GET" &&
                    $0.url?.path == "/api/v1/resumes/resume_123/review-session"
                }.count
                if requestCount == 1 {
                    return (
                        try Self.response(for: request, statusCode: 404),
                        Self.apiErrorPayload(code: "not_found", message: "Review session not found.")
                    )
                }
                return (try Self.response(for: request, statusCode: 200), Self.reviewSessionPayload)
            case ("POST", "/api/v1/resumes/resume_123/review-session"):
                return (
                    try Self.response(for: request, statusCode: 409),
                    Self.apiErrorPayload(code: "conflict", message: "Review already exists.")
                )
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let workflow = try await service.restoreLatestWorkflow()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(workflow?.reviewSession?.id, "review_123")
        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/resumes",
                "GET /api/v1/resumes/resume_123/review-session",
                "POST /api/v1/resumes/resume_123/review-session",
                "GET /api/v1/resumes/resume_123/review-session"
            ]
        )
    }

    func test_repeatedWorkflowRestorationReusesSameJobReviewAndItems() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resumes"):
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            case ("GET", "/api/v1/resumes/resume_123/review-session"):
                let requestCount = await MockURLProtocolStorage.shared.requests().filter {
                    $0.httpMethod == "GET" &&
                    $0.url?.path == "/api/v1/resumes/resume_123/review-session"
                }.count
                if requestCount == 1 {
                    return (
                        try Self.response(for: request, statusCode: 404),
                        Self.apiErrorPayload(code: "not_found", message: "Review session not found.")
                    )
                }
                return (try Self.response(for: request, statusCode: 200), Self.reviewSessionPayload)
            case ("POST", "/api/v1/resumes/resume_123/review-session"):
                return (try Self.response(for: request, statusCode: 201), Self.reviewSessionPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let first = try await service.restoreLatestWorkflow()
        let second = try await service.restoreLatestWorkflow()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(first?.resume.id, second?.resume.id)
        XCTAssertEqual(first?.reviewSession?.id, second?.reviewSession?.id)
        XCTAssertEqual(first?.reviewSession?.items, second?.reviewSession?.items)
        XCTAssertEqual(requests.filter { $0.httpMethod == "POST" }.count, 1)
        XCTAssertEqual(requests.filter { $0.url?.path == "/api/v1/resumes" }.count, 2)
    }

    func test_restoreLatestWorkflowRejectsReviewWithoutHydratedItems() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resumes"):
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            case ("GET", "/api/v1/resumes/resume_123/review-session"):
                return (try Self.response(for: request, statusCode: 200), Self.emptyReviewSessionPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        await XCTAssertThrowsErrorAsync(try await service.restoreLatestWorkflow()) { error in
            XCTAssertEqual(
                error as? ResumeImportServiceError,
                .reviewRecovery(.missingItems)
            )
        }
    }

    func test_restoreLatestWorkflowClassifies422ReviewRecoveryFailure() async throws {
        try await assertReviewRecoveryFailure(statusCode: 422, expected: .invalidState)
    }

    func test_restoreLatestWorkflowClassifies429ReviewRecoveryFailure() async throws {
        try await assertReviewRecoveryFailure(statusCode: 429, expected: .rateLimited)
    }

    func test_restoreLatestWorkflowClassifies5xxReviewRecoveryFailure() async throws {
        try await assertReviewRecoveryFailure(statusCode: 503, expected: .serverUnavailable)
    }

    func test_restoreLatestWorkflowClassifiesTimeoutAsTransportFailure() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resumes"):
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            case ("GET", "/api/v1/resumes/resume_123/review-session"):
                throw URLError(.timedOut)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        await XCTAssertThrowsErrorAsync(try await service.restoreLatestWorkflow()) { error in
            XCTAssertEqual(
                error as? ResumeImportServiceError,
                .reviewRecovery(.transport)
            )
        }
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

    func test_completeOnboardingIfNeededUsesCanonicalCompletionDespiteAdvisoryRequirements() async throws {
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
                    callCount == 1 ? Self.incompleteOnboardingMissingRequirementsPayload : Self.completedOnboardingPayload
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

    func test_completeOnboardingIfNeededSurfacesCanonicalCompletionFailure() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case ("GET", "/api/v1/onboarding/status"):
                return (try Self.response(for: request, statusCode: 200), Self.incompleteOnboardingMissingRequirementsPayload)
            case ("POST", "/api/v1/users/me/complete-onboarding"):
                return (
                    try Self.response(for: request, statusCode: 503),
                    Self.apiErrorPayload(code: "service_unavailable", message: "Try again later.")
                )
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        do {
            _ = try await service.completeOnboardingIfNeeded()
            XCTFail("Expected canonical onboarding completion failure.")
        } catch let NetworkError.api(apiError) {
            XCTAssertEqual(apiError.code.rawValue, "service_unavailable")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/users/me",
                "GET /api/v1/onboarding/status",
                "POST /api/v1/users/me/complete-onboarding"
            ]
        )
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
                let callCount = await MockURLProtocolStorage.shared.requests().filter {
                    $0.url?.path == "/api/v1/onboarding/status"
                }.count
                return (
                    try Self.response(for: request, statusCode: 200),
                    callCount == 1 ? Self.incompleteOnboardingMissingRequirementsPayload : Self.completedOnboardingPayload
                )
            case ("POST", "/api/v1/users/me/complete-onboarding"):
                return (try Self.response(for: request, statusCode: 204), Data())
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
        XCTAssertTrue(recovery.completionResult?.isOnboardingComplete ?? false)
        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/resume-reviews/review_123",
                "GET /api/v1/resume-reviews/review_123/import-status",
                "GET /api/v1/users/me",
                "GET /api/v1/onboarding/status",
                "POST /api/v1/users/me/complete-onboarding",
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

    nonisolated private func makeService(environment: AppEnvironment = .staging) async throws -> ResumeImportService {
        try await Self.makeServiceOnMainActor(environment: environment)
    }

    @MainActor
    private static func makeServiceOnMainActor(environment: AppEnvironment) async throws -> ResumeImportService {
        try await makeServicesOnMainActor(environment: environment).0
    }

    @MainActor
    private static func makeServicesOnMainActor(environment: AppEnvironment) async throws -> (ResumeImportService, CareerOverviewService) {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let mockedSession = makeMockedURLSession()
        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: environment),
            session: mockedSession
        )
        let configuration = AppConfiguration(
            buildConfiguration: environment == .production ? .production : .development,
            environment: environment,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: environment),
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
        let resume = ResumeImportService(
            sessionService: sessionService,
            authService: authService,
            consentVersion: configuration.currentResumeImportConsentVersion,
            storageSession: mockedSession
        )
        return (resume, CareerOverviewService(authService: authService, sessionService: sessionService))
    }

    private func assertReviewRecoveryFailure(
        statusCode: Int,
        expected: ResumeReviewRecoveryFailure
    ) async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/resumes"):
                return (try Self.response(for: request, statusCode: 200), Self.resumeListPayload)
            case ("GET", "/api/v1/resumes/resume_123/review-session"):
                return (
                    try Self.response(for: request, statusCode: statusCode),
                    Self.apiErrorPayload(code: Self.errorCode(for: statusCode), message: "Sanitized failure.")
                )
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        await XCTAssertThrowsErrorAsync(try await service.restoreLatestWorkflow()) { error in
            XCTAssertEqual(error as? ResumeImportServiceError, .reviewRecovery(expected))
        }
    }

    private static func errorCode(for statusCode: Int) -> String {
        switch statusCode {
        case 422: "validation_error"
        case 429: "rate_limited"
        case 500: "internal_error"
        case 503: "service_unavailable"
        default: "bad_request"
        }
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

    private static let emptyReviewSessionPayload = Data(
        """
        {
          "id": "review_123",
          "resume_id": "resume_123",
          "parsed_result_id": "parsed_123",
          "status": "reviewing",
          "schema_version": "resume_review_v1",
          "version": 4,
          "items": [],
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
