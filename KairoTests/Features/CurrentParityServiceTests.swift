import Foundation
import XCTest
@testable import Kairo

@MainActor private final class ParityContractNetwork: NetworkClient {
    var requests: [NetworkRequest] = []
    var unauthorized = false
    func reject() { unauthorized = true }
    func send(_ request: NetworkRequest) async throws -> Data {
        requests.append(request)
        if unauthorized { throw NetworkError.api(.init(statusCode: 401, code: .unauthorized, message: "Synthetic rejection", fieldErrors: [:], globalErrors: [], validationDetails: [])) }
        if request.path.contains("references") {
            return Data("{\"employment_id\":\"\(CurrentParityFixtures.employmentID)\",\"completed_count\":0,\"total_count\":2,\"hr_reference\":{\"status\":\"pending\"},\"reporting_manager\":{\"status\":\"awaiting_hr_validation\"}}".utf8)
        }
        if request.path.hasSuffix("document-types") {
            return Data(#"{"items":[{"value":"voter_id","label":"Voter ID","max_age_days":null}],"allowed_content_types":["application/pdf"],"max_bytes":10485760}"#.utf8)
        }
        if request.path.hasSuffix("upload-intent") {
            return Data("{\"document_id\":\"\(CurrentParityFixtures.documentID)\",\"upload_url\":\"https://storage.example/synthetic-upload\",\"headers_required\":{\"Content-Type\":\"application/pdf\"}}".utf8)
        }
        if request.path.hasSuffix("complete-upload") || request.path.hasSuffix("/document") {
            return Data("{\"document_id\":\"\(CurrentParityFixtures.documentID)\",\"document_type\":\"voter_id\",\"status\":\"UPLOADED\"}".utf8)
        }
        if request.path.hasSuffix("/sessions") {
            return Data("{\"session_id\":\"\(CurrentParityFixtures.documentID)\",\"challenge\":\"synthetic\",\"expires_at\":\"2099-01-01T00:00:00Z\",\"minimum_duration_seconds\":30,\"maximum_duration_seconds\":60,\"minimum_samples\":5,\"maximum_samples\":10}".utf8)
        }
        return Data("{\"enabled\":true,\"status\":\"NEEDS_REVIEW\",\"address_version_id\":\"\(CurrentParityFixtures.version)\",\"successful_gps_checks\":0,\"required_gps_checks\":3}".utf8)
    }
}

@MainActor final class CurrentParityServiceTests: XCTestCase {
    override func tearDown() async throws { await MockURLProtocolStorage.shared.reset(); try await super.tearDown() }
    private func session(_ network: ParityContractNetwork) async throws -> SessionService {
        let tokens = InMemoryTokenStore()
        try await tokens.save("synthetic-access", for: .accessToken)
        try await tokens.save("synthetic-refresh", for: .refreshToken)
        return SessionService(configuration: .init(buildConfiguration: .staging, environment: .staging, isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging), keychainService: "synthetic"), networkClient: network, tokenStore: tokens)
    }
    func testReferencesReadNominationAndChangeUseOnlyCanonicalCandidatePaths() async throws {
        let network = ParityContractNetwork()
        let service = EmploymentReferencesService(session: try await session(network))
        _ = try await service.load(employmentID: CurrentParityFixtures.employmentID)
        let input = ManagerNominationInput(fullName: " Synthetic ", designation: " Lead ", workEmail: "qa@example.invalid")
        _ = try await service.save(employmentID: CurrentParityFixtures.employmentID, input: input, change: false)
        _ = try await service.save(employmentID: CurrentParityFixtures.employmentID, input: input, change: true)
        let requests = network.requests
        XCTAssertEqual(requests.map(\.method), [.get, .put, .post])
        XCTAssertEqual(requests.map(\.path), ["", "/reporting-manager", "/reporting-manager/change"].map { "/employments/\(CurrentParityFixtures.employmentID)/references" + $0 })
        XCTAssertTrue(requests.allSatisfy { $0.requiresPrivateJSONTransport && $0.headers["Cache-Control"] == "no-store" })
        XCTAssertFalse(requests.dropFirst().contains { $0.allowsSessionRefreshOnUnauthorized })
        XCTAssertFalse(requests.contains { $0.path.contains("invite") || $0.path.contains("send") })
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[1].body)) as? [String: Any])
        XCTAssertEqual(body["full_name"] as? String, "Synthetic"); XCTAssertEqual(body["designation"] as? String, "Lead")
    }
    func testReference401DoesNotReplayNominationOrDispatchInvitation() async throws {
        let network = ParityContractNetwork()
        let service = EmploymentReferencesService(session: try await session(network))
        network.reject()
        do { _ = try await service.save(employmentID: CurrentParityFixtures.employmentID, input: .init(fullName: "QA", designation: "Lead", workEmail: "qa@example.invalid"), change: false); XCTFail() } catch {}
        let requests = network.requests
        XCTAssertEqual(requests.count, 1); XCTAssertEqual(requests.first?.method, .put)
    }
    func testInvalidReferenceScopeRejectedBeforeNetwork() async throws {
        let network = ParityContractNetwork(), service = EmploymentReferencesService(session: try await session(network))
        do { _ = try await service.load(employmentID: "../../admin"); XCTFail() } catch { XCTAssertEqual(error as? NetworkError, .invalidURL) }
        let requests = network.requests; XCTAssertTrue(requests.isEmpty)
    }
    func testAddressSecureUploadCompletesExactlyOnceWithoutAutoSubmitOrAuthLeak() async throws {
        let network = ParityContractNetwork()
        let service = PermanentAddressService(session: try await session(network), enabled: true, transfer: .init(session: makeMockedURLSession()))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("address-synthetic-\(UUID()).pdf")
        try Data("%PDF-synthetic-qa-only".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.host, "storage.example"); XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization")); XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            return (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)), Data())
        }
        let result = try await service.upload(version: CurrentParityFixtures.version, type: "voter_id", file: file, issued: nil)
        XCTAssertEqual(result.status, "UPLOADED")
        let requests = network.requests, storage = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(storage.count, 1)
        XCTAssertEqual(requests.map(\.path), ["/permanent-address/document-types", "/permanent-address/documents/upload-intent", "/permanent-address/documents/\(CurrentParityFixtures.documentID)/complete-upload"])
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests.last?.body)) as? [String: String])
        XCTAssertEqual(body["address_version_id"], CurrentParityFixtures.version); XCTAssertEqual(body["checksum_sha256"]?.count, 64)
        XCTAssertTrue(requests.allSatisfy(\.requiresPrivateJSONTransport))
    }
    func testDocumentSubmitBindsExactVersionAndExplicitConfirmation() async throws {
        let network = ParityContractNetwork(), service = PermanentAddressService(session: try await session(network), enabled: true)
        _ = try await service.submit(version: CurrentParityFixtures.version, document: CurrentParityFixtures.documentID)
        let requests = network.requests
        XCTAssertEqual(requests.count, 1); XCTAssertFalse(requests[0].allowsSessionRefreshOnUnauthorized)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].body)) as? [String: Any])
        XCTAssertEqual(body["confirms_current_address"] as? Bool, true)
        XCTAssertEqual(body["address_version_id"] as? String, CurrentParityFixtures.version)
        XCTAssertEqual(body["document_id"] as? String, CurrentParityFixtures.documentID)
    }
    func testLocationChallengeAndCancellationUseExactVersionAndNoRetry() async throws {
        let network = ParityContractNetwork(), service = PermanentAddressService(session: try await session(network), enabled: true)
        let challenge = try await service.start(version: CurrentParityFixtures.version)
        XCTAssertTrue(challenge.supported)
        try await service.cancel(challenge)
        let requests = network.requests
        XCTAssertEqual(requests.count, 2); XCTAssertTrue(requests.allSatisfy { !$0.allowsSessionRefreshOnUnauthorized && $0.requiresPrivateJSONTransport })
        XCTAssertEqual(requests[1].path, "/permanent-address/sessions/\(CurrentParityFixtures.documentID)/cancel")
    }
    func testDisabledServiceCannotSendNetworkRequests() async throws {
        let network = ParityContractNetwork(), service = PermanentAddressService(session: try await session(network), enabled: false)
        do { _ = try await service.state(); XCTFail() } catch { XCTAssertEqual(error as? NetworkError, .unavailableInDemoMode) }
        let requests = network.requests; XCTAssertTrue(requests.isEmpty)
    }
}
