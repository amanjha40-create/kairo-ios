import Foundation

nonisolated struct ClaimedPermanentAddress: Codable, Equatable, Sendable {
    var addressLine1 = ""
    var addressLine2: String? = nil
    var locality: String? = nil
    var city = ""
    var state = ""
    var postalCode = ""
    var country = "IN"
    private enum EncodingKeys: String, CodingKey {
        case addressLine1 = "address_line_1", addressLine2 = "address_line_2"
        case locality, city, state, postalCode = "postal_code", country
    }
    // convertToSnakeCase alone produces address_line1, not the API's address_line_1.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKeys.self)
        try container.encode(addressLine1, forKey: .addressLine1)
        try container.encodeIfPresent(addressLine2, forKey: .addressLine2)
        try container.encodeIfPresent(locality, forKey: .locality)
        try container.encode(city, forKey: .city)
        try container.encode(state, forKey: .state)
        try container.encode(postalCode, forKey: .postalCode)
        try container.encode(country, forKey: .country)
    }
    var isValid: Bool {
        country == "IN" && (3...160).contains(addressLine1.trimmingCharacters(in: .whitespacesAndNewlines).count)
        && (addressLine2?.count ?? 0) <= 160 && (locality?.count ?? 0) <= 100
        && (1...100).contains(city.trimmingCharacters(in: .whitespacesAndNewlines).count)
        && (1...100).contains(state.trimmingCharacters(in: .whitespacesAndNewlines).count)
        && postalCode.range(of: #"^[1-9][0-9]{5}$"#, options: .regularExpression) != nil
        && ![addressLine1, addressLine2 ?? "", locality ?? "", city, state].joined().unicodeScalars.contains(where: { $0.value < 32 })
    }
    var display: String { [addressLine1, addressLine2, locality, city, state, postalCode, "India"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") }
}
// No target coordinates, geocoder diagnostics, risk fields or reviewer identity.
nonisolated struct PermanentAddressState: Codable, Equatable, Sendable {
    let enabled: Bool
    let status: String
    var addressVersionId: String?
    var claimedAddress: ClaimedPermanentAddress?
    var documentStatus: String?
    var geocodeStatus: String?
    var targetConfirmationRequired: Bool?
    var targetSource: String?
    var successfulGpsChecks: Int?
    var requiredGpsChecks: Int?
    var todayComplete: Bool?
    var canStartLocation: Bool?
    var lastLocationResult: String?
    var expiresAt: Date?
    var isVerified: Bool { status == "PERMANENT_ADDRESS_VERIFIED" }
    var progress: String { "\(successfulGpsChecks ?? 0) of \(requiredGpsChecks ?? 3) completed" }
    var label: String {
        ["NOT_STARTED":"Not started", "DOCUMENT_REQUIRED":"Address document required", "DOCUMENT_UNDER_REVIEW":"Address document under review",
         "LOCATION_CHECK_REQUIRED":"Location checks required", "LOCATION_CHECK_IN_PROGRESS":"Location check in progress",
         "LOCATION_CONFIRMED":"Location confirmed", "NEEDS_REVIEW":"Needs review", "PERMANENT_ADDRESS_VERIFIED":"Permanent Address Verified"][status] ?? "Status unavailable"
    }
}
nonisolated struct AddressDocumentState: Codable, Equatable, Sendable {
    var documentId: String?
    var documentType: String?
    var status: String
    var issuedOn: String?
    var approved: Bool { ["MATCH", "APPROVED_MATCHING"].contains(status) }
    var label: String {
        ["REQUIRED":"Required", "UPLOADING":"Upload not completed", "UPLOADED":"Ready to submit", "UNDER_REVIEW":"Under review",
         "NEEDS_REVIEW":"Under review", "MATCH":"Approved", "APPROVED_MATCHING":"Approved", "REJECTED":"Rejected",
         "NEEDS_CORRECTION":"Needs correction", "MISMATCH":"Needs correction", "SUPERSEDED":"Replaced"][status] ?? "Status unavailable"
    }
}
nonisolated struct AddressDocumentPolicy: Decodable, Sendable {
    struct Item: Decodable, Identifiable, Sendable {
        let value: String
        let label: String
        let maxAgeDays: Int?
        var id: String { value }
    }
    let items: [Item]
    let allowedContentTypes: [String]
    let maxBytes: Int
}
nonisolated struct AddressLocationChallenge: Decodable, Sendable {
    let sessionId: String
    let challenge: String
    let expiresAt: Date
    let minimumDurationSeconds: Int
    let maximumDurationSeconds: Int
    let minimumSamples: Int
    let maximumSamples: Int
    var supported: Bool { minimumDurationSeconds == 30 && maximumDurationSeconds == 60 && minimumSamples == 5 && maximumSamples == 10 }
}
nonisolated struct AddressLocationSample: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
    let accuracyM: Double
    let timestamp: String
    let mockLocation: Bool
}
