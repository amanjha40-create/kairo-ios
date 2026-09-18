import XCTest
@testable import Kairo

@MainActor
final class VerifyHierarchyTests: XCTestCase {
    func testNineCanonicalFiltersAndDefaultOrder() {
        XCTAssertEqual(VerifyRequestFilter.allCases.map(\.title), ["All verification requests", "Needs your attention", "In progress",
            "Verified", "Rejected", "Withdrawn", "Unable to verify", "Expired", "Cancelled"])
        XCTAssertEqual(VerifyRequestFilter.allCases.first, .all)
    }

    func testAllRetainsEveryKnownAndUnknownStatus() {
        for status in VerifyVerificationStatus.displayOrder + [.unknown("future")] {
            XCTAssertTrue(VerifyRequestFilter.all.includes(status))
        }
    }

    func testActionableFilterUsesCanonicalCandidateActionStates() {
        let expected: [VerifyVerificationStatus] = [.draft, .pendingSubjectAcceptance, .accepted,
            .pendingSubjectSubmission, .awaitingInformation, .awaitingSubjectCorrections]
        XCTAssertEqual(VerifyVerificationStatus.displayOrder.filter(VerifyRequestFilter.attention.includes), expected)
    }

    func testInProgressExcludesAttentionTerminalAndUnknown() {
        XCTAssertEqual(VerifyVerificationStatus.displayOrder.filter(VerifyRequestFilter.inProgress.includes), [
            .pendingAdminReview, .pendingAdminReReview, .approvedForOrganizationVerification,
            .pendingOrganizationResolution, .pendingOrganizationAcceptance, .inProgress, .pendingAdminQualityReview])
        XCTAssertFalse(VerifyRequestFilter.inProgress.includes(.unknown("future")))
    }

    func testEachTerminalFilterHasExactMembershipWithoutLeakage() {
        let pairs: [(VerifyRequestFilter, VerifyVerificationStatus)] = [(.verified, .verified), (.rejected, .rejected),
            (.withdrawn, .withdrawnByCandidate), (.unableToVerify, .unableToVerify), (.expired, .expired), (.cancelled, .cancelled)]
        for (filter, expected) in pairs {
            XCTAssertEqual(VerifyVerificationStatus.displayOrder.filter(filter.includes), [expected])
            XCTAssertFalse(filter.includes(.unknown("future")))
        }
    }

    func testUnknownOnlyAppearsUnderAllAndUnavailableGroup() {
        let status = VerifyVerificationStatus(rawBackendValue: "future_state")
        XCTAssertEqual(status.style.title, "Status unavailable")
        XCTAssertEqual(VerifyRequestFilter.allCases.filter { $0.includes(status) }, [.all])
        XCTAssertEqual(VerifyListGroup.allCases.filter { $0.includes(status) }, [.unavailable])
        XCTAssertFalse(status.canCandidateWithdraw)
        XCTAssertEqual(content.request(id: "qa-unknown")?.availableActions, [])
    }

    func testGroupsPartitionWithoutDuplicatingOrDroppingRequests() {
        XCTAssertEqual(VerifyListGroup.allCases, [.attention, .inProgress, .completed, .unavailable])
        let counts = VerifyListGroup.allCases.map { group in content.requests.filter { group.includes($0.status) }.count }
        XCTAssertEqual(counts, [1, 1, 6, 1])
        XCTAssertEqual(counts.reduce(0, +), content.requests.count)
    }

    func testFilterCountsComeOnlyFromSuppliedList() {
        XCTAssertEqual(VerifyRequestFilter.all.requests(in: content.requests).count, 9)
        for filter in VerifyRequestFilter.allCases.dropFirst() {
            XCTAssertEqual(filter.requests(in: content.requests).count, 1)
            XCTAssertTrue(filter.requests(in: []).isEmpty)
        }
    }

    func testEveryFilterHasDistinctTruthfulEmptyCopy() {
        let messages = VerifyRequestFilter.allCases.map(\.emptyMessage)
        XCTAssertEqual(Set(messages).count, 9)
        XCTAssertTrue(messages.allSatisfy { $0.hasPrefix("No ") })
    }

