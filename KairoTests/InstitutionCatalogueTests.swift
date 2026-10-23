import XCTest
@testable import Kairo

@MainActor
final class InstitutionCatalogueTests: XCTestCase {
    func testPublicSearchContractAndBoundedParameters() async throws {
        let network = CatalogueNetwork()
        let client = InstitutionCatalogueClient(network: network)
        let result = try await client.search("  Synthetic  ", state: "State", district: "District", page: 2, limit: 500)
        let capturedRequest = network.lastRequest()
        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.path, "/catalogues/institutions")
        let urlRequest = try URLSessionNetworkClient(baseURL: URL(string: "https://api.kairoid.com/api/v1")!, session: .shared).makeURLRequest(for: request)
        XCTAssertEqual(urlRequest.url?.path, "/api/v1/catalogues/institutions")
        XCTAssertEqual(request.method, .get)
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertNil(request.body)
        let query = Dictionary(uniqueKeysWithValues: request.queryItems.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query, ["search": "Synthetic", "state": "State", "district": "District", "page": "2", "limit": "50"])
        XCTAssertEqual(result.version, "test-v1")
        XCTAssertEqual(result.items[0].location, "City, District, State")
        XCTAssertEqual(result.provenance.licenceName, "Fixture licence")
        XCTAssertEqual(result.total, 1)
        XCTAssertTrue(result.manualEntryAllowed)
    }

    func testSelectedCareerCreateAndReadbackCarryLinkage() throws {
        var draft = CareerEducationDraft()
        draft.selectInstitution(.init(name: "Synthetic Institute", catalogueID: "catalogue-1", catalogueVersion: "test-v1"))
        let json = try object(draft.createRequest())
        XCTAssertEqual(json["institution_name"] as? String, "Synthetic Institute")
        XCTAssertEqual(json["institution_catalogue_id"] as? String, "catalogue-1")
        XCTAssertEqual(json["institution_catalogue_version"] as? String, "test-v1")
        let restored = CareerEducationDraft(record: try record(linked: true))
        XCTAssertEqual(restored.institutionCatalogueID, "catalogue-1")
        XCTAssertEqual(restored.institutionCatalogueVersion, "test-v1")
        let unchanged = try object(restored.updateRequest())
        XCTAssertNil(unchanged["institution_catalogue_id"])
        XCTAssertNil(unchanged["institution_catalogue_version"])
    }

    func testManualCreateEncodesNullNotEmptyStrings() throws {
        var draft = CareerEducationDraft()
        draft.selectInstitution(.init(name: "Unlisted historical institution"))
        let json = try object(draft.createRequest())
        XCTAssertTrue(json["institution_catalogue_id"] is NSNull)
        XCTAssertTrue(json["institution_catalogue_version"] is NSNull)
    }

    func testManualRenameClearsSelectedLinkageWithoutChangingOtherFields() throws {
        var draft = CareerEducationDraft(record: try record(linked: true))
        draft.institutionName = "Historical renamed institution"
        let json = try object(draft.updateRequest())
        XCTAssertTrue(json["institution_catalogue_id"] is NSNull)
        XCTAssertTrue(json["institution_catalogue_version"] is NSNull)
        XCTAssertEqual(json["institution_name"] as? String, "Historical renamed institution")
        XCTAssertNil(json["degree"])
        XCTAssertNil(json["field_of_study"])
    }

    func testExplicitManualSameNameStillClearsLinkage() throws {
        var draft = CareerEducationDraft(record: try record(linked: true))
        draft.selectInstitution(.init(name: draft.institutionName))
        let json = try object(draft.updateRequest())
        XCTAssertTrue(json["institution_catalogue_id"] is NSNull)
        XCTAssertTrue(json["institution_catalogue_version"] is NSNull)
    }

    func testLegacyNamePreservedAndUnrelatedSaveDoesNotLink() throws {
        let draft = CareerEducationDraft(record: try record(linked: false))
        XCTAssertEqual(draft.institutionName, "Historical custom institution")
        let json = try object(draft.updateRequest())
        XCTAssertNil(json["institution_name"])
        XCTAssertNil(json["institution_catalogue_id"])
        XCTAssertNil(json["institution_catalogue_version"])
    }

    func testReSelectingCatalogueReplacesBothLinkageValues() throws {
        var draft = CareerEducationDraft(record: try record(linked: true))
        draft.selectInstitution(.init(name: "New institution", catalogueID: "catalogue-2", catalogueVersion: "test-v2"))
        let json = try object(draft.updateRequest())
        XCTAssertEqual(json["institution_catalogue_id"] as? String, "catalogue-2")
        XCTAssertEqual(json["institution_catalogue_version"] as? String, "test-v2")
    }

    func testDebounceDoesNotSendBeforeReadinessAndCancelledQueryNeverSends() async {
        let network = CatalogueNetwork()
        let state = InstitutionSearchState(service: InstitutionCatalogueClient(network: network))
        let gate = CatalogueDebounceGate()
        let first = Task { await state.load("old", debounce: { await gate.wait() }) }
        await gate.waitUntilStarted()
        let initialCount = network.count()
        XCTAssertEqual(initialCount, 0)
        XCTAssertTrue(state.isLoading)
        first.cancel()
        await state.load("new", debounce: {})
        await gate.release()
        await first.value
        let count = network.count()
        XCTAssertEqual(count, 1)
        let request = network.lastRequest()
        XCTAssertEqual(request?.queryItems.first(where: { $0.name == "search" })?.value, "new")
        XCTAssertNotNil(state.result)
        XCTAssertFalse(state.failed)
    }

    func testEmptyUnavailableAndFailureStateAreDistinct() async throws {
        for mode in ["empty", "unavailable", "failure"] {
            let state = InstitutionSearchState(service: InstitutionCatalogueClient(network: CatalogueNetwork(mode: mode)))
            await state.load("query", debounce: {})
            XCTAssertFalse(state.isLoading)
            if mode == "failure" { XCTAssertTrue(state.failed); XCTAssertNil(state.result) }
            else {
                XCTAssertFalse(state.failed)
                XCTAssertEqual(state.result?.available, mode != "unavailable")
                XCTAssertEqual(state.result?.items, [])
                XCTAssertEqual(state.result?.manualEntryAllowed, true)
            }
        }
    }

    func testManualOnboardingRenameAndCodableLegacyRestore() throws {
        var entry = ManualEducationEntry.blank(id: 0)
        entry.selectInstitution(.init(name: "Selected", catalogueID: "catalogue-1", catalogueVersion: "test-v1"))
        let restored = try JSONDecoder().decode(ManualEducationEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(restored, entry)
        entry.institution = "Custom"
        XCTAssertNil(entry.institutionCatalogueID)
        XCTAssertNil(entry.institutionCatalogueVersion)
        var old = try object(entry)
        old.removeValue(forKey: "institution_catalogue_id")
        old.removeValue(forKey: "institution_catalogue_version")
        let legacy = try APIJSONCoder.makeDecoder().decode(ManualEducationEntry.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertEqual(legacy.institution, "Custom")
        XCTAssertNil(legacy.institutionCatalogueID)
    }

    func testFourTabNavigationRemainsUnchanged() {
        XCTAssertEqual(CandidateTab.allCases, [.home, .career, .passport, .more])
    }

    private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(value)) as? [String: Any])
    }
    private func record(linked: Bool) throws -> CareerEducationRecord {
        var json: [String: Any] = ["id": "education-1", "institution_name": "Historical custom institution", "degree": "BSc", "is_currently_studying": false, "verification_status": "draft"]
        if linked { json["institution_catalogue_id"] = "catalogue-1"; json["institution_catalogue_version"] = "test-v1" }
        return CareerEducationRecord(dto: try APIJSONCoder.makeDecoder().decode(CareerEducationDTO.self, from: JSONSerialization.data(withJSONObject: json)))
    }
}

