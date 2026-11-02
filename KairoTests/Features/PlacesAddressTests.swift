import XCTest
import GooglePlacesSwift
@testable import Kairo

@MainActor final class PlacesAddressTests: XCTestCase {
    private var address: ClaimedPermanentAddress {
        .init(addressLine1: "10 Example Road", city: "Bengaluru", state: "Karnataka", postalCode: "560001")
    }
    func testMissingPlaceholderAndInvalidKeyAreUnavailable() {
        for value in ["", "$(GOOGLE_PLACES_API_KEY)", "YOUR_API_KEY", "not-a-key"] {
            XCTAssertNil(PlacesBootstrap.configuredKey(bundle: ["GOOGLE_PLACES_API_KEY": value]))
        }
        XCTAssertNil(PlacesBootstrap.configuredKey(bundle: [:]))
        let synthetic = "AIza" + String(repeating: "x", count: 35)
        XCTAssertEqual(PlacesBootstrap.configuredKey(bundle: ["GOOGLE_PLACES_API_KEY": synthetic]), synthetic)
    }
    func testProductionCredentialNeverEnablesStagingDemoOrNetworkBlockedQA() {
        for build in [AppBuildConfiguration.development, .staging, .production] {
            for demo in [false, true] {
                for localQA in [false, true] {
                    let config = AppConfiguration(buildConfiguration: build, environment: .production,
                        isDemoModeEnabled: demo, apiBaseURL: APIConfiguration.baseURL(for: .production), keychainService: "synthetic")
                    XCTAssertEqual(PlacesBootstrap.permitsSearch(configuration: config, localQA: localQA),
                                   build == .production && !demo && !localQA)
                }
            }
        }
    }
    func testAutocompleteSelectionMapsStructuredAddressWithoutCoordinates() throws {
        let result = try XCTUnwrap(PlacesAddressSelection.map(placeID: "synthetic-place-id", components: [
            .init(types: [.country], name: "India", shortName: "IN"),
            .init(types: [.streetNumber], name: "10"), .init(types: [.route], name: "Example Road"),
            .init(types: [.locality], name: "Bengaluru"), .init(types: [.administrativeAreaLevel1], name: "Karnataka"),
            .init(types: [.postalCode], name: "560001")
        ]))
        XCTAssertEqual(result.address, address)
        XCTAssertEqual(result.placeID(for: address), "synthetic-place-id")
        var edited = address; edited.addressLine1 = "20 Other Road"
        XCTAssertNil(result.placeID(for: edited))
    }
    func testRejectsInvalidSelectionAndNonIndiaCountry() {
        XCTAssertNil(PlacesAddressSelection.map(placeID: "", components: []))
        XCTAssertNil(PlacesAddressSelection.map(placeID: "invalid\nplace", components: []))
        XCTAssertNil(PlacesAddressSelection.map(placeID: "synthetic", components: [.init(types: [.country], name: "USA", shortName: "US")]))
    }
    func testFormattedAddressPreservesCompleteResultWhenStreetComponentsAreMissing() throws {
        let result = try XCTUnwrap(PlacesAddressSelection.map(
            placeID: "synthetic-place-id",
            formattedAddress: "  Building 4, Example Campus, Sector 7, Bengaluru, Karnataka 560001, India  ",
            components: [
                .init(types: [.country], name: "India", shortName: "IN"),
                .init(types: [.sublocalityLevel1], name: "Sector 7"),
                .init(types: [.locality], name: "Bengaluru"),
                .init(types: [.administrativeAreaLevel1], name: "Karnataka"),
                .init(types: [.postalCode], name: "560001")
            ]
        ))
        XCTAssertEqual(result.address.addressLine1,
                       "Building 4, Example Campus, Sector 7, Bengaluru, Karnataka 560001, India")
        XCTAssertEqual(result.address.locality, "Sector 7")
        XCTAssertEqual(result.address.city, "Bengaluru")
        XCTAssertEqual(result.address.state, "Karnataka")
        XCTAssertEqual(result.address.postalCode, "560001")
    }
    func testManualSaveOmitsPlaceIDAndSelectionAddsOnlyPlaceID() throws {
        let manual = try payload(nil)
        let selected = try payload("synthetic-place-id")
        XCTAssertNil(manual["google_place_id"])
        XCTAssertEqual(selected["google_place_id"] as? String, "synthetic-place-id")
        XCTAssertEqual(selected["address_line_1"] as? String, address.addressLine1)
        XCTAssertEqual(Set(selected.keys), Set(manual.keys).union(["google_place_id"]))
        for key in ["latitude", "longitude", "lat", "lng", "coordinates", "target_latitude", "target_longitude"] {
            XCTAssertNil(selected[key]); XCTAssertNil(manual[key])
        }
    }
    func testDrivingLicenceHandoffIsTransientDraftOnly() {
        let handoff = DigiLockerAddressHandoffStore()
        handoff.prepare(.prefill("Synthetic licence address"))
        XCTAssertEqual(handoff.consume(), .prefill("Synthetic licence address"))
        XCTAssertNil(handoff.consume())
        handoff.prepare(.structured(address)); handoff.clear()
        XCTAssertNil(handoff.consume())
    }
    func testPlaceIDUsesPrivateNonReplayableAuthoritativePut() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("synthetic-access", for: .accessToken)
        let network = PlacesSaveNetwork()
        let session = SessionService(configuration: .init(buildConfiguration: .production, environment: .production,
            isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .production), keychainService: "synthetic"),
            networkClient: network, tokenStore: tokens)
        let service = PermanentAddressService(session: session, enabled: true)
        _ = try await service.save(address, googlePlaceID: "synthetic-place-id")
        let request = try XCTUnwrap(network.requests.first)
        XCTAssertEqual(request.path, "/permanent-address"); XCTAssertEqual(request.method, .put)
        XCTAssertTrue(request.requiresPrivateJSONTransport)
        XCTAssertFalse(request.allowsSessionRefreshOnUnauthorized)
        let body = try XCTUnwrap(request.body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["google_place_id"] as? String, "synthetic-place-id")
        do {
            _ = try await service.save(address, googlePlaceID: "invalid\nvalue")
            XCTFail("Invalid ID must be rejected before transport")
        } catch {}
        XCTAssertEqual(network.requests.count, 1)
    }
    private func payload(_ placeID: String?) throws -> [String: Any] {
        let data = try APIJSONCoder.makeEncoder().encode(PermanentAddressSaveRequest(address: address, googlePlaceID: placeID))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

@MainActor private final class PlacesSaveNetwork: NetworkClient {
    var requests: [NetworkRequest] = []
    func send(_ request: NetworkRequest) async throws -> Data {
        requests.append(request)
        return Data(#"{"enabled":true,"status":"DOCUMENT_REQUIRED"}"#.utf8)
    }
}
