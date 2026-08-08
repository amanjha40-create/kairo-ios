import Foundation

protocol PassportOverviewServiceProtocol: Sendable {
    func loadOverview() async throws -> PassportOverview
}

actor PassportOverviewService: PassportOverviewServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let decoder = APIJSONCoder.makeDecoder()

    init(sessionService: any SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func loadOverview() async throws -> PassportOverview {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/passport/me",
                headers: ["Accept": "application/json"]
            )
        )

        #if DEBUG
        NetworkDiagnostics.logPassportResponseShape(path: "/passport/me", data: data)
        #endif

        do {
            let response = try decoder.decode(OwnerPassportResponseDTO.self, from: data)
            return PassportOverview(dto: response)
        } catch let error as DecodingError {
            #if DEBUG
            NetworkDiagnostics.logPassportDecodeFailure(path: "/passport/me", error: error)
            logTopLevelSectionDiagnostics(for: data)
            #endif
            throw error
        }
    }

    #if DEBUG
    private func logTopLevelSectionDiagnostics(for data: Data) {
        guard
            let rootObject = try? JSONSerialization.jsonObject(with: data),
            let root = rootObject as? [String: Any]
        else {
            return
        }

        logSectionDecodeFailure(
            section: "profile",
            value: root["profile"],
            as: UserPublicDTO.self
        )
        logSectionDecodeFailure(
            section: "trust_score",
            value: root["trust_score"],
            as: TrustScoreResponseDTO.self
        )
        logSectionDecodeFailure(
            section: "vault",
            value: root["vault"],
            as: PublicPassportVaultDTO.self
        )
        logSectionDecodeFailure(
            section: "passport_metadata",
            value: root["passport_metadata"],
            as: PassportMetadataDTO.self
        )
        logSectionDecodeFailure(
            section: "sharing_summary",
            value: root["sharing_summary"],
            as: PassportSharingSummaryDTO.self
        )
        logSectionDecodeFailure(
            section: "verification_summary",
            value: root["verification_summary"],
            as: PassportVerificationSummaryDTO.self
        )
    }

    private func logSectionDecodeFailure<Section: Decodable>(
        section: String,
        value: Any?,
        as type: Section.Type
    ) {
        guard let value else {
            return
        }

        guard JSONSerialization.isValidJSONObject(value) else {
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: value)
            _ = try decoder.decode(type, from: data)
        } catch let error as DecodingError {
            NetworkDiagnostics.logPassportSectionDecodeFailure(section: section, error: error)
        } catch {
            return
        }
    }
    #endif
}
