import Foundation
import XCTest
@testable import Kairo

@MainActor
final class ManualProfileServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_submitPersistsProfileThenEmploymentsThenEducationsThenCompletesOnboarding() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.currentUserPayload)
            case ("PATCH", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.updatedUserPayload)
            case ("GET", "/api/v1/employments"):
                return (try Self.response(for: request, statusCode: 200), Data("{\"items\":[]}".utf8))
            case ("POST", "/api/v1/employments/"):
                return (try Self.response(for: request, statusCode: 201), Data("{\"id\":\"employment_1\"}".utf8))
            case ("GET", "/api/v1/educations"):
                return (try Self.response(for: request, statusCode: 200), Data("{\"items\":[]}".utf8))
            case ("POST", "/api/v1/educations"):
                return (try Self.response(for: request, statusCode: 201), Data("{\"id\":\"education_1\"}".utf8))
            case ("POST", "/api/v1/users/me/complete-onboarding"):
                return (try Self.response(for: request, statusCode: 204), Data())
            case ("GET", "/api/v1/onboarding/status"):
                return (try Self.response(for: request, statusCode: 200), Self.completedOnboardingStatusPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let result = try await service.submit(
            draft: makeDraft()
        )
        let requests = await MockURLProtocolStorage.shared.requests()
        let orderedPaths = requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" }

        XCTAssertEqual(
            orderedPaths,
            [
                "GET /api/v1/users/me",
                "PATCH /api/v1/users/me",
                "GET /api/v1/employments",
                "POST /api/v1/employments/",
                "GET /api/v1/educations",
                "POST /api/v1/educations",
                "POST /api/v1/users/me/complete-onboarding",
                "GET /api/v1/users/me",
                "GET /api/v1/onboarding/status"
            ]
        )

        let profileBody = try XCTUnwrap(requests[1].httpBody)
        let profileJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: profileBody) as? [String: Any]
        )
        XCTAssertEqual(profileJSON["headline"] as? String, "Trust Operations Specialist")
        XCTAssertEqual(profileJSON["current_role"] as? String, "Trust Operations Specialist")
        XCTAssertEqual(profileJSON["industry"] as? String, "Technology")
        XCTAssertEqual(profileJSON["years_of_experience"] as? Int, 4)

        let employmentBody = try XCTUnwrap(requests[3].httpBody)
        let employmentJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: employmentBody) as? [String: Any]
        )
        XCTAssertEqual(employmentJSON["subject_full_name"] as? String, "Aman Jha")
        XCTAssertEqual(employmentJSON["employment_type"] as? String, "full_time")
        XCTAssertEqual(employmentJSON["start_date"] as? String, "2022-01-01")
        XCTAssertEqual(employmentJSON["work_location_country"] as? String, "IN")

        let educationBody = try XCTUnwrap(requests[5].httpBody)
        let educationJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: educationBody) as? [String: Any]
        )
        XCTAssertEqual(educationJSON["institution_name"] as? String, "Delhi Institute of Technology")
        XCTAssertEqual(educationJSON["education_level"] as? String, "bachelors")
        XCTAssertEqual(educationJSON["start_date_precision"] as? String, "year")

        XCTAssertTrue(result.onboardingStatus.isOnboardingComplete)
        XCTAssertEqual(result.user.email, "aman@example.com")
    }

    func test_submitStopsWhenProfileValidationFails() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            if request.httpMethod == "GET", request.url?.path == "/api/v1/users/me" {
                return (try Self.response(for: request, statusCode: 200), Self.currentUserPayload)
            }

            if request.httpMethod == "PATCH", request.url?.path == "/api/v1/users/me" {
                return (try Self.response(for: request, statusCode: 422), Self.profileValidationErrorPayload)
            }

            XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
            throw URLError(.badURL)
        }

        do {
            _ = try await service.submit(draft: makeDraft())
            XCTFail("Expected submission to throw a profile validation error")
        } catch let error as ManualProfileSubmissionError {
            XCTAssertEqual(
                error,
                .fieldValidation(
                    step: .basicProfile,
                    fieldErrors: ["headline": "Enter your professional headline."],
                    message: "Request validation failed"
                )
            )
        }

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/users/me",
                "PATCH /api/v1/users/me"
            ]
        )
    }

    func test_submitStopsBeforeEducationAndCompletionWhenEmploymentFails() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.currentUserPayload)
            case ("PATCH", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.updatedUserPayload)
            case ("GET", "/api/v1/employments"):
                return (try Self.response(for: request, statusCode: 200), Data("{\"items\":[]}".utf8))
            case ("POST", "/api/v1/employments/"):
                return (try Self.response(for: request, statusCode: 422), Self.employmentValidationErrorPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        do {
            _ = try await service.submit(draft: makeDraft())
            XCTFail("Expected submission to throw an employment validation error")
        } catch let error as ManualProfileSubmissionError {
            XCTAssertEqual(
                error,
                .fieldValidation(
                    step: .employment(entryID: 0),
                    fieldErrors: ["work_location_country": "Enter a valid country."],
                    message: "Request validation failed"
                )
            )
        }

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(
            requests.map { "\($0.httpMethod ?? "nil") \($0.url?.path ?? "nil")" },
            [
                "GET /api/v1/users/me",
                "PATCH /api/v1/users/me",
                "GET /api/v1/employments",
                "POST /api/v1/employments/"
            ]
        )
    }

    func test_retryDoesNotDuplicateEmploymentCreatedBeforePartialFailure() async throws {
        let service = try await makeService()
        let draft = makeDraftWithTwoEmployments()
        let gate = ManualProfileFailureGate()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.currentUserPayload)
            case ("PATCH", "/api/v1/users/me"):
                return (try Self.response(for: request, statusCode: 200), Self.updatedUserPayload)
            case ("GET", "/api/v1/employments"):
                if await gate.didFailOnce {
                    return (try Self.response(for: request, statusCode: 200), Self.existingFirstEmploymentPayload)
                }
                return (try Self.response(for: request, statusCode: 200), Data("{\"items\":[]}".utf8))
            case ("POST", "/api/v1/employments/"):
                let body = try XCTUnwrap(request.httpBody)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                if (payload["employer_legal_name"] as? String) == "First Meridian" {
                    return (try Self.response(for: request, statusCode: 201), Data("{\"id\":\"employment_first\"}".utf8))
                }

                if await gate.consumeFailure() {
                    throw URLError(.notConnectedToInternet)
                }

                return (try Self.response(for: request, statusCode: 201), Data("{\"id\":\"employment_second\"}".utf8))
            case ("GET", "/api/v1/educations"):
                return (try Self.response(for: request, statusCode: 200), Data("{\"items\":[]}".utf8))
            case ("POST", "/api/v1/educations"):
                return (try Self.response(for: request, statusCode: 201), Data("{\"id\":\"education_1\"}".utf8))
            case ("POST", "/api/v1/users/me/complete-onboarding"):
                return (try Self.response(for: request, statusCode: 204), Data())
            case ("GET", "/api/v1/onboarding/status"):
                return (try Self.response(for: request, statusCode: 200), Self.completedOnboardingStatusPayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        do {
            _ = try await service.submit(draft: draft)
            XCTFail("Expected first submission attempt to fail")
        } catch let error as NetworkError {
            guard case .transport = error else {
                return XCTFail("Expected transport error, received \(error)")
            }
        }

        _ = try await service.submit(draft: draft)

        let requests = await MockURLProtocolStorage.shared.requests()
        let employmentPosts = requests.filter {
            $0.httpMethod == "POST" && $0.url?.path == "/api/v1/employments/"
        }

        XCTAssertEqual(employmentPosts.count, 3)
        let postedEmployers = try employmentPosts.map { request -> String in
            let body = try XCTUnwrap(request.httpBody)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            return try XCTUnwrap(payload["employer_legal_name"] as? String)
        }
        XCTAssertEqual(
            postedEmployers,
            ["First Meridian", "Second Meridian", "Second Meridian"]
        )
    }

    private func makeService() async throws -> ManualProfileService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)
        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.manualProfile"
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

        return ManualProfileService(
            authService: authService,
            sessionService: sessionService
        )
    }

    private func makeDraft() -> ManualProfileFlowState {
        var draft = ManualProfileFlowState()
        draft.basicProfile = ManualProfileBasicDraft(
            fullName: "Aman Jha",
            professionalHeadline: "Trust Operations Specialist",
            currentRole: "Trust Operations Specialist",
            industry: "Technology",
            yearsOfExperience: "4",
            currentCity: "Bengaluru",
            currentCountry: "India"
        )
        draft.updateEmployment(id: 0) { entry in
            entry.company = "Meridian Trust"
            entry.jobTitle = "Trust Operations Specialist"
            entry.employmentType = "Full-time"
            entry.workCountry = "India"
            entry.startDay = "1"
            entry.startMonth = "January"
            entry.startYear = "2022"
            entry.isCurrentlyWorking = true
        }
        draft.updateEducation(id: 0) { entry in
            entry.institution = "Delhi Institute of Technology"
            entry.degree = "B.Tech"
            entry.educationLevel = "Bachelor's"
            entry.fieldOfStudy = "Information Technology"
            entry.startYear = "2016"
            entry.endYear = "2020"
        }
        return draft
    }

    private func makeDraftWithTwoEmployments() -> ManualProfileFlowState {
        var draft = makeDraft()
        draft.updateEmployment(id: 0) { entry in
            entry.company = "First Meridian"
        }
        draft.addEmployment()
        let secondID = draft.employmentEntries[1].id
        draft.updateEmployment(id: secondID) { entry in
            entry.company = "Second Meridian"
            entry.jobTitle = "Trust Operations Lead"
            entry.employmentType = "Full-time"
            entry.workCountry = "India"
            entry.startDay = "3"
            entry.startMonth = "March"
            entry.startYear = "2024"
            entry.isCurrentlyWorking = true
        }
        return draft
    }

    private nonisolated static func response(
        for request: URLRequest,
        statusCode: Int
    ) throws -> HTTPURLResponse {
        try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
    }

    private nonisolated static let currentUserPayload = Data(
        """
        {
          "id": "user_123",
          "email": "aman@example.com",
          "full_name": "Aman Jha",
          "profile_slug": "aman-jha",
          "phone": "+919876543210",
          "role": "user",
          "is_active": true,
          "phone_verified_at": "2026-08-08T08:00:00Z",
          "email_verified_at": "2026-08-08T08:00:00Z",
          "profile_completion_percentage": 75,
          "created_at": "2026-08-01T08:00:00Z"
        }
        """.utf8
    )

    private nonisolated static let updatedUserPayload = Data(
        """
        {
          "id": "user_123",
          "email": "aman@example.com",
          "full_name": "Aman Jha",
          "profile_slug": "aman-jha",
          "phone": "+919876543210",
          "current_role": "Trust Operations Specialist",
          "industry": "Technology",
          "years_of_experience": 4,
          "location": "Bengaluru, India",
          "location_city": "Bengaluru",
          "location_country": "IN",
          "headline": "Trust Operations Specialist",
          "role": "user",
          "is_active": true,
          "phone_verified_at": "2026-08-08T08:00:00Z",
          "email_verified_at": "2026-08-08T08:00:00Z",
          "employment_onboarding_completed_at": "2026-08-08T08:10:00Z",
          "profile_completion_percentage": 100,
          "created_at": "2026-08-01T08:00:00Z"
        }
        """.utf8
    )

    private nonisolated static let completedOnboardingStatusPayload = Data(
        """
        {
          "current_step": "complete",
          "email_verified": true,
          "phone_verified": true,
          "passport_ready": true,
          "completed_steps": ["verify_email", "verify_phone", "complete_profile"],
          "missing_requirements": [],
          "next_recommended_step": null,
          "completion_percentage": 100,
          "is_onboarding_complete": true
        }
        """.utf8
    )

    private nonisolated static let profileValidationErrorPayload = Data(
        """
        {
          "error": {
            "code": "validation_error",
            "message": "Request validation failed",
            "details": [
              {
                "location": ["body", "headline"],
                "message": "Enter your professional headline.",
                "error_type": "value_error"
              }
            ]
          }
        }
        """.utf8
    )

    private nonisolated static let employmentValidationErrorPayload = Data(
        """
        {
          "error": {
            "code": "validation_error",
            "message": "Request validation failed",
            "details": [
              {
                "location": ["body", "work_location_country"],
                "message": "Enter a valid country.",
                "error_type": "value_error"
              }
            ]
          }
        }
        """.utf8
    )

    private nonisolated static let existingFirstEmploymentPayload = Data(
        """
        {
          "items": [
            {
              "id": "employment_first",
              "employer_legal_name": "First Meridian",
              "job_title": "Trust Operations Specialist",
              "employment_type": "full_time",
              "start_date": "2022-01-01",
              "end_date": null,
              "work_location_country": "IN",
              "work_location_region": null,
              "verification_status": "draft"
            }
          ]
        }
        """.utf8
    )
}

private actor ManualProfileFailureGate {
    private var hasFailed = false

    var didFailOnce: Bool {
        hasFailed
    }

    func consumeFailure() -> Bool {
        if hasFailed {
            return false
        }

        hasFailed = true
        return true
    }
}
