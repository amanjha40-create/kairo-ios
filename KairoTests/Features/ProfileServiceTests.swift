import Foundation
import XCTest
@testable import Kairo

@MainActor
final class ProfileServiceTests: XCTestCase {
    func testDOBMissingCanBeSavedAndRestoredFromFreshAuthenticatedRead() async throws {
        let state = ProfilePatchTestState(data: Self.profilePayload)
        try await state.apply(body: Data(#"{"date_of_birth":null}"#.utf8), link: false)
        await installStatefulHandler(state)
        let service = try await makeService()
        var draft = ProfileEditDraft(user: try await service.load().user)
        XCTAssertEqual(draft.dateOfBirth, "")
        draft.dateOfBirth = "14-09-1994"
        let saved = try await service.update(draft)
        XCTAssertEqual(saved.user.dateOfBirth.map(ProfileBirthDate.wire), "1994-09-14")
        let fresh = try await makeService()
        let restored = try await fresh.load()
        XCTAssertEqual(ProfileEditDraft(user: restored.user).dateOfBirth, "14-09-1994")
    }
    func testDOBSaveRefetchAndFreshSessionPreserveCanonicalDate() async throws {
        let state = ProfilePatchTestState(data: Self.profilePayload)
        await installStatefulHandler(state)
        let service = try await makeService()
        let original = try await service.load()
        var draft = ProfileEditDraft(user: original.user)
        XCTAssertEqual(draft.dateOfBirth, "25-09-2000", "Existing ISO DOB is decoded and presented, not dropped")
        draft.dateOfBirth = "29-02-2000"
        let saved = try await service.update(draft)
        XCTAssertEqual(saved.user.dateOfBirth.map(ProfileBirthDate.wire), "2000-02-29")
        XCTAssertEqual(saved.user.fullName, original.user.fullName)
        let freshService = try await makeService()
        let restored = try await freshService.load()
        XCTAssertEqual(ProfileEditDraft(user: restored.user).dateOfBirth, "29-02-2000")
        let unchanged = try XCTUnwrap(JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(ProfileEditDraft(user: restored.user).request)) as? [String: Any])
        XCTAssertNil(unchanged["date_of_birth"])
        let requests = await MockURLProtocolStorage.shared.requests()
        let patch = try XCTUnwrap(requests.first { $0.httpMethod == "PATCH" })
        XCTAssertEqual(try requestJSONBody(from: patch)["date_of_birth"] as? String, "2000-02-29")
        draft = ProfileEditDraft(user: restored.user)
        draft.dateOfBirth = ""
        let cleared = try await service.update(draft)
        XCTAssertNil(cleared.user.dateOfBirth, "Existing explicit-null clearing contract remains intact")
    }

    func testDOBInvalidDateNeverSendsMutation() async throws {
        let service = try await makeService()
        var draft = ProfileEditDraft(user: ProfileSnapshot.fixture.user)
        draft.dateOfBirth = "31-04-2000"
        await XCTAssertThrowsErrorAsync { _ = try await service.update(draft) }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.isEmpty)
    }
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
        var draft = ProfileEditDraft(user: ProfileSnapshot.fixture.user)
        draft.headline = "Updated synthetic headline"
        await installStandardHandler { request in
            guard request.url?.path == "/api/v1/users/me", request.httpMethod == "PATCH" else { return }
            let body = try requestJSONBody(from: request)
            XCTAssertNil(body["full_name"], "Unchanged identity fields must not be resent")
            XCTAssertNil(body["phone"])
            XCTAssertNil(body["location_region"])
            XCTAssertNil(body["bio"])
            XCTAssertEqual(body["headline"] as? String, "Updated synthetic headline")
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

    func testClearedProfileFieldsStayClearedAfterRefetchAndFreshService() async throws {
        let state = ProfilePatchTestState(data: Self.profilePayload)
        await installStatefulHandler(state)
        let service = try await makeService()
        var draft = ProfileEditDraft(user: try await service.load().user)
        draft.headline = ""; draft.bio = ""; draft.locationRegion = ""
        let saved = try await service.update(draft)
        XCTAssertNil(saved.user.headline)
        XCTAssertNil(saved.user.bio)
        XCTAssertNil(saved.user.locationRegion)
        let freshService = try await makeService()
        let reopened = ProfileEditDraft(user: try await freshService.load().user)
        XCTAssertEqual(reopened.headline, "")
        XCTAssertEqual(reopened.bio, "")
        XCTAssertEqual(reopened.locationRegion, "")
        XCTAssertTrue(try JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(reopened.request)) as? [String: String] == [:])
    }

