import Foundation

protocol TrustScoreServiceProtocol: Sendable {
    func loadScore() async throws -> TrustScoreResponseDTO
    func grantConsent(version: String) async throws -> TrustScoreResponseDTO
    func withdrawConsent() async throws -> TrustScoreResponseDTO
}

actor TrustScoreService: TrustScoreServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let decoder = APIJSONCoder.makeDecoder()

    init(sessionService: any SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func loadScore() async throws -> TrustScoreResponseDTO {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/trust-score",
                headers: ["Accept": "application/json"]
            )
        )
        return try decoder.decode(TrustScoreResponseDTO.self, from: data)
    }

    func grantConsent(version: String) async throws -> TrustScoreResponseDTO {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/trust-score/consent",
                method: .post,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try APIJSONCoder.makeEncoder().encode(
                    TrustScoreConsentRequestDTO(consentVersion: version)
                )
            )
        )
        return try await loadScore()
    }

    func withdrawConsent() async throws -> TrustScoreResponseDTO {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/trust-score/consent",
                method: .delete,
                headers: ["Accept": "application/json"]
            )
        )
        return try await loadScore()
    }
}

actor DemoTrustScoreService: TrustScoreServiceProtocol {
    private var consentGranted = true

    func loadScore() async throws -> TrustScoreResponseDTO {
        try makeFixture(consentGranted: consentGranted)
    }

    func grantConsent(version: String) async throws -> TrustScoreResponseDTO {
        _ = version
        consentGranted = true
        return try makeFixture(consentGranted: true)
    }

    func withdrawConsent() async throws -> TrustScoreResponseDTO {
        consentGranted = false
        return try makeFixture(consentGranted: false)
    }

    private func makeFixture(consentGranted: Bool) throws -> TrustScoreResponseDTO {
        let json: String
        if consentGranted {
            json = #"""
            {
              "overall": 72,
              "breakdown": {"identity": 85, "employment": 70, "education": 60},
              "domain_details": {},
              "status": "incomplete_verification",
              "positive_contributors": [{"code":"email_verified","label":"Email verified","points":15,"detail":"Email verification is complete."}],
              "negative_contributors": [],
              "critical_overrides": [],
              "manual_review_reason": "Mandatory verification checks remain incomplete.",
              "score_version": "v1",
              "last_calculated_at": "2026-08-01T10:00:00Z",
              "verification_completeness_percentage": 72,
              "week_change": 0
            }
            """#
        } else {
            json = #"""
            {
              "overall": null,
              "breakdown": null,
              "domain_details": {},
              "status": "consent_required",
              "positive_contributors": [],
              "negative_contributors": [],
              "critical_overrides": [],
              "manual_review_reason": "Explicit Trust Score consent is required before screening starts.",
              "score_version": "v1",
              "last_calculated_at": "2026-08-01T10:00:00Z",
              "verification_completeness_percentage": 0,
              "week_change": 0
            }
            """#
        }

        return try APIJSONCoder.makeDecoder().decode(
            TrustScoreResponseDTO.self,
            from: Data(json.utf8)
        )
    }
}

private nonisolated struct TrustScoreConsentRequestDTO: Encodable, Sendable {
    let consentVersion: String
}
