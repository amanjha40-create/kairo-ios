import Foundation

protocol PassportShareServiceProtocol: Sendable {
    func listShares() async throws -> [PassportShare]
    func getShare(id: String) async throws -> PassportShare
    func getAnalytics(shareID: String) async throws -> PassportShareAnalytics
    func createShare(_ input: PassportShareMutationInput) async throws -> PassportShareCreation
    func updateShare(id: String, input: PassportShareMutationInput) async throws -> PassportShare
    func revokeShare(id: String) async throws -> PassportShare
}

actor PassportShareService: PassportShareServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let environment: AppEnvironment
    private let decoder = APIJSONCoder.makeDecoder()
    private let encoder = APIJSONCoder.makeEncoder()

    init(
        sessionService: any SessionServiceProtocol,
        configuration: AppConfiguration
    ) {
        self.sessionService = sessionService
        environment = configuration.environment
    }

    func listShares() async throws -> [PassportShare] {
        let pageLimit = 100
        var offset = 0
        var shares: [PassportShare] = []
        var expectedTotal = Int.max

        while shares.count < expectedTotal {
            let page: PassportSharePageDTO = try await get(
                path: "/passport-shares",
                queryItems: [
                    URLQueryItem(name: "offset", value: String(offset)),
                    URLQueryItem(name: "limit", value: String(pageLimit))
                ]
            )
            expectedTotal = page.total
            let next = page.items.map(\.domain)
            shares.append(contentsOf: next)
            guard !next.isEmpty else { break }
            offset += next.count
        }

        return shares
    }

    func getShare(id: String) async throws -> PassportShare {
        let response: PassportShareResponseDTO = try await get(path: "/passport-shares/\(id)")
        return response.domain
    }

    func getAnalytics(shareID: String) async throws -> PassportShareAnalytics {
        let response: PassportShareAnalyticsResponseDTO = try await get(
            path: "/passport-shares/\(shareID)/analytics"
        )
        return response.domain
    }

    func createShare(_ input: PassportShareMutationInput) async throws -> PassportShareCreation {
        try validate(input)
        let response: PassportShareCreateResponseDTO = try await send(
            path: "/passport-shares",
            method: .post,
            body: PassportShareCreateRequestDTO(input: input)
        )
        guard let publicURL = validatedPublicURL(from: response.shareURL) else {
            throw PassportShareServiceError.invalidPublicURL
        }
        return PassportShareCreation(share: response.share, publicURL: publicURL)
    }

    func updateShare(id: String, input: PassportShareMutationInput) async throws -> PassportShare {
        try validate(input)
        let _: PassportShareResponseDTO = try await send(
            path: "/passport-shares/\(id)",
            method: .patch,
            body: PassportShareUpdateRequestDTO(input: input)
        )
        return try await getShare(id: id)
    }

    func revokeShare(id: String) async throws -> PassportShare {
        let _: PassportShareResponseDTO = try await postWithoutBody(
            path: "/passport-shares/\(id)/revoke"
        )
        return try await getShare(id: id)
    }

    private func validate(_ input: PassportShareMutationInput) throws {
        if let label = input.label, label.count > 120 {
            throw PassportShareServiceError.invalidDraft
        }
        if let expiresAt = input.expiresAt, expiresAt <= Date() {
            throw PassportShareServiceError.invalidDraft
        }
    }

    private func validatedPublicURL(from value: String) -> URL? {
        guard
            let url = URL(string: value),
            let scheme = url.scheme?.lowercased(),
            let host = url.host,
            !host.isEmpty
        else {
            return nil
        }

        if scheme == "https" {
            return url
        }
        if environment == .development, scheme == "http", ["localhost", "127.0.0.1"].contains(host) {
            return url
        }
        return nil
    }

    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                headers: ["Accept": "application/json"],
                queryItems: queryItems
            )
        )
        return try decoder.decode(Response.self, from: data)
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod,
        body: Body
    ) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                method: method,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try encoder.encode(body)
            )
        )
        return try decoder.decode(Response.self, from: data)
    }

    private func postWithoutBody<Response: Decodable>(path: String) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                method: .post,
                headers: ["Accept": "application/json"]
            )
        )
        return try decoder.decode(Response.self, from: data)
    }
}

