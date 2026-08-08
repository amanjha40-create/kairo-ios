import Foundation
import XCTest
@testable import Kairo

final class VerifyOverviewMapperTests: XCTestCase {
    func test_mapCreatesPopulatedVerifyStateFromLiveOverview() {
        let overview = VerifyOverview(
            requests: [
                VerifyRequestRecord(
                    id: "request_pending",
                    routeID: "request_pending",
                    kind: .employment,
                    typeTitle: "Employment verification",
                    organizationName: "BrightPath Technologies",
                    requesterName: "BrightPath Technologies",
                    requestedItem: "Product Operations Manager at BrightPath Technologies",
                    status: .pendingSubjectAcceptance,
                    priority: "high",
                    dueDate: makeUTCDate(year: 2026, month: 8, day: 12),
                    createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 8, hour: 8, minute: 0, second: 0)!,
                    updatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 8, hour: 10, minute: 0, second: 0)!,
                    candidateResponse: nil,
                    candidateResponseSubmittedAt: nil,
                    acceptedAt: nil,
                    consentedFields: ["employment_dates"],
                    consentedEvidenceScope: [],
                    evidenceSummary: VerifyEvidenceSummaryRecord(
                        totalItems: 0,
                        documentItems: 0,
                        fieldKeys: []
                    ),
                    timeline: [
                        VerifyTimelineEventRecord(
                            id: "event_1",
                            eventType: "verification_requested",
                            eventSource: "organization",
                            previousStatus: nil,
                            newStatus: .pendingSubjectAcceptance,
                            createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 8, hour: 8, minute: 0, second: 0)!
                        )
                    ]
                ),
                VerifyRequestRecord(
                    id: "request_completed",
                    routeID: "request_completed",
                    kind: .education,
                    typeTitle: "Education verification",
                    organizationName: "Christ University",
                    requesterName: "Christ University",
                    requestedItem: "BBA at Christ University",
                    status: .verified,
                    priority: "normal",
                    dueDate: nil,
                    createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 8, minute: 0, second: 0)!,
                    updatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 2, hour: 8, minute: 0, second: 0)!,
                    candidateResponse: "Degree certificate uploaded.",
                    candidateResponseSubmittedAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 12, minute: 0, second: 0)!,
                    acceptedAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 10, minute: 0, second: 0)!,
                    consentedFields: [],
                    consentedEvidenceScope: ["degree_certificate"],
                    evidenceSummary: VerifyEvidenceSummaryRecord(
                        totalItems: 1,
                        documentItems: 1,
                        fieldKeys: ["degree_certificate"]
                    ),
                    timeline: [
                        VerifyTimelineEventRecord(
                            id: "event_2",
                            eventType: "verified",
                            eventSource: "organization",
                            previousStatus: .inProgress,
                            newStatus: .verified,
                            createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 2, hour: 8, minute: 0, second: 0)!
                        )
                    ]
                )
            ]
        )

        let state = VerifyOverviewMapper.map(overview)

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated Verify state")
        }

        XCTAssertEqual(content.dataSourceLabel, "Live data")
        XCTAssertEqual(content.pendingRequests.first?.organization, "BrightPath Technologies")
        XCTAssertEqual(content.completedRequests.first?.organization, "Christ University")
        XCTAssertEqual(content.pendingRequests.first?.routeRequestID, "request_pending")
        XCTAssertEqual(content.priorityAction.actionTitle, "View request")
        guard case .openRequest(let requestID)? = content.priorityAction.action else {
            return XCTFail("Expected open-request priority action")
        }
        XCTAssertEqual(requestID, "request_pending")
        XCTAssertEqual(content.pendingRequests.first?.availableActions, [VerifyRequestAction.accept])
        XCTAssertEqual(content.pendingRequests.first?.evidenceRequirement, "Requested fields: employment_dates")
    }

    func test_mapCreatesEmptyVerifyStateForZeroRequests() {
        let state = VerifyOverviewMapper.map(VerifyOverview(requests: []))

        guard case .empty(let content) = state.phase else {
            return XCTFail("Expected empty Verify state")
        }

        XCTAssertEqual(content.dataSourceLabel, "Live data")
        XCTAssertEqual(content.primaryActionTitle, "Continue profile")
        XCTAssertEqual(content.primaryAction, .openCareer)
        XCTAssertEqual(content.secondaryAction, .viewTrustPassport)
    }

    func test_mapPlacesUnknownStatusesIntoSafeInProgressPresentation() {
        let overview = VerifyOverview(
            requests: [
                VerifyRequestRecord(
                    id: "request_unknown",
                    routeID: nil,
                    kind: nil,
                    typeTitle: "Custom verification",
                    organizationName: "Verifier",
                    requesterName: "Verifier",
                    requestedItem: "Custom verification",
                    status: .unknown("awaiting_magic"),
                    priority: "normal",
                    dueDate: nil,
                    createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 8, minute: 0, second: 0)!,
                    updatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 8, minute: 0, second: 0)!,
                    candidateResponse: nil,
                    candidateResponseSubmittedAt: nil,
                    acceptedAt: nil,
                    consentedFields: [],
                    consentedEvidenceScope: [],
                    evidenceSummary: VerifyEvidenceSummaryRecord(totalItems: 0, documentItems: 0, fieldKeys: []),
                    timeline: []
                )
            ]
        )

        let state = VerifyOverviewMapper.map(overview)

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated Verify state")
        }

        XCTAssertEqual(content.inProgressRequests.first?.status.style.title, "Status unavailable")
        XCTAssertTrue(content.pendingRequests.isEmpty)
    }

    func test_mapSuppressesCandidateActionsForUnroutableLegacyRequest() {
        let overview = VerifyOverview(
            requests: [
                VerifyRequestRecord(
                    id: "verify-list-0",
                    routeID: nil,
                    kind: .employment,
                    typeTitle: "Employment verification",
                    organizationName: "Archive University",
                    requesterName: "Archive University",
                    requestedItem: "Employment verification",
                    status: .pendingSubjectAcceptance,
                    priority: "normal",
                    dueDate: nil,
                    createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 7, hour: 8, minute: 0, second: 0)!,
                    updatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 7, hour: 9, minute: 0, second: 0)!,
                    candidateResponse: nil,
                    candidateResponseSubmittedAt: nil,
                    acceptedAt: nil,
                    consentedFields: [],
                    consentedEvidenceScope: [],
                    evidenceSummary: VerifyEvidenceSummaryRecord(totalItems: 0, documentItems: 0, fieldKeys: []),
                    timeline: []
                )
            ]
        )

        let state = VerifyOverviewMapper.map(overview)

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated Verify state")
        }

        XCTAssertEqual(content.pendingRequests.first?.id, "verify-list-0")
        XCTAssertNil(content.pendingRequests.first?.routeRequestID)
        XCTAssertEqual(content.pendingRequests.first?.availableActions, [])
    }

    func test_errorStateMapsTransportErrorToOfflineExperience() {
        let state = VerifyOverviewMapper.errorState(for: NetworkError.transport("offline"))

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error Verify state")
        }

        XCTAssertEqual(errorState.title, "You're offline")
        XCTAssertTrue(errorState.message.contains("couldn't reach"))
    }

    func test_requiresSessionRecoveryOnlyForExpiredSession() {
        XCTAssertTrue(VerifyOverviewMapper.requiresSessionRecovery(for: SessionServiceError.sessionExpired))
        XCTAssertFalse(VerifyOverviewMapper.requiresSessionRecovery(for: SessionServiceError.missingAccessToken))
        XCTAssertFalse(VerifyOverviewMapper.requiresSessionRecovery(for: NetworkError.transport("offline")))
    }
}

private func makeUTCDate(year: Int, month: Int, day: Int) -> Date? {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    return components.date
}

private func makeUTCTimestamp(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    second: Int
) -> Date? {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    return components.date
}
