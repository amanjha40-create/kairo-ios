import Foundation
import XCTest
@testable import Kairo

@MainActor
final class CareerOverviewServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_loadOverviewFetchesCareerCollectionsOverAuthenticatedRequests() async throws {
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
        let service = CareerOverviewService(
            authService: authService,
            sessionService: sessionService
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/users/me":
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case "https://staging-api.kairoid.com/api/v1/employments/":
                return (try Self.response(for: request, statusCode: 200), Self.employmentsPayload)
            case "https://staging-api.kairoid.com/api/v1/educations":
                return (try Self.response(for: request, statusCode: 200), Self.educationsPayload)
            case "https://staging-api.kairoid.com/api/v1/certifications":
                return (try Self.response(for: request, statusCode: 200), Self.certificationsPayload)
            case "https://staging-api.kairoid.com/api/v1/projects":
                return (try Self.response(for: request, statusCode: 200), Self.projectsPayload)
            case "https://staging-api.kairoid.com/api/v1/skills":
                return (try Self.response(for: request, statusCode: 200), Self.skillsPayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.loadOverview()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(
            Set(requests.compactMap(\.url?.path)),
            [
                "/api/v1/users/me",
                "/api/v1/employments",
                "/api/v1/educations",
                "/api/v1/certifications",
                "/api/v1/projects",
                "/api/v1/skills"
            ]
        )
        XCTAssertEqual(
            requests.first(where: { $0.url?.absoluteString.contains("/api/v1/employments") == true })?.url?.absoluteString,
            "https://staging-api.kairoid.com/api/v1/employments/"
        )
        XCTAssertEqual(requests.count, 6)
        XCTAssertEqual(overview.user.email, "aarav@example.com")
        XCTAssertEqual(overview.employments.first?.company, "Northline Career Services")
        XCTAssertTrue(overview.employments.first?.currentlyWorking ?? false)
        XCTAssertEqual(overview.educations.first?.institution, "Christ University")
        XCTAssertEqual(overview.educations.first?.startDate, Self.utcDate(year: 2016, month: 6, day: 1))
        XCTAssertEqual(overview.educations.first?.startDatePrecision, "month")
        XCTAssertTrue(overview.certifications.isEmpty)
        XCTAssertTrue(overview.projects.isEmpty)
        XCTAssertEqual(
            overview.skills.map(\.name),
            ["Trust Operations", "Employment Verification", "People Operations", "Stakeholder Communication"]
        )
    }

    func test_loadOverviewSurfacesUnderlyingDecodeErrorInsteadOfCancelledTransportError() async throws {
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
        let service = CareerOverviewService(
            authService: authService,
            sessionService: sessionService
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/users/me":
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case "https://staging-api.kairoid.com/api/v1/employments/":
                try await Task.sleep(nanoseconds: 150_000_000)
                return (try Self.response(for: request, statusCode: 200), Self.employmentsPayload)
            case "https://staging-api.kairoid.com/api/v1/educations":
                return (try Self.response(for: request, statusCode: 200), Data("{\"items\":[{}]}".utf8))
            case "https://staging-api.kairoid.com/api/v1/certifications":
                return (try Self.response(for: request, statusCode: 200), Self.certificationsPayload)
            case "https://staging-api.kairoid.com/api/v1/projects":
                return (try Self.response(for: request, statusCode: 200), Self.projectsPayload)
            case "https://staging-api.kairoid.com/api/v1/skills":
                return (try Self.response(for: request, statusCode: 200), Self.skillsPayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        do {
            _ = try await service.loadOverview()
            XCTFail("Expected loadOverview to throw a decoding error")
        } catch let error as DecodingError {
            switch error {
            case .keyNotFound:
                break
            default:
                XCTFail("Expected keyNotFound decoding error, received \(error)")
            }
        } catch let error as NetworkError {
            XCTFail("Expected decode error, received network error: \(error)")
        }

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(
            Set(requests.compactMap(\.url?.path)),
            [
                "/api/v1/users/me",
                "/api/v1/employments",
                "/api/v1/educations",
                "/api/v1/certifications",
                "/api/v1/projects",
                "/api/v1/skills"
            ]
        )
        XCTAssertEqual(
            requests.first(where: { $0.url?.absoluteString.contains("/api/v1/employments") == true })?.url?.absoluteString,
            "https://staging-api.kairoid.com/api/v1/employments/"
        )
    }

    func test_loadOverviewRefetchesCareerCollectionsAfterARetry() async throws {
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
        let service = CareerOverviewService(
            authService: authService,
            sessionService: sessionService
        )

        let failureGate = FailureGate()
        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/users/me":
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case "https://staging-api.kairoid.com/api/v1/employments/":
                if await failureGate.consumeFirstFailure() {
                    throw URLError(.notConnectedToInternet)
                }
                return (try Self.response(for: request, statusCode: 200), Self.employmentsPayload)
            case "https://staging-api.kairoid.com/api/v1/educations":
                return (try Self.response(for: request, statusCode: 200), Self.educationsPayload)
            case "https://staging-api.kairoid.com/api/v1/certifications":
                return (try Self.response(for: request, statusCode: 200), Self.certificationsPayload)
            case "https://staging-api.kairoid.com/api/v1/projects":
                return (try Self.response(for: request, statusCode: 200), Self.projectsPayload)
            case "https://staging-api.kairoid.com/api/v1/skills":
                return (try Self.response(for: request, statusCode: 200), Self.skillsPayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        do {
            _ = try await service.loadOverview()
            XCTFail("Expected first loadOverview attempt to fail")
        } catch let error as NetworkError {
            guard case .transport = error else {
                return XCTFail("Expected transport error, received \(error)")
            }
        }

        let overview = try await service.loadOverview()
        let requests = await MockURLProtocolStorage.shared.requests()
        let employmentRequests = requests.filter { $0.url?.absoluteString == "https://staging-api.kairoid.com/api/v1/employments/" }

        XCTAssertEqual(employmentRequests.count, 2)
        XCTAssertEqual(overview.employments.count, 1)
        XCTAssertEqual(overview.educations.count, 1)
        XCTAssertEqual(overview.skills.count, 4)
    }

    func test_loadOverviewDecodesSparseLiveCareerRecords() async throws {
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
        let service = CareerOverviewService(
            authService: authService,
            sessionService: sessionService
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/users/me":
                return (try Self.response(for: request, statusCode: 200), Self.userPayload)
            case "https://staging-api.kairoid.com/api/v1/employments/":
                return (try Self.response(for: request, statusCode: 200), Self.sparseEmploymentsPayload)
            case "https://staging-api.kairoid.com/api/v1/educations":
                return (try Self.response(for: request, statusCode: 200), Self.sparseEducationsPayload)
            case "https://staging-api.kairoid.com/api/v1/certifications":
                return (try Self.response(for: request, statusCode: 200), Self.certificationsPayload)
            case "https://staging-api.kairoid.com/api/v1/projects":
                return (try Self.response(for: request, statusCode: 200), Self.projectsPayload)
            case "https://staging-api.kairoid.com/api/v1/skills":
                return (try Self.response(for: request, statusCode: 200), Self.sparseSkillsPayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.loadOverview()

        XCTAssertEqual(overview.employments.first?.company, "First Meridian")
        XCTAssertEqual(overview.employments.first?.verificationStatus, .notVerified)
        XCTAssertEqual(overview.educations.first?.institution, "Delhi Institute of Technology")
        XCTAssertEqual(overview.educations.first?.verificationStatus, .notVerified)
        XCTAssertEqual(overview.skills.map(\.id), ["Trust Operations"])
        XCTAssertEqual(overview.skills.map(\.name), ["Trust Operations"])
    }

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.career"
        )
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
          "created_at": "2026-07-30T08:00:00Z"
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
              "employer_trade_name": null,
              "job_title": "Trust & Operations Associate",
              "employment_type": "full_time",
              "start_date": "2024-01-01",
              "end_date": null,
              "work_location_country": "India",
              "work_location_region": "Karnataka",
              "verification_method": "document",
              "verification_status": "approved",
              "submitted_at": "2026-07-31T09:00:00Z",
              "reviewed_at": null,
              "assigned_reviewer_user_id": null,
              "assigned_at": null,
              "created_at": "2026-07-31T08:00:00Z",
              "updated_at": "2026-07-31T08:30:00Z"
            }
          ],
          "total": 1,
          "page": 1,
          "page_size": 20,
          "total_pages": 1,
          "offset": 0,
          "limit": 20
        }
        """.utf8
    )

    private nonisolated static let sparseEmploymentsPayload = Data(
        """
        {
          "items": [
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
              "user_id": "user_123",
              "institution_name": "Christ University",
              "degree": "BBA",
              "field_of_study": "Human Resources & Operations",
              "education_level": "bachelors",
              "grade": null,
              "start_date": "2016-06-01",
              "start_date_precision": "month",
              "end_date": "2019-04-01",
              "end_date_precision": "month",
              "is_currently_studying": false,
              "verification_status": "pending",
              "submitted_at": null,
              "reviewed_at": null,
              "reviewed_by_user_id": null,
              "reviewer_note": null,
              "created_at": "2026-07-31T08:00:00Z",
              "updated_at": "2026-07-31T08:30:00Z"
            }
          ],
          "total": 1,
          "page": 1,
          "page_size": 20,
          "total_pages": 1,
          "offset": 0,
          "limit": 20
        }
        """.utf8
    )

    private nonisolated static let sparseEducationsPayload = Data(
        """
        {
          "items": [
            {
              "id": "education_sparse_1",
              "institution_name": "Delhi Institute of Technology",
              "degree": "B.Tech",
              "field_of_study": "Computer Science",
              "education_level": "bachelors",
              "start_date": "2017-06-01",
              "end_date": "2021-05-01",
              "is_currently_studying": false
            }
          ]
        }
        """.utf8
    )

    private nonisolated static let certificationsPayload = Data(
        """
        {
          "items": [],
          "total": 0,
          "page": 1,
          "page_size": 20,
          "total_pages": 0,
          "offset": 0,
          "limit": 20
        }
        """.utf8
    )

    private nonisolated static let projectsPayload = Data(
        """
        []
        """.utf8
    )

    private nonisolated static let skillsPayload = Data(
        """
        [
          {
            "id": "skill_1",
            "user_id": "user_123",
            "name": "Trust Operations",
            "verification_status": "verified"
          },
          {
            "id": "skill_2",
            "user_id": "user_123",
            "name": "Employment Verification",
            "verification_status": "pending_verification"
          },
          {
            "id": "skill_3",
            "user_id": "user_123",
            "name": "People Operations",
            "verification_status": "not_verified"
          },
          {
            "id": "skill_4",
            "user_id": "user_123",
            "name": "Stakeholder Communication",
            "verification_status": "verified"
          }
        ]
        """.utf8
    )

    private nonisolated static let sparseSkillsPayload = Data(
        """
        [
          {
            "name": "Trust Operations"
          }
        ]
        """.utf8
    )
}

private actor FailureGate {
    private var hasFailed = false

    func consumeFirstFailure() -> Bool {
        guard !hasFailed else {
            return false
        }

        hasFailed = true
        return true
    }
}

private extension CareerOverviewServiceTests {
    nonisolated static func utcDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
