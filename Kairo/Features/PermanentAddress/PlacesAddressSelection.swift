import Foundation
import GooglePlacesSwift

@MainActor
enum PlacesBootstrap {
    private(set) static var isReady = false
    private static var attempted = false

    static func configure(configuration: AppConfiguration, bundle: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        guard !attempted else { return }
        attempted = true
        // Only the Production plist receives the Production credential.
        guard permitsSearch(configuration: configuration, localQA: LocalBatch1QA.isEnabled(configuration: configuration)),
              let key = configuredKey(bundle: bundle) else { return }
        isReady = PlacesClient.provideAPIKey(key)
    }

    static func permitsSearch(configuration: AppConfiguration, localQA: Bool) -> Bool {
        configuration.buildConfiguration == .production && configuration.environment == .production
            && !configuration.isDemoModeEnabled && !localQA
    }

    static func configuredKey(bundle: [String: Any]) -> String? {
        guard let value = bundle["GOOGLE_PLACES_API_KEY"] as? String else { return nil }
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("AIza"), key.count == 39,
              key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else { return nil }
        return key
    }
}

// Deliberately not Codable: the place ID lives only in the open editor/save request.
nonisolated struct PlacesAddressSelection: Equatable, Sendable {
    let placeID: String
    let address: ClaimedPermanentAddress

    func placeID(for draft: ClaimedPermanentAddress) -> String? {
        draft == address ? placeID : nil
    }

    static func map(placeID: String, components: [AddressComponent]) -> PlacesAddressSelection? {
        guard validPlaceID(placeID) else { return nil }
        func component(_ type: PlaceType, short: Bool = false) -> String {
            guard let value = components.first(where: { $0.types.contains(type) }) else { return "" }
            return (short ? value.shortName ?? value.name : value.name).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard component(.country, short: true) == "IN" else { return nil }
        let street = [component(.streetNumber), component(.route)].filter { !$0.isEmpty }.joined(separator: " ")
        let line1 = [component(.premise), street].filter { !$0.isEmpty }.joined(separator: ", ")
        let locality = [component(.sublocalityLevel1), component(.sublocality)].first { !$0.isEmpty }
        let city = [component(.locality), component(.administrativeAreaLevel3), component(.administrativeAreaLevel2)].first { !$0.isEmpty } ?? ""
        let address = ClaimedPermanentAddress(addressLine1: line1.isEmpty ? locality ?? "" : line1,
            locality: locality, city: city, state: component(.administrativeAreaLevel1),
            postalCode: component(.postalCode), country: "IN")
        return PlacesAddressSelection(placeID: placeID, address: address)
    }

    static func validPlaceID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 255 && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }
}

nonisolated struct PermanentAddressSaveRequest: Encodable, Sendable {
    let address: ClaimedPermanentAddress
    let googlePlaceID: String?
    private enum CodingKeys: String, CodingKey { case googlePlaceID = "google_place_id" }
    func encode(to encoder: Encoder) throws {
        try address.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(googlePlaceID, forKey: .googlePlaceID)
    }
}
