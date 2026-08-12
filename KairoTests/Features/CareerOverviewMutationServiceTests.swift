import Foundation
import XCTest
@testable import Kairo

@MainActor
final class CareerOverviewMutationServiceTests: XCTestCase {
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

    func test_replaceSkillPostsNewSkillDeletesOldSkillAndRefetchesOverview() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/skills":
                if request.httpMethod == "POST" {
                    let body = try requestJSONBody(from: request)
                    XCTAssertEqual(body["name"] as? String, "SQL")
                    return (try Self.response(for: request, statusCode: 201), Self.createdSkillPayload)
                }
                return try await Self.overviewResponse(for: request)
            case "https://staging-api.kairoid.com/api/v1/skills/skill_1":
                XCTAssertEqual(request.httpMethod, "DELETE")
                return (try Self.response(for: request, statusCode: 204), Data())
            default:
                return try await Self.overviewResponse(for: request)
            }
        }

        let overview = try await service.replaceSkill(
            id: "skill_1",
            with: CareerSkillCreateRequestDTO(name: "SQL")
        )
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(overview.skills.first?.name, "Trust Operations")
        XCTAssertEqual(
            requests.filter { $0.url?.absoluteString == "https://staging-api.kairoid.com/api/v1/skills" && $0.httpMethod == "POST" }.count,
            1
        )
        XCTAssertEqual(
            requests.filter { $0.url?.absoluteString == "https://staging-api.kairoid.com/api/v1/skills/skill_1" && $0.httpMethod == "DELETE" }.count,
            1
        )
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
            sessionService: sessionService
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
}