    func testLinkLabelUnchangedOmittedThenClearPersistsAcrossFreshService() async throws {
        let state = ProfilePatchTestState(data: Self.profilePayload)
        await installStatefulHandler(state)
        let service = try await makeService()
        _ = try await service.load()
        let url = try XCTUnwrap(URL(string: "https://www.linkedin.com/in/synthetic"))
        _ = try await service.updateLink(id: "link-1", type: .linkedin, label: "LinkedIn", url: url)
        let before = await MockURLProtocolStorage.shared.requests()
        let unchanged = try XCTUnwrap(before.first { $0.httpMethod == "PATCH" })
        XCTAssertNil(try requestJSONBody(from: unchanged)["label"])
        let saved = try await service.updateLink(id: "link-1", type: .linkedin, label: nil, url: url)
        XCTAssertNil(saved.user.professionalLinks.first?.label)
        let freshService = try await makeService()
        let fresh = try await freshService.load()
        XCTAssertNil(fresh.user.professionalLinks.first?.label)
        let requests = await MockURLProtocolStorage.shared.requests()
        let clear = try XCTUnwrap(requests.last { $0.httpMethod == "PATCH" })
        XCTAssertTrue(try requestJSONBody(from: clear)["label"] is NSNull)
    }

    private func installStatefulHandler(_ state: ProfilePatchTestState) async {
        await MockURLProtocolStorage.shared.setHandler { request in
            let response = try Self.response(for: request, statusCode: 200)
            if request.httpMethod == "PATCH" {
                try await state.apply(body: requestBodyData(from: request), link: request.url?.path.hasSuffix("/links/link-1") == true)
                return (response, Data("{}".utf8))
            }
            return (response, request.url?.path == "/api/v1/skills" ? Self.skillsPayload : await state.data())
        }
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
        let photoURL = "https://storage.example/saved-profile-photo"
        await installStandardHandler(avatarURL: photoURL) { request in
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

        let snapshot = try await service.uploadAvatar(jpegData: Data(repeating: 0x01, count: 1024))
        XCTAssertEqual(snapshot.user.avatarURL, photoURL, "The post-upload refetch must retain the returned photo URL")
        let reopened = try await service.load()
        XCTAssertEqual(reopened.user.avatarURL, photoURL, "Reload must not require another upload or login")
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
        avatarURL: String? = nil,
        assertion: (@Sendable (URLRequest) throws -> Void)? = nil
    ) async {
        await MockURLProtocolStorage.shared.setHandler { request in
            try assertion?(request)
            let response = try Self.response(for: request, statusCode: request.httpMethod == "DELETE" ? 204 : 200)
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("GET", _, "/api/v1/users/me"):
                var profile = try JSONSerialization.jsonObject(with: Self.profilePayload) as! [String: Any]
                profile["avatar_url"] = avatarURL as Any? ?? NSNull()
                return (response, try JSONSerialization.data(withJSONObject: profile))
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

private actor ProfilePatchTestState {
    private var payload: Data
    init(data: Data) { payload = data }
    func data() -> Data { payload }
    func apply(body: Data, link: Bool) throws {
        var profile = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let changes = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        if link {
            var links = try XCTUnwrap(profile["professional_links"] as? [[String: Any]])
            for (key, value) in changes { links[0][key] = value }
            profile["professional_links"] = links
        } else {
            for (key, value) in changes { profile[key] = value }
        }
        payload = try JSONSerialization.data(withJSONObject: profile)
    }
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
