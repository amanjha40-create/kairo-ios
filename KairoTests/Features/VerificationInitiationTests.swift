import Foundation
import XCTest
@testable import Kairo

@MainActor
final class VerificationInitiationTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_eligibilityUsesBackendStatusAndActiveRequestWithoutOfferingUnsupportedKinds() {
        let eligibleEmployment = subject(id: "employment_1", kind: .employment)
        let verifiedEducation = subject(
            id: "education_verified",
            kind: .education,
            status: .verified
        )
        let pendingEmployment = subject(
            id: "employment_pending",
            kind: .employment,
            status: .pending
        )
        let duplicateEducation = subject(
            id: "education_duplicate",
            kind: .education,
            hasActiveRequest: true
        )
        let eligibility = VerificationInitiationEligibility(
            subjects: [eligibleEmployment, verifiedEducation, pendingEmployment, duplicateEducation]
        )

        XCTAssertEqual(eligibility.eligibleSubjects.map(\.id), ["employment_1"])
        XCTAssertEqual(verifiedEducation.eligibilityMessage, "Already verified")
        XCTAssertEqual(pendingEmployment.eligibilityMessage, "Verification already in progress")
        XCTAssertEqual(duplicateEducation.eligibilityMessage, "Verification already in progress")
        XCTAssertEqual(VerificationInitiationKind.allCases, [.employment, .education])
    }

    func test_formRequiresCompletedEvidenceValidContactAndBothConsents() {
        var draft = draft(kind: .employment)

        XCTAssertFalse(draft.canSubmit)
        draft.selectedDocumentIDs = ["document_1"]
        draft.contactEmail = "hr@brightpath.example"
        draft.consentsToClaimFields = true
        XCTAssertFalse(draft.canSubmit)

        draft.consentsToEvidence = true
        XCTAssertTrue(draft.canSubmit)
        XCTAssertTrue(draft.consentedFields.contains("employment.role"))
        XCTAssertEqual(draft.consentedEvidenceScope, ["offer_letter"])
    }

    func test_employmentSubmissionCreatesDraftSubmitsConsentAndRefetchesAuthoritativeRequest() async throws {
        let service = try await makeService()
        var draft = draft(kind: .employment)
        makeSubmittable(&draft)

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/employments/employment_1/verification-request"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["employment_document_ids"] as? [String], ["document_1"])
                XCTAssertNil(body["employment_document_i_ds"])
                XCTAssertEqual(Set(body.keys), ["employment_document_ids", "verification_contact"])
                let contact = try XCTUnwrap(body["verification_contact"] as? [String: Any])
                XCTAssertEqual(contact["contact_email"] as? String, "hr@brightpath.example")
                XCTAssertEqual(contact["contact_type"] as? String, "hr")
                return (try Self.response(request, 201), Self.requestPayload(status: "pending_subject_submission"))
            case ("POST", "/api/v1/verification-requests/request_1/submit-for-review"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["consent_version"] as? String, "candidate_verification_initiation_v1")
                XCTAssertEqual(body["consented_evidence_scope"] as? [String], ["offer_letter"])
                XCTAssertTrue((body["consented_fields"] as? [String])?.contains("employment.employer_name") == true)
                return (try Self.response(request, 200), Self.requestPayload(status: "pending_admin_review"))
            case ("GET", "/api/v1/verification-requests/request_1"):
                return (try Self.response(request, 200), Self.requestPayload(status: "pending_admin_review"))
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let result = try await service.submit(draft)
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(result.requestID, "request_1")
        XCTAssertEqual(result.status, .pendingAdminReview)
        XCTAssertFalse(result.reusedExistingRequest)
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "POST", "GET"])
    }

    func test_educationSubmissionEncodesExactDocumentIDsKeyWithProductionEncoder() async throws {
        let service = try await makeService()
        var draft = draft(kind: .education)
        makeSubmittable(&draft)

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/educations/education_1/verification-request"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["education_document_ids"] as? [String], ["document_1"])
                XCTAssertNil(body["education_document_i_ds"])
                XCTAssertEqual(Set(body.keys), ["education_document_ids", "verification_contact"])
                let contact = try XCTUnwrap(body["verification_contact"] as? [String: Any])
                XCTAssertEqual(contact["contact_email"] as? String, "hr@brightpath.example")
                XCTAssertEqual(contact["contact_type"] as? String, "hr")
                return (try Self.response(request, 201), Self.requestPayload(status: "pending_subject_submission"))
            case ("POST", "/api/v1/verification-requests/request_1/submit-for-review"):
                return (try Self.response(request, 200), Self.requestPayload(status: "pending_admin_review"))
            case ("GET", "/api/v1/verification-requests/request_1"):
                return (try Self.response(request, 200), Self.requestPayload(status: "pending_admin_review"))
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let result = try await service.submit(draft)
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(result.requestID, "request_1")
        XCTAssertEqual(result.status, .pendingAdminReview)
        XCTAssertFalse(result.reusedExistingRequest)
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "POST", "GET"])
    }

    func test_educationEvidenceDecodesSnakeCasePageAndUsesSupportedRoute() async throws {
        let service = try await makeService()
        let education = subject(id: "education_1", kind: .education)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/educations/education_1/documents")
            return (
                try Self.response(request, 200),
                Data(
                    """
                    {"items":[{"id":"education_document_1","document_type":"transcript","original_filename":"transcript.pdf"}]}
                    """.utf8
                )
            )
        }

        let evidence = try await service.loadEvidence(for: education)

        XCTAssertEqual(
            evidence,
            [
                VerificationEvidenceDocument(
                    id: "education_document_1",
                    documentType: "transcript",
                    filename: "transcript.pdf",
                    isUploadComplete: true
                )
            ]
        )
    }

    func test_duplicateConflictReconcilesExistingRequestWithoutCreatingFalseState() async throws {
        let service = try await makeService()
        var draft = draft(kind: .employment)
        makeSubmittable(&draft)

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/employments/employment_1/verification-request"):
                return (
                    try Self.response(request, 409),
                    Data("{\"code\":\"conflict\",\"message\":\"Active verification request already exists\"}".utf8)
                )
            case ("GET", "/api/v1/employments/employment_1/verification-request"):
                return (try Self.response(request, 200), Self.requestPayload(status: "pending_admin_review"))
            case ("GET", "/api/v1/verification-requests/request_1"):
                return (try Self.response(request, 200), Self.requestPayload(status: "pending_admin_review"))
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let result = try await service.submit(draft)
        let paths = await MockURLProtocolStorage.shared.requests().compactMap(\.url?.path)

        XCTAssertTrue(result.reusedExistingRequest)
        XCTAssertEqual(result.status, .pendingAdminReview)
        XCTAssertFalse(paths.contains("/api/v1/verification-requests/request_1/submit-for-review"))
    }

    func test_incompleteEvidenceAndValidationErrorsRemainActionable() async throws {
        let service = try await makeService()
        let employment = subject(id: "employment_1", kind: .employment)

        await MockURLProtocolStorage.shared.setHandler { request in
            return (
                try Self.response(request, 200),
                Data(
                    """
                    {"items":[{"id":"document_1","document_type":"offer_letter","original_filename":"offer.pdf","verification_status":"pending_upload"}]}
                    """.utf8
                )
            )
        }

        do {
            _ = try await service.loadEvidence(for: employment)
            XCTFail("Expected incomplete evidence to block initiation")
        } catch let error as VerificationInitiationServiceError {
            XCTAssertEqual(error, .noCompletedEvidence)
        }

        let validationError = APIError(
            statusCode: 422,
            code: .validationError,
            message: "Validation failed",
            fieldErrors: ["contact_email": ["Enter a valid email address"]],
            globalErrors: [],
            validationDetails: []
        )
        let presentation = VerificationInitiationPresentationError.map(
            NetworkError.api(validationError),
            fallbackTitle: "Request not sent"
        )
        XCTAssertEqual(presentation.title, "Check verification details")
        XCTAssertTrue(presentation.message.contains("contact_email"))
    }

    func test_initialEligibilityFailureCanRetryWithoutCreatingLocalState() async {
        let service = RetryVerificationInitiationService()
        let model = VerificationInitiationViewModel(service: service, preset: nil)

        await model.load()

        XCTAssertNil(model.eligibility)
        XCTAssertEqual(model.error?.title, "Network unavailable")

        await model.load()

        let loadCount = await service.loadCount()
        XCTAssertEqual(model.eligibility?.eligibleSubjects.map(\.id), ["employment_retry"])
        XCTAssertNil(model.error)
        XCTAssertNil(model.result)
        XCTAssertEqual(loadCount, 2)
    }

    func test_unresolvedOrganizationAndBackendFailureRemainDistinct() {
        let unresolved = VerificationInitiationPresentationError.map(
            NetworkError.api(
                APIError(
                    statusCode: 422,
                    code: .validationError,
                    message: "Target organization is unresolved",
                    fieldErrors: [:],
                    globalErrors: [],
                    validationDetails: []
                )
            ),
            fallbackTitle: "Request not sent"
        )
        let unavailable = VerificationInitiationPresentationError.map(
            NetworkError.api(
                APIError(
                    statusCode: 503,
                    code: .serviceUnavailable,
                    message: "Service unavailable",
                    fieldErrors: [:],
                    globalErrors: [],
                    validationDetails: []
                )
            ),
            fallbackTitle: "Request not sent"
        )

        XCTAssertEqual(unresolved.title, "Organisation unresolved")
        XCTAssertEqual(unavailable.title, "Verification service unavailable")
    }

    func test_successRefreshInvalidatesBackendDrivenTabsAndFocusIsConsumedOnce() {
        let refreshStore = CandidateDataRefreshStore()

        refreshStore.verificationRequested(requestID: "request_refresh")

        XCTAssertEqual(refreshStore.revision, 1)
        XCTAssertEqual(refreshStore.focusedVerificationRequestID, "request_refresh")

        refreshStore.clearVerificationFocus(requestID: "different_request")
        XCTAssertEqual(refreshStore.focusedVerificationRequestID, "request_refresh")

        refreshStore.clearVerificationFocus(requestID: "request_refresh")
        XCTAssertNil(refreshStore.focusedVerificationRequestID)
        XCTAssertEqual(refreshStore.revision, 1)
    }

    private func makeService() async throws -> VerificationInitiationService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.verification-initiation"
        )
        let networkClient = URLSessionNetworkClient(
            baseURL: configuration.apiBaseURL,
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: configuration,
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let careerService = CareerOverviewService(
            authService: DemoAuthService(sessionService: sessionService),
            sessionService: sessionService
        )
        return VerificationInitiationService(
            careerService: careerService,
            sessionService: sessionService
        )
    }

    private func subject(
        id: String,
        kind: VerificationInitiationKind,
        status: CareerRecordVerificationStatus = .notVerified,
        hasActiveRequest: Bool = false
    ) -> VerificationInitiationSubject {
        VerificationInitiationSubject(
            id: id,
            kind: kind,
            title: kind == .employment ? "BrightPath Technologies" : "Kairo University",
            subtitle: kind == .employment ? "People Operations Manager" : "MBA",
            verificationStatus: status,
            hasActiveRequest: hasActiveRequest
        )
    }

    private func draft(kind: VerificationInitiationKind) -> VerificationInitiationDraft {
        VerificationInitiationDraft(
            subject: subject(id: kind == .employment ? "employment_1" : "education_1", kind: kind),
            documents: [
                VerificationEvidenceDocument(
                    id: "document_1",
                    documentType: kind == .employment ? "offer_letter" : "transcript",
                    filename: "evidence.pdf",
                    isUploadComplete: true
                )
            ]
        )
    }

    private func makeSubmittable(_ draft: inout VerificationInitiationDraft) {
        draft.selectedDocumentIDs = ["document_1"]
        draft.contactEmail = "hr@brightpath.example"
        draft.consentsToClaimFields = true
        draft.consentsToEvidence = true
    }

    private nonisolated static func response(_ request: URLRequest, _ statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
    }

    private nonisolated static func requestPayload(status: String) -> Data {
        Data(
            """
            {
              "public_id":"request_1",
              "employment_id":"employment_1",
              "subject_name":"Candidate",
              "subject_email":"candidate@example.com",
              "target_organization_name":"BrightPath Technologies",
              "target_organization_email":"hr@brightpath.example",
              "request_type":"employment",
              "status":"\(status)",
              "priority":"normal",
              "created_at":"2026-08-29T01:00:00Z",
              "updated_at":"2026-08-29T01:01:00Z",
              "consented_fields":[],
              "consented_evidence_scope":[],
              "evidence_summary":{"total_items":1,"document_items":1,"field_keys":["employment_evidence"]}
            }
            """.utf8
        )
    }
}

private actor RetryVerificationInitiationService: VerificationInitiationServiceProtocol {
    private var loads = 0

    func loadEligibility() async throws -> VerificationInitiationEligibility {
        loads += 1
        if loads == 1 {
            throw NetworkError.transport("The request could not connect")
        }
        return VerificationInitiationEligibility(
            subjects: [
                VerificationInitiationSubject(
                    id: "employment_retry",
                    kind: .employment,
                    title: "Retry Employer",
                    subtitle: "QA role",
                    verificationStatus: .notVerified,
                    hasActiveRequest: false
                )
            ]
        )
    }

    func loadEvidence(for subject: VerificationInitiationSubject) async throws -> [VerificationEvidenceDocument] {
        _ = subject
        return []
    }

    func submit(_ draft: VerificationInitiationDraft) async throws -> VerificationInitiationResult {
        _ = draft
        throw VerificationInitiationServiceError.unsupportedSubject
    }

    func loadCount() -> Int {
        loads
    }
}