actor DemoPassportShareService: PassportShareServiceProtocol {
    private var shares: [PassportShare]
    private var nextID = 2

    init(now: Date = Date(timeIntervalSince1970: 1_785_600_000)) {
        shares = [
            PassportShare(
                id: "demo-share-1",
                label: "Recruiter preview",
                permissions: PassportSharePermissions(
                    includeEmployments: true,
                    includeEducations: true,
                    includeInternships: false,
                    includeFreelance: false,
                    includeGigPlatforms: false,
                    includePortfolio: false,
                    includeCertifications: true,
                    includeSkills: false,
                    includeProjects: false,
                    includeUserDocuments: false,
                    showEmployerNames: true,
                    showDocuments: false,
                    showTrustScore: true
                ),
                trackViews: true,
                expiresAt: now.addingTimeInterval(2_592_000),
                revokedAt: nil,
                lastViewedAt: nil,
                createdAt: now,
                updatedAt: now,
                state: .active
            )
        ]
    }

    func listShares() async throws -> [PassportShare] { shares }

    func getShare(id: String) async throws -> PassportShare {
        guard let share = shares.first(where: { $0.id == id }) else {
            throw PassportShareServiceError.shareNotFound
        }
        return share
    }

    func getAnalytics(shareID: String) async throws -> PassportShareAnalytics {
        _ = try await getShare(id: shareID)
        return PassportShareAnalytics(shareID: shareID, totalViews: 0, uniqueViews: 0, lastViewedAt: nil)
    }

    func createShare(_ input: PassportShareMutationInput) async throws -> PassportShareCreation {
        let id = "demo-share-\(nextID)"
        nextID += 1
        let now = Date(timeIntervalSince1970: 1_785_600_000 + Double(nextID))
        let share = PassportShare(
            id: id,
            label: input.label,
            permissions: input.permissions,
            trackViews: true,
            expiresAt: input.expiresAt,
            revokedAt: nil,
            lastViewedAt: nil,
            createdAt: now,
            updatedAt: now,
            state: .active
        )
        shares.insert(share, at: 0)
        return PassportShareCreation(
            share: share,
            publicURL: URL(string: "https://demo.kairoid.invalid/passport/\(id)")!
        )
    }

    func updateShare(id: String, input: PassportShareMutationInput) async throws -> PassportShare {
        let current = try await getShare(id: id)
        guard current.state == .active else {
            throw NetworkError.api(APIError(
                statusCode: 409,
                code: .conflict,
                message: "Only active demo shares can be updated.",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        }
        let updated = PassportShare(
            id: current.id,
            label: input.label,
            permissions: input.permissions,
            trackViews: current.trackViews,
            expiresAt: input.expiresAt,
            revokedAt: nil,
            lastViewedAt: current.lastViewedAt,
            createdAt: current.createdAt,
            updatedAt: Date(timeIntervalSince1970: 1_785_600_100),
            state: .active
        )
        replace(updated)
        return updated
    }

    func revokeShare(id: String) async throws -> PassportShare {
        let current = try await getShare(id: id)
        let now = Date(timeIntervalSince1970: 1_785_600_200)
        let revoked = PassportShare(
            id: current.id,
            label: current.label,
            permissions: current.permissions,
            trackViews: current.trackViews,
            expiresAt: current.expiresAt,
            revokedAt: now,
            lastViewedAt: current.lastViewedAt,
            createdAt: current.createdAt,
            updatedAt: now,
            state: .revoked
        )
        replace(revoked)
        return revoked
    }

    private func replace(_ share: PassportShare) {
        guard let index = shares.firstIndex(where: { $0.id == share.id }) else { return }
        shares[index] = share
    }
}
