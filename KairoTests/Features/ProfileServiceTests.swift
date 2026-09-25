import Foundation
import XCTest
@testable import Kairo

@MainActor
final class ProfileServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_loadMapsProfileSkillsLanguagesAndLinks() async throws {
        let service = try await makeService()
        await installStandardHandler()

        let snapshot = try await service.load()

        XCTAssertEqual(snapshot.user.fullName, "Synthetic Candidate")
        XCTAssertEqual(snapshot.user.languages.map(\.language), ["English"])
        XCTAssertEqual(snapshot.user.professionalLinks.map(\.linkType), ["linkedin"])
        XCTAssertEqual(snapshot.skills.map(\.name), ["SQL"])
    }

    func test_updateSendsOnlySupportedProfileFieldsAndRefetches() async throws {
        let service = try await makeService()
        let draft = ProfileEditDraft(user: ProfileSnapshot.fixture.user)
        await installStandardHandler { request in
            guard request.url?.path == "/api/v1/users/me", request.httpMethod == "PATCH" else { return }
            let body = try requestJSONBody(from: request)
            XCTAssertEqual(body["full_name"] as? String, "Aarav Mehta")
            XCTAssertEqual(body["phone"] as? String, "+919876543210")
            XCTAssertEqual(body["location_region"] as? String, "Karnataka")
            XCTAssertEqual(body["bio"] as? String, "Product operator focused on portable professional trust.")
            XCTAssertNil(body["email"])
            XCTAssertNil(body["pan"])
            XCTAssertNil(body["driving_licence_number"])
        }

        _ = try await service.update(draft)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.filter { $0.httpMethod == "PATCH" }.count, 1)
        XCTAssertEqual(requests.filter { $0.url?.path == "/api/v1/users/me" && $0.httpMethod == "GET" }.count, 1)
    }

    func test_skillMutationUsesCanonicalEndpointAndRefetches() async throws {
        let service = try await makeService()
        await installStandardHandler { request in
            guard request.url?.path == "/api/v1/skills", request.httpMethod == "POST" else { return }
            let body = try requestJSONBody(from: request)
            XCTAssertEqual(body["name"] as? String, "Microsoft Excel")
            XCTAssertEqual(Set(body.keys), ["name"])
        }

        _ = try await service.addSkill(name: "Microsoft Excel")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.filter { $0.httpMethod == "POST" }.count, 1)
    }

    func test_languageCreateUpdateAndDeleteUseBackendVocabulary() async throws {
        let service = try await makeService()
        await installStandardHandler { request in
            guard request.url?.path.contains("/api/v1/users/me/languages") == true else { return }
            if request.httpMethod == "POST" || request.httpMethod == "PATCH" {
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["language"] as? String, "Marathi")
                XCTAssertEqual(body["proficiency"] as? String, "native")
            }
        }

        _ = try await service.addLanguage(name: "Marathi", proficiency: .native)
        _ = try await service.updateLanguage(id: "language-1", name: "Marathi", proficiency: .native)
        _ = try await service.removeLanguage(id: "language-1")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.contains { $0.url?.path.hasSuffix("/languages/language-1") == true && $0.httpMethod == "PATCH" })
        XCTAssertTrue(requests.contains { $0.url?.path.hasSuffix("/languages/language-1") == true && $0.httpMethod == "DELETE" })
    }

    func test_linkMutationUsesApprovedTypeAndNormalizedURL() async throws {
        let service = try await makeService()
        await installStandardHandler { request in
            guard request.url?.path == "/api/v1/users/me/links", request.httpMethod == "POST" else { return }
            let body = try requestJSONBody(from: request)
            XCTAssertEqual(body["link_type"] as? String, "linkedin")
            XCTAssertEqual(body["label"] as? String, "Professional profile")
            XCTAssertEqual(body["url"] as? String, "https://www.linkedin.com/in/synthetic")
        }
        let url = try XCTUnwrap(ProfileURLValidator.normalized("www.linkedin.com/in/synthetic"))
        _ = try await service.addLink(type: .linkedin, label: "Professional profile", url: url)
    }

    func test_avatarUsesUnauthenticatedHTTPSUploadThenCompletes() async throws {
        let service = try await makeService()
        await installStandardHandler { request in
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("POST", "staging-api.kairoid.com", "/api/v1/users/me/avatar-upload-url"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-profile")
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["content_type"] as? String, "image/jpeg")
            case ("PUT", "storage.example", "/profile-photo"):
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
            case ("POST", "staging-api.kairoid.com", "/api/v1/users/me/avatar/complete"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-profile")
            default: break
            }
        }

        _ = try await service.uploadAvatar(jpegData: Data(repeating: 0x01, count: 1024))
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.filter { $0.httpMethod == "PUT" }.count, 1)
        XCTAssertTrue(requests.contains { $0.url?.path == "/api/v1/users/me/avatar/complete" })
    }

    func test_avatarRejectsEmptyAndOversizedDataBeforeNetworking() async throws {
        let service = try await makeService()
        await XCTAssertThrowsErrorAsync { _ = try await service.uploadAvatar(jpegData: Data()) }
        await XCTAssertThrowsErrorAsync {
            _ = try await service.uploadAvatar(jpegData: Data(repeating: 0x01, count: 5 * 1_024 * 1_024 + 1))
        }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    func test_invalidStructuredValuesAreRejectedBeforeNetworking() async throws {
        let service = try await makeService()

        await XCTAssertThrowsErrorAsync { _ = try await service.addSkill(name: "Invented Skill") }
        await XCTAssertThrowsErrorAsync {
            _ = try await service.addLanguage(name: "Invented Language", proficiency: .fluent)
        }
        let unsafeURL = try XCTUnwrap(URL(string: "javascript:alert(1)"))
        await XCTAssertThrowsErrorAsync {
            _ = try await service.addLink(type: .other, label: nil, url: unsafeURL)
        }

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    private func makeService() async throws -> ProfileService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-profile", for: .accessToken)
        let client = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.profile"
        )
        let session = SessionService(configuration: configuration, networkClient: client, tokenStore: tokenStore)
        return ProfileService(session: session, transfer: SecureDocumentTransferClient(session: makeMockedURLSession()))
    }

    private func installStandardHandler(
        assertion: (@Sendable (URLRequest) throws -> Void)? = nil
    ) async {
        await MockURLProtocolStorage.shared.setHandler { request in
            try assertion?(request)
            let response = try Self.response(for: request, statusCode: request.httpMethod == "DELETE" ? 204 : 200)
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("GET", _, "/api/v1/users/me"):
                return (response, Self.profilePayload)
            case ("GET", _, "/api/v1/skills"):
                return (response, Self.skillsPayload)
            case ("POST", _, "/api/v1/users/me/avatar-upload-url"):
                return (response, Data(#"{"upload_url":"https://storage.example/profile-photo"}"#.utf8))
            case ("PUT", "storage.example", "/profile-photo"):
                return (response, Data())
            default:
                return (response, Data("{}".utf8))
            }
        }
    }

    private nonisolated static func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: statusCode, httpVersion: nil, headerFields: nil))
    }

    private nonisolated static let skillsPayload = Data(#"[{"id":"skill-1","name":"SQL","verification_status":"self_declared"}]"#.utf8)

    private nonisolated static let profilePayload = Data(
        """
        {
          "id":"profile-user","email":"candidate@example.invalid","full_name":"Synthetic Candidate",
          "profile_slug":"synthetic-candidate","phone":"+919876543210","current_role":"Product Manager",
          "industry":"Technology","years_of_experience":6,"location":"Bengaluru, India",
          "location_city":"Bengaluru","location_region":"Karnataka","location_country":"IN",
          "headline":"Product Operations Manager","bio":"Building trust.","date_of_birth":"2000-09-25",
          "avatar_url":null,"role":"candidate","is_active":true,"phone_verified_at":null,
          "email_verified_at":"2026-09-01T00:00:00Z","employment_onboarding_completed_at":null,
          "languages":[{"id":"language-1","language":"English","proficiency":"fluent"}],
          "professional_links":[{"id":"link-1","link_type":"linkedin","label":"LinkedIn","url":"https://www.linkedin.com/in/synthetic"}],
          "profile_completion_percentage":88,"created_at":"2026-01-01T00:00:00Z"
        }
        """.utf8
    )
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}