private actor CatalogueDebounceGate {
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async { await withCheckedContinuation { continuation = $0 } }
    func waitUntilStarted() async { while continuation == nil { await Task.yield() } }
    func release() { continuation?.resume(); continuation = nil }
}

@MainActor
private final class CatalogueNetwork: NetworkClient {
    private var requests: [NetworkRequest] = []
    let mode: String
    init(mode: String = "results") { self.mode = mode }
    func lastRequest() -> NetworkRequest? { requests.last }
    func count() -> Int { requests.count }
    func send(_ request: NetworkRequest) async throws -> Data {
        requests.append(request)
        if mode == "failure" { throw NetworkError.invalidResponse }
        let items: [[String: String]] = mode == "results" ? [["id": "catalogue-1", "name": "Synthetic Institute", "city": "City", "district": "District", "state": "State"]] : []
        return try JSONSerialization.data(withJSONObject: [
            "version": "test-v1", "scope": "Synthetic", "available": mode != "unavailable", "manual_entry_allowed": true,
            "fallback_label": "Institution not listed / Enter manually", "items": items, "total": items.count, "limit": 25, "offset": 0, "page": 1,
            "provenance": ["source_name": "Fixture source", "source_url": "https://example.com/source", "licence_name": "Fixture licence", "licence_url": "https://example.com/licence", "attribution": "Fixture attribution", "non_endorsement": "Fixture only"]
        ])
    }
}