    func testIdenticalClaimAndOrganizationNeverReplaceExactRequestIdentity() {
        XCTAssertEqual(Set(content.requests.map(\.requestedItem)).count, 1)
        XCTAssertEqual(Set(content.requests.map(\.organization)).count, 1)
        for request in content.requests {
            XCTAssertEqual(content.request(id: request.id)?.routeRequestID, request.routeRequestID)
            XCTAssertEqual(VerifyFocusedDestination.resolve(target: request.id, authoritativeFocusID: request.id,
                state: VerifyHierarchyFixtures.state), .request(request.id))
        }
        XCTAssertEqual(content.request(id: "qa-withdrawn")?.status, .withdrawnByCandidate)
        XCTAssertEqual(content.request(id: "qa-active")?.status, .pendingAdminReview)
    }

    func testConsentScopesContactAndEvidencePreservedSeparately() {
        let request = content.request(id: "qa-active")!
        XCTAssertEqual(request.consentedFields, ["role", "employment_dates"])
        XCTAssertEqual(request.consentedEvidenceScope, ["employment_document"])
        XCTAssertEqual(request.consentVersion, "qa-v1")
        XCTAssertNotNil(request.consentedAt)
        XCTAssertEqual(request.verificationContact?.name, "Synthetic Verification Contact")
        XCTAssertEqual(request.evidence.first?.originalFilename, "synthetic-verification.pdf")
        XCTAssertNil(request.evidence.first?.downloadURL)
    }

    func testTimelineIsChronologicalAndRetainsEvidenceEventMeaning() {
        let timeline = content.request(id: "qa-active")!.timeline
        XCTAssertEqual(timeline.map(\.id), ["qa-event-early", "qa-event-late"])
        XCTAssertEqual(timeline.map(\.title), ["Evidence Uploaded", "Verification Submitted"])
        XCTAssertTrue(timeline.allSatisfy { $0.source == "You" })
    }

    func testWithdrawalRemainsRestrictedAndTerminalHistoryHasNoMutationActions() {
        XCTAssertEqual(VerifyVerificationStatus.displayOrder.filter(\.canCandidateWithdraw), [.pendingAdminReview, .pendingAdminReReview])
        XCTAssertEqual(content.request(id: "qa-active")?.availableActions, [.withdraw])
        for request in content.completedRequests { XCTAssertTrue(request.availableActions.isEmpty) }
        XCTAssertTrue(content.request(id: "qa-withdrawn")!.showsCareerRecovery)
    }

    func testFailureDoesNotLeaveCachedCountsLookingAuthoritative() async {
        let loader = VerifyOverviewLoadState()
        loader.state = VerifyHierarchyFixtures.state
        _ = await loader.load(service: FailedVerifyHierarchyService(), focusedRequestID: nil, showLoading: false)
        guard case .error = loader.state.phase else { return XCTFail("Must show Retry instead of old counts") }
        XCTAssertNil(loader.authoritativeFocusID)
    }

    func testHierarchyFixtureIsExplicitlyGuarded() {
        let env = ["KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_VERIFY_HIERARCHY": "1"]
        XCTAssertFalse(UITestVerifyConfiguration.current(arguments: [], environment: env).showsHierarchy)
        XCTAssertTrue(UITestVerifyConfiguration.current(arguments: ["-KAIRO_UI_TESTING"], environment: env).showsHierarchy)
    }

    private var content: VerifyOverviewContent {
        guard case .populated(let content) = VerifyHierarchyFixtures.state.phase else { fatalError("Invalid synthetic fixture") }
        return content
    }
}

private struct FailedVerifyHierarchyService: VerifyOverviewServiceProtocol {
    func loadOverview() async throws -> VerifyOverview { throw URLError(.notConnectedToInternet) }
    func performAction(requestID: String, action: VerifyRequestAction, response: String?, consent: VerificationSubmissionConsent?) async throws {
        throw URLError(.unsupportedURL)
    }
}
