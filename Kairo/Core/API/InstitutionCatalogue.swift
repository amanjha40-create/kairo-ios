import Foundation
import Combine

nonisolated struct InstitutionSelection: Equatable, Sendable {
    let name: String
    var catalogueID: String? = nil
    var catalogueVersion: String? = nil
}

nonisolated struct InstitutionCataloguePage: Decodable, Equatable, Sendable {
    struct Item: Decodable, Equatable, Identifiable, Sendable {
        let id: String
        let name: String
        let state: String?
        let district: String?
        let city: String?
        var location: String { [city, district, state].compactMap { $0 }.filter { !$0.isEmpty }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: ", ") }
    }
    struct Provenance: Decodable, Equatable, Sendable {
        let sourceName: String
        let sourceUrl: String
        let licenceName: String
        let licenceUrl: String
        let attribution: String
        let nonEndorsement: String
    }
    let version: String
    let scope: String
    let available: Bool
    let manualEntryAllowed: Bool
    let fallbackLabel: String
    let provenance: Provenance
    let items: [Item]
    let total: Int
    let limit: Int
    let offset: Int
    let page: Int
}

protocol InstitutionCatalogueServing: Sendable {
    func search(_ query: String, state: String?, district: String?, page: Int, limit: Int) async throws -> InstitutionCataloguePage
}

struct InstitutionCatalogueClient: InstitutionCatalogueServing {
    let network: any NetworkClient

    func search(_ query: String, state: String? = nil, district: String? = nil, page: Int = 1, limit: Int = 25) async throws -> InstitutionCataloguePage {
        var parameters = [URLQueryItem(name: "page", value: String(max(1, page))),
                          URLQueryItem(name: "limit", value: String(min(50, max(1, limit))))]
        for (key, value) in [("search", Optional(query)), ("state", state), ("district", district)] {
            if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                parameters.append(URLQueryItem(name: key, value: value))
            }
        }
        let data = try await network.send(NetworkRequest(path: "/catalogues/institutions", queryItems: parameters))
        return try APIJSONCoder.makeDecoder().decode(InstitutionCataloguePage.self, from: data)
    }

    static func make(configuration: AppConfiguration) -> any InstitutionCatalogueServing {
        #if !KAIRO_PRODUCTION
        if UITestLaunchConfiguration.current().validated(for: configuration).isEnabled {
            return InstitutionCatalogueFixture(mode: ProcessInfo.processInfo.environment["KAIRO_UI_TEST_INSTITUTION_MODE"] ?? "results")
        }
        #endif
        if configuration.isDemoModeEnabled { return UnavailableInstitutionCatalogue() }
        return InstitutionCatalogueClient(network: URLSessionNetworkClient(baseURL: configuration.apiBaseURL, session: .shared))
    }
}

private struct UnavailableInstitutionCatalogue: InstitutionCatalogueServing {
    func search(_ query: String, state: String?, district: String?, page: Int, limit: Int) async throws -> InstitutionCataloguePage {
        throw NetworkError.unavailableInDemoMode
    }
}

@MainActor
final class InstitutionSearchState: ObservableObject {
    @Published private(set) var result: InstitutionCataloguePage?
    @Published private(set) var isLoading = false
    @Published private(set) var failed = false
    private let service: any InstitutionCatalogueServing
    private var generation = 0
    init(service: any InstitutionCatalogueServing) { self.service = service }

    // Called from SwiftUI's query-keyed task: replacement queries cancel the debounce.
    // Generation also rejects a transport which returns after cancellation.
    func load(_ query: String, page: Int = 1,
              debounce: @Sendable () async throws -> Void = { try await Task.sleep(for: .milliseconds(300)) }) async {
        generation += 1
        let request = generation
        result = nil; failed = false; isLoading = true
        defer { if request == generation { isLoading = false } }
        do {
            try await debounce()
            try Task.checkCancellation()
            let response = try await service.search(query, state: nil, district: nil, page: page, limit: 25)
            try Task.checkCancellation()
            guard request == generation else { return }
            result = response
        } catch is CancellationError {
            // Superseded query, not an unavailable catalogue.
        } catch {
            if request == generation && !Task.isCancelled { failed = true }
        }
    }
}

#if !KAIRO_PRODUCTION
private struct InstitutionCatalogueFixture: InstitutionCatalogueServing {
    let mode: String
    func search(_ query: String, state: String?, district: String?, page: Int, limit: Int) async throws -> InstitutionCataloguePage {
        if mode == "failure" { throw NetworkError.invalidResponse }
        let items: [InstitutionCataloguePage.Item] = mode == "empty" || mode == "unavailable" ? [] : [
            .init(id: "synthetic-institution", name: "Synthetic Institute", state: "Test State", district: "Test District", city: "Test City")
        ].filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        return .init(version: "synthetic-v1", scope: "Synthetic catalogue only", available: mode != "unavailable",
                     manualEntryAllowed: true, fallbackLabel: "Institution not listed / Enter manually",
                     provenance: .init(sourceName: "Synthetic fixture", sourceUrl: "", licenceName: "Synthetic fixture", licenceUrl: "", attribution: "Synthetic test data, not a published catalogue.", nonEndorsement: ""),
                     items: items, total: items.count, limit: limit, offset: 0, page: page)
    }
}
#endif
