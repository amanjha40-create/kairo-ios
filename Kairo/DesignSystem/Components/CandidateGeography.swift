import Foundation

/// Pinned offline data. Never contacts a geocoder, provider, or location service.
nonisolated struct CandidateGeography: Decodable, Sendable {
    struct Region: Decodable, Sendable {
        let name: String
        let cities: [String]
    }
    let regions: [Region]
    let cities: [String]
    static let empty = CandidateGeography(regions: [], cities: [])
    static let countries: [String: String] = load("Countries", as: [String: String].self) ?? [:]

    static func countryCode(_ value: String) -> String? {
        let code = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if countries[code] != nil { return code }
        return countries.first { $0.value.caseInsensitiveCompare(value) == .orderedSame ||
            CandidateLocationCatalogue.countryName($0.key).caseInsensitiveCompare(value) == .orderedSame }?.key
    }
    static func country(_ value: String) -> Self {
        guard let code = countryCode(value) else { return .empty }
        return load(code, as: Self.self) ?? .empty
    }
    func cities(in region: String) -> [String] {
        if regions.isEmpty { return cities }
        return regions.first { $0.name == region }?.cities ?? []
    }
    private static func load<T: Decodable>(_ suffix: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: "Geography-" + suffix, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
