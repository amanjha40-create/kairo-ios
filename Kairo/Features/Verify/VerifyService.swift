import Foundation

protocol VerifyOverviewServiceProtocol: Sendable {
    func loadOverview() async throws -> VerifyOverview
    func performAction(
        requestID: String,
        action: VerifyRequestAction,
        response: String?
    ) async throws
}

actor VerifyOverviewService: VerifyOverviewServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let decoder = APIJSONCoder.makeDecoder()

    init(sessionService: any SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func loadOverview() async throws -> VerifyOverview {
        let list = try await loadVerificationRequestList(path: "/verification-requests/me")

        let requests = try await withThrowingTaskGroup(of: VerifyRequestRecord.self) { group in
            for (index, item) in list.enumerated() {
                group.addTask { [self] in
                    let fallbackID = "verify-list-\(index)"

                    guard let routeID = item.routingID else {
                        return VerifyRequestRecord(
                            detail: item,
                            fallbackID: fallbackID,
                            timeline: []
                        )
                    }

                    do {
                        let detail = try await self.loadDetail(requestID: routeID)
                        let timelineItems: [VerificationRequestTimelineEventDTO]
                        do {
                            timelineItems = try await self.loadTimeline(requestID: routeID).items
                        } catch {
                            timelineItems = []
                        }

                        return VerifyRequestRecord(
                            detail: detail,
                            fallbackID: fallbackID,
                            routeIDOverride: routeID,
                            timeline: timelineItems
                        )
                    } catch {
                        return VerifyRequestRecord(
                            detail: item,
                            fallbackID: fallbackID,
                            routeIDOverride: routeID,
                            timeline: []
                        )
                    }
                }
            }

            var collected: [VerifyRequestRecord] = []
            for try await request in group {
                collected.append(request)
            }
            return collected
        }

        return VerifyOverview(requests: requests)
    }

    func performAction(
        requestID: String,
        action: VerifyRequestAction,
        response: String?
    ) async throws {
        switch action {
        case .accept:
            _ = try await send(
                NetworkRequest(
                    path: "/verification-requests/\(requestID)/accept",
                    method: .post,
                    headers: ["Accept": "application/json"]
                )
            ) as VerificationRequestResponseDTO
        case .submitInformation:
            let trimmed = response?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            _ = try await send(
                NetworkRequest(
                    path: "/verification-requests/\(requestID)/submit-information",
                    method: .post,
                    headers: [
                        "Accept": "application/json",
                        "Content-Type": "application/json"
                    ],
                    body: try APIJSONCoder.makeEncoder().encode(
                        VerificationInformationSubmissionRequestDTO(response: trimmed)
                    )
                )
            ) as VerificationRequestResponseDTO
        case .submitForReview:
            _ = try await send(
                NetworkRequest(
                    path: "/verification-requests/\(requestID)/submit-for-review",
                    method: .post,
                    headers: ["Accept": "application/json"]
                )
            ) as VerificationRequestResponseDTO
        case .resubmitForReview:
            _ = try await send(
                NetworkRequest(
                    path: "/verification-requests/\(requestID)/resubmit",
                    method: .post,
                    headers: ["Accept": "application/json"]
                )
            ) as VerificationRequestResponseDTO
        }
    }

    private func loadVerificationRequestList(path: String) async throws -> [VerificationRequestResponseDTO] {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                headers: ["Accept": "application/json"]
            )
        )

        #if DEBUG
        NetworkDiagnostics.logVerifyResponseShape(path: path, data: data)
        #endif

        do {
            return try decodeVerificationRequestList(from: data)
        } catch let error {
            #if DEBUG
            NetworkDiagnostics.logVerifyDecodeFailure(
                path: path,
                primaryError: error,
                envelopeError: nil
            )
            #endif
            throw error
        }
    }

    private func loadDetail(requestID: String) async throws -> VerificationRequestResponseDTO {
        try await send(
            NetworkRequest(
                path: "/verification-requests/\(requestID)",
                headers: ["Accept": "application/json"]
            )
        )
    }

    private func loadTimeline(requestID: String) async throws -> VerificationRequestTimelineResponseDTO {
        try await send(
            NetworkRequest(
                path: "/verification-requests/\(requestID)/timeline",
                headers: ["Accept": "application/json"]
            )
        )
    }

    private func loadCollection<Element: Decodable & Equatable & Sendable>(
        _ type: [Element].Type,
        path: String
    ) async throws -> [Element] {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                headers: ["Accept": "application/json"]
            )
        )

        #if DEBUG
        NetworkDiagnostics.logVerifyResponseShape(path: path, data: data)
        #endif

        do {
            return try decoder.decode([Element].self, from: data)
        } catch let primaryError {
            do {
                return try decoder.decode(VerificationRequestCollectionEnvelopeDTO<Element>.self, from: data).items
            } catch let envelopeError {
                #if DEBUG
                NetworkDiagnostics.logVerifyDecodeFailure(
                    path: path,
                    primaryError: primaryError,
                    envelopeError: envelopeError
                )
                #endif
                throw primaryError
            }
        }
    }

    private func send<Response: Decodable>(
        _ request: NetworkRequest
    ) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(request)
        return try decoder.decode(Response.self, from: data)
    }

    private func decodeVerificationRequestList(from data: Data) throws -> [VerificationRequestResponseDTO] {
        let rootObject = try JSONSerialization.jsonObject(with: data)

        let rawItems: [Any]
        if let array = rootObject as? [Any] {
            rawItems = array
        } else if
            let object = rootObject as? [String: Any],
            let items = object["items"] as? [Any] {
            rawItems = items
        } else {
            return try decoder.decode([VerificationRequestResponseDTO].self, from: data)
        }

        var decodedItems: [VerificationRequestResponseDTO] = []
        var firstError: Error?

        for (index, rawItem) in rawItems.enumerated() {
            #if DEBUG
            NetworkDiagnostics.logVerifyListItemRoutingFields(index: index, item: rawItem)
            #endif
            do {
                let itemData = try JSONSerialization.data(withJSONObject: rawItem)
                decodedItems.append(try decoder.decode(VerificationRequestResponseDTO.self, from: itemData))
            } catch {
                firstError = firstError ?? error
                #if DEBUG
                NetworkDiagnostics.logVerifyListItemSkipped(index: index, error: error)
                #endif
            }
        }

        if decodedItems.isEmpty, let firstError {
            throw firstError
        }

        return decodedItems
    }
}
