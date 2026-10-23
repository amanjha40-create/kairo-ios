import Foundation
import XCTest
@testable import Kairo

@MainActor
final class CareerOverviewMutationServiceTests: XCTestCase {
    func testHistoricalPickerDateSaveRefetchAndReopenPreserveExactDate() async throws {
        let service = try await makeService()
        let selected = try XCTUnwrap(CandidateDateInput.date(year: "1999", month: 8, day: 29))
        let month = try XCTUnwrap(ManualProfileNormalization.normalizedMonthNumber("8"))
        let roundTrip = try XCTUnwrap(CandidateDateInput.date(year: "1999", month: month, day: 29))
        var draft = CareerEmploymentDraft()
        draft.startDate = roundTrip
        draft.includesStartDate = true
        let request = draft.updateRequest()
        XCTAssertEqual(request.startDate, "1999-08-29")
        // Fully mocked transport. The refetch response is a saved historical date,
        // not an optimistic form value or a real account mutation.
        await MockURLProtocolStorage.shared.setHandler { request in
            var record = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.createdEmploymentPayload) as? [String: Any])
            record["id"] = "employment_1"
            record["start_date"] = "1999-08-29"
            if request.url?.path == "/api/v1/employments/employment_1" {
                if request.httpMethod == "PATCH" {
                    XCTAssertEqual(try requestJSONBody(from: request)["start_date"] as? String, "1999-08-29")
                }
                return (try Self.response(for: request, statusCode: 200), try JSONSerialization.data(withJSONObject: record))
            }
            if ["/api/v1/employments", "/api/v1/employments/"].contains(request.url?.path ?? "") {
                return (try Self.response(for: request, statusCode: 200), try JSONSerialization.data(withJSONObject: ["items": [record]]))
            }
            return try await Self.overviewResponse(for: request)
        }
        let overview = try await service.updateEmployment(id: "employment_1", request: request)
        XCTAssertEqual(overview.employments.first?.startDate, selected)
        let refetched = try await service.loadEmployment(id: "employment_1")
        let reopened = CareerEmploymentDraft(record: refetched)
        XCTAssertEqual(reopened.startDate, selected)
        XCTAssertEqual(reopened.updateRequest().startDate, "1999-08-29")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.contains { $0.httpMethod == "PATCH" && $0.url?.path == "/api/v1/employments/employment_1" })
        XCTAssertTrue(requests.contains { $0.httpMethod == "GET" && $0.url?.path == "/api/v1/employments/employment_1" })
    }

    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_loadEmploymentDecodesSparseEditableRecord() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/employments/employment_sparse_1")
            return (try Self.response(for: request, statusCode: 200), Self.sparseEmploymentDetailPayload)
        }

        let record = try await service.loadEmployment(id: "employment_sparse_1")

        XCTAssertEqual(record.company, "First Meridian")
        XCTAssertEqual(record.role, "Trust Operations Specialist")
        XCTAssertEqual(record.verificationStatus, .notVerified)
        XCTAssertEqual(record.rawVerificationStatus, "draft")
        XCTAssertTrue(record.allowsCandidateEditing)
        XCTAssertTrue(record.allowsCandidateDeletion)
    }

    func test_createEmploymentPostsCanonicalBodyAndRefetchesOverview() async throws {
        let service = try await makeService()
        let request = CareerEmploymentCreateRequestDTO(
            subjectFullName: "Aarav Mehta",
            subjectEmail: "aarav@example.com",
            employerLegalName: "Northline Career Services",
            employerTradeName: nil,
            jobTitle: "Trust Operations Lead",
            employmentType: "full_time",
            verificationMethod: "document",
            startDate: "2024-01-01",
            endDate: nil,
            workLocationCountry: "IN",
            workLocationRegion: "Karnataka"
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/employments/":
                if request.httpMethod == "POST" {
                    let body = try requestJSONBody(from: request)
                    XCTAssertEqual(body["subject_full_name"] as? String, "Aarav Mehta")
                    XCTAssertEqual(body["job_title"] as? String, "Trust Operations Lead")
                    XCTAssertEqual(body["verification_method"] as? String, "document")
                    XCTAssertEqual(body["work_location_country"] as? String, "IN")
                    XCTAssertEqual(Set(body.keys), [
                        "subject_full_name",
                        "subject_email",
                        "employer_legal_name",
                        "job_title",
                        "employment_type",
                        "verification_method",
                        "start_date",
                        "work_location_country",
                        "work_location_region"
                    ])
                    return (try Self.response(for: request, statusCode: 201), Self.createdEmploymentPayload)
                }

                return try await Self.overviewResponse(for: request)
            default:
                return try await Self.overviewResponse(for: request)
            }
        }

        let overview = try await service.createEmployment(request)
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(overview.employments.first?.company, "Northline Career Services")
        XCTAssertEqual(
            requests.filter { $0.url?.absoluteString == "https://staging-api.kairoid.com/api/v1/employments/" && $0.httpMethod == "POST" }.count,
            1
        )
        XCTAssertEqual(
            requests.filter { $0.url?.absoluteString == "https://staging-api.kairoid.com/api/v1/users/me" }.count,
            1
        )
    }

    func test_createSkillPostsSingleCanonicalRecordAndRefetchesOverview() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            if request.url?.absoluteString == "https://staging-api.kairoid.com/api/v1/skills",
                request.httpMethod == "POST" {
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["name"] as? String, "SQL")
                XCTAssertEqual(Set(body.keys), ["name"])
                return (try Self.response(for: request, statusCode: 201), Self.createdSkillPayload)
            }
            return try await Self.overviewResponse(for: request)
        }

        let overview = try await service.createSkill(CareerSkillCreateRequestDTO(name: "SQL"))
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(overview.skills.first?.name, "Trust Operations")
        XCTAssertEqual(requests.filter { $0.httpMethod == "POST" }.count, 1)
        XCTAssertEqual(requests.filter { $0.httpMethod == "DELETE" }.count, 0)
    }

    func test_createPortfolioPostsSupportedFieldsAndRefetchesOverview() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            if request.url?.path == "/api/v1/portfolio", request.httpMethod == "POST" {
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["title"] as? String, "Accessible banking case study")
                XCTAssertEqual(body["description"] as? String, "A mobile accessibility redesign.")
                XCTAssertEqual(body["url"] as? String, "https://example.com/case-study")
                XCTAssertEqual(body["tags"] as? [String], ["Accessibility", "iOS"])
                XCTAssertEqual(Set(body.keys), ["title", "description", "url", "tags"])
                return (try Self.response(for: request, statusCode: 201), Self.portfolioPayload)
            }
            return try await Self.overviewResponse(for: request)
        }

        _ = try await service.createPortfolio(.init(
            title: "Accessible banking case study",
            description: "A mobile accessibility redesign.",
            url: "https://example.com/case-study",
            tags: ["Accessibility", "iOS"]
        ))

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.filter { $0.url?.path == "/api/v1/portfolio" && $0.httpMethod == "POST" }.count, 1)
    }

    func test_updatePortfolioPreservesAttachmentBySendingOnlyEditableMetadata() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            if request.url?.path == "/api/v1/portfolio/portfolio_1", request.httpMethod == "PATCH" {
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["title"] as? String, "Updated work sample")
                XCTAssertEqual(body["description"] as? String, "Kept")
                XCTAssertTrue(body["url"] is NSNull)
                XCTAssertEqual(body["tags"] as? [String], ["Research"])
                XCTAssertNil(body["original_filename"])
                XCTAssertNil(body["content_type"])
                XCTAssertNil(body["byte_size"])
                XCTAssertNil(body["upload_completed_at"])
                return (try Self.response(for: request, statusCode: 200), Self.portfolioPayload)
            }
            return try await Self.overviewResponse(for: request)
        }

        _ = try await service.updatePortfolio(
            id: "portfolio_1",
            request: .init(title: "Updated work sample", description: "Kept", url: nil, tags: ["Research"])
        )
        let writes = await MockURLProtocolStorage.shared.requests().filter { $0.httpMethod != "GET" }
        XCTAssertEqual(writes.count, 1)
    }

    func test_loadPortfolioUsesFirstClassDetailEndpoint() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/portfolio/portfolio_1")
            return (try Self.response(for: request, statusCode: 200), Self.portfolioPayload)
        }

        let record = try await service.loadPortfolio(id: "portfolio_1")
        XCTAssertEqual(record.title, "Accessible banking case study")
        XCTAssertEqual(record.tags, ["Accessibility", "iOS"])
        XCTAssertEqual(record.document?.originalFilename, "case-study.pdf")
    }

    func test_createCertificationWithDocumentUsesIntentUploadCompletionAndReload() async throws {
        let service = try await makeService()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("certificate.pdf")
        try Data("%PDF-certificate-fixture".utf8).write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let certification = CareerCertificationCreateRequestDTO(
            title: "Secure Product Certification",
            issuingOrganization: "KairoID Academy",
            issuedDate: "2026-01-01",
            expiryDate: nil,
            doesNotExpire: true,
            credentialID: "CERT-123",
            credentialURL: "https://example.com/cert/CERT-123"
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("POST", "staging-api.kairoid.com", "/api/v1/certifications/upload-intent"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["title"] as? String, "Secure Product Certification")
                XCTAssertEqual(body["original_filename"] as? String, "certificate.pdf")
                XCTAssertEqual(body["content_type"] as? String, "application/pdf")
                return (try Self.response(for: request, statusCode: 201), Self.certificationIntentPayload)
            case ("PUT", "storage.example", "/certificate-upload"):
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                return (try Self.response(for: request, statusCode: 200), Data())
            case ("POST", "staging-api.kairoid.com", "/api/v1/certifications/certification_upload_1/complete-upload"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual((body["checksum_sha256"] as? String)?.count, 64)
                return (try Self.response(for: request, statusCode: 200), Self.createdCertificationWithDocumentPayload)
            default:
                return try await Self.overviewResponse(for: request)
            }
        }

        _ = try await service.createCertification(certification, withDocument: fileURL)
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(requests.filter { $0.httpMethod == "PUT" }.count, 1)
        XCTAssertEqual(requests.filter { $0.url?.path.hasSuffix("/complete-upload") == true }.count, 1)
    }

    func test_updateCertificationMetadataDoesNotSendAttachmentMutationFields() async throws {
        let service = try await makeService()
        let update = CareerCertificationUpdateRequestDTO(
            title: "Updated title",
            issuingOrganization: "Updated issuer",
            issuedDate: "2026-01-01",
            expiryDate: nil,
            doesNotExpire: true,
            credentialID: "CERT-123",
            credentialURL: "https://example.com/cert/CERT-123"
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            if request.url?.path == "/api/v1/certifications/certification_1",
               request.httpMethod == "PATCH" {
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["title"] as? String, "Updated title")
                XCTAssertNil(body["object_key"])
                XCTAssertNil(body["original_filename"])
                XCTAssertNil(body["content_type"])
                XCTAssertNil(body["byte_size"])
                XCTAssertNil(body["upload_token"])
                return (try Self.response(for: request, statusCode: 200), Self.createdCertificationWithDocumentPayload)
            }
            if request.url?.path == "/api/v1/certifications/certification_1", request.httpMethod == "GET" {
                var record = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.createdCertificationWithDocumentPayload) as? [String: Any])
                record["id"] = "certification_1"
                record["title"] = "Updated title"
                return (try Self.response(for: request, statusCode: 200), try JSONSerialization.data(withJSONObject: record))
            }
            return try await Self.overviewResponse(for: request)
        }

        _ = try await service.updateCertification(id: "certification_1", request: update)
        let reopened = try await service.loadCertification(id: "certification_1")
        XCTAssertEqual(reopened.id, "certification_1")
        XCTAssertEqual(reopened.title, "Updated title")
        XCTAssertEqual(reopened.originalFilename, "certificate.pdf")
        let writes = await MockURLProtocolStorage.shared.requests().filter { $0.httpMethod != "GET" }
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes.first?.httpMethod, "PATCH")
        XCTAssertEqual(writes.first?.url?.path, "/api/v1/certifications/certification_1")
    }

    func test_deleteOperationsUseCanonicalRoutesAndRefetchOverview() async throws {
        let service = try await makeService()

        try await assertDeleteAndRefetch(
            service: service,
            expectedPath: "https://staging-api.kairoid.com/api/v1/employments/employment_1"
        ) {
            try await service.deleteEmployment(id: "employment_1")
        }

        try await assertDeleteAndRefetch(
            service: service,
            expectedPath: "https://staging-api.kairoid.com/api/v1/educations/education_1"
        ) {
            try await service.deleteEducation(id: "education_1")
        }

        try await assertDeleteAndRefetch(
            service: service,
            expectedPath: "https://staging-api.kairoid.com/api/v1/certifications/certification_1"
        ) {
            try await service.deleteCertification(id: "certification_1")
        }

        try await assertDeleteAndRefetch(
            service: service,
            expectedPath: "https://staging-api.kairoid.com/api/v1/projects/project_1"
        ) {
            try await service.deleteProject(id: "project_1")
        }

        try await assertDeleteAndRefetch(
            service: service,
            expectedPath: "https://staging-api.kairoid.com/api/v1/skills/skill_1"
        ) {
            try await service.deleteSkill(id: "skill_1")
        }
    }

    private func assertDeleteAndRefetch(
        service: CareerOverviewService,
        expectedPath: String,
        operation: @escaping () async throws -> CareerOverview
    ) async throws {
        await MockURLProtocolStorage.shared.reset()
        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case expectedPath:
                XCTAssertEqual(request.httpMethod, "DELETE")
                return (try Self.response(for: request, statusCode: 204), Data())
            default:
                return try await Self.overviewResponse(for: request)
            }
        }

        let overview = try await operation()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(requests.first?.url?.absoluteString, expectedPath)
        XCTAssertEqual(overview.user.email, "aarav@example.com")
        XCTAssertEqual(requests.filter { $0.url?.absoluteString == expectedPath && $0.httpMethod == "DELETE" }.count, 1)
        XCTAssertEqual(requests.filter { $0.url?.absoluteString == "https://staging-api.kairoid.com/api/v1/users/me" }.count, 1)
    }

    private func makeService() async throws -> CareerOverviewService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let authService = AuthService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            sessionService: sessionService
        )
        return CareerOverviewService(
            authService: authService,
            sessionService: sessionService,
            transferClient: SecureDocumentTransferClient(session: makeMockedURLSession())
        )
    }

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.career.mutations"
        )
    }

    private nonisolated static func overviewResponse(for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        switch request.url?.absoluteString {
        case "https://staging-api.kairoid.com/api/v1/portfolio?offset=0&limit=100":
            return (try response(for: request, statusCode: 200), Data("[]".utf8))
        case "https://staging-api.kairoid.com/api/v1/users/me":
            return (try response(for: request, statusCode: 200), userPayload)
        case "https://staging-api.kairoid.com/api/v1/employments/":
            return (try response(for: request, statusCode: 200), employmentsPayload)
        case "https://staging-api.kairoid.com/api/v1/educations":
            return (try response(for: request, statusCode: 200), educationsPayload)
        case "https://staging-api.kairoid.com/api/v1/certifications":
            return (try response(for: request, statusCode: 200), certificationsPayload)
        case "https://staging-api.kairoid.com/api/v1/projects":
            return (try response(for: request, statusCode: 200), projectsPayload)
        case "https://staging-api.kairoid.com/api/v1/skills":
            return (try response(for: request, statusCode: 200), skillsPayload)
        default:
            XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
            throw URLError(.badURL)
        }
    }

    private nonisolated static func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
    }

    private nonisolated static let userPayload = Data(
        """
        {
          "id": "user_123",
          "email": "aarav@example.com",
          "full_name": "Aarav Mehta",
          "profile_slug": "aarav-mehta",
          "phone": "+919876543210",
          "current_role": "Trust & Operations Associate",
          "industry": "Technology",
          "years_of_experience": 6,
          "location": "Bengaluru, India",
          "location_city": "Bengaluru",
          "location_region": "Karnataka",
          "location_country": "India",
          "headline": "Trust & Operations Associate",
          "bio": "Building verified professional trust.",
          "role": "user",
          "is_active": true,
          "profile_completion_percentage": 75,
          "created_at": "2026-08-01T08:00:00Z"
        }
        """.utf8
    )

    private nonisolated static let portfolioPayload = Data(
        """
        {
          "id": "portfolio_1",
          "title": "Accessible banking case study",
          "description": "A mobile accessibility redesign.",
          "url": "https://example.com/case-study",
          "tags": ["Accessibility", "iOS"],
          "original_filename": "case-study.pdf",
          "content_type": "application/pdf",
          "byte_size": 2048,
          "upload_completed_at": "2026-09-01T08:00:00Z",
          "verification_status": "draft",
          "created_at": "2026-08-01T08:00:00Z",
          "updated_at": "2026-09-01T08:00:00Z"
        }
        """.utf8
    )

    private nonisolated static let employmentsPayload = Data(
        """
        {
          "items": [
            {
              "id": "employment_1",
              "subject_full_name": "Aarav Mehta",
              "subject_email": "aarav@example.com",
              "employer_legal_name": "Northline Career Services",
              "job_title": "Trust & Operations Associate",
              "employment_type": "full_time",
              "start_date": "2024-01-01",
              "end_date": null,
              "work_location_country": "India",
              "work_location_region": "Karnataka",
              "verification_method": "document",
              "verification_status": "approved"
            }
          ]
        }
        """.utf8
    )

    private nonisolated static let educationsPayload = Data(
        """
        {
          "items": [
            {
              "id": "education_1",
              "institution_name": "Christ University",
              "degree": "BBA",
              "field_of_study": "Human Resources & Operations",
              "education_level": "bachelors",
              "start_date": "2016-06-01",
              "start_date_precision": "month",
              "end_date": "2019-04-01",
              "end_date_precision": "month",
              "is_currently_studying": false,
              "verification_status": "pending"
            }
          ]
        }
        """.utf8
    )

    private nonisolated static let certificationsPayload = Data(
        """
        {
          "items": [
            {
              "id": "certification_1",
              "title": "People Operations Foundations",
              "issuing_organization": "Northline Academy",
              "issued_date": "2025-03-01",
              "verification_status": "draft"
            }
          ]
        }
        """.utf8
    )

    private nonisolated static let projectsPayload = Data(
        """
        [
          {
            "id": "project_1",
            "title": "Career Trust Onboarding Pilot",
            "role": "Program Lead",
            "start_date": "2025-01-01",
            "end_date": "2025-06-01",
            "is_ongoing": false,
            "project_url": "https://portfolio.example.com/projects/1",
            "verification_status": "approved"
          }
        ]
        """.utf8
    )

    private nonisolated static let skillsPayload = Data(
        """
        [
          {
            "id": "skill_1",
            "name": "Trust Operations",
            "verification_status": "verified"
          }
        ]
        """.utf8
    )

    private nonisolated static let sparseEmploymentDetailPayload = Data(
        """
        {
          "id": "employment_sparse_1",
          "employer_legal_name": "First Meridian",
          "job_title": "Trust Operations Specialist",
          "employment_type": "full_time",
          "start_date": "2026-08-01",
          "end_date": null,
          "work_location_country": "India",
          "work_location_region": "Karnataka"
        }
        """.utf8
    )

    private nonisolated static let createdEmploymentPayload = Data(
        """
        {
          "id": "employment_created_1",
          "subject_full_name": "Aarav Mehta",
          "subject_email": "aarav@example.com",
          "employer_legal_name": "Northline Career Services",
          "job_title": "Trust Operations Lead",
          "employment_type": "full_time",
          "start_date": "2024-01-01",
          "end_date": null,
          "work_location_country": "India",
          "work_location_region": "Karnataka",
          "verification_method": "document",
          "verification_status": "draft"
        }
        """.utf8
    )

    private nonisolated static let createdSkillPayload = Data(
        """
        {
          "id": "skill_created_1",
          "name": "SQL",
          "verification_status": "draft"
        }
        """.utf8
    )

    private nonisolated static let certificationIntentPayload = Data(
        #"{"certification_id":"certification_upload_1","upload_url":"https://storage.example/certificate-upload","expires_in_seconds":300}"#.utf8
    )

    private nonisolated static let createdCertificationWithDocumentPayload = Data(
        """
        {
          "id": "certification_upload_1",
          "title": "Secure Product Certification",
          "issuing_organization": "KairoID Academy",
          "issued_date": "2026-01-01",
          "expiry_date": null,
          "does_not_expire": true,
          "credential_id": "CERT-123",
          "credential_url": "https://example.com/cert/CERT-123",
          "original_filename": "certificate.pdf",
          "content_type": "application/pdf",
          "byte_size": 24,
          "verification_status": "draft"
        }
        """.utf8
    )
}
