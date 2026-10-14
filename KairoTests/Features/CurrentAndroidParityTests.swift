import XCTest
@testable import Kairo

@MainActor final class CurrentAndroidParityTests: XCTestCase {
    func testNominationRequiresNameDesignationAndContact() {
        XCTAssertFalse(ManagerNominationInput().isValid)
        XCTAssertFalse(ManagerNominationInput(fullName: "Synthetic", designation: "Lead").isValid)
        XCTAssertTrue(ManagerNominationInput(fullName: "Synthetic", designation: "Lead", workEmail: "qa@example.invalid").isValid)
        XCTAssertTrue(ManagerNominationInput(fullName: "Synthetic", designation: "Lead", phone: "+12025550123").isValid)
        XCTAssertFalse(ManagerNominationInput(fullName: "Synthetic", designation: "Lead", phone: "2025550123").isValid)
        XCTAssertFalse(ManagerNominationInput(fullName: "Synthetic", designation: "Lead", workEmail: "invalid").isValid)
    }
    func testNominationNormalizesTransientInputs() {
        let input = ManagerNominationInput(fullName: " QA ", designation: " Lead ", workEmail: " ", phone: " +12025550123 ").normalized
        XCTAssertEqual(input.fullName, "QA"); XCTAssertEqual(input.designation, "Lead")
        XCTAssertNil(input.workEmail); XCTAssertEqual(input.phone, "+12025550123")
    }
    func testAllReferenceStatesHaveTruthfulLabels() {
        let labels = ["not_started":"Not started", "pending":"Pending", "awaiting_hr_validation":"Awaiting HR confirmation",
            "ready_to_invite":"Ready for invitation", "invitation_sent":"Invitation sent", "opened":"Awaiting response",
            "completed":"Completed", "declined":"Declined", "expired":"Invitation expired", "needs_review":"Needs review", "cannot_confirm":"Unable to confirm"]
        for (key, label) in labels { XCTAssertEqual(ReferenceCopy.status(key), label) }
        XCTAssertEqual(ReferenceCopy.status("private_admin_value"), "Status unavailable")
    }
    func testHRConfirmedAndLockedManagersRequireExplicitChange() {
        XCTAssertFalse(ManagerReferenceSummary(status: "not_started").requiresChange)
        XCTAssertFalse(ManagerReferenceSummary(status: "awaiting_hr_validation").requiresChange)
        XCTAssertTrue(ManagerReferenceSummary(status: "pending", nominationLocked: true).requiresChange)
        XCTAssertTrue(ManagerReferenceSummary(status: "pending", relationshipConfirmedByHr: true).requiresChange)
        XCTAssertTrue(ManagerReferenceSummary(status: "completed").requiresChange)
    }
    func testWithheldIdentityNeverRenders() {
        let summary = ManagerReferenceSummary(status: "ready_to_invite", fullName: "hidden", designation: "hidden", identityWithheld: true)
        XCTAssertNil(summary.visibleName); XCTAssertNil(summary.visibleDesignation)
    }
    func testReferenceDTOIgnoresPrivateContactRatingAndCapabilityFields() throws {
        let data = Data(#"{"employment_id":"fixture","completed_count":2,"total_count":2,"hr_reference":{"status":"completed","comments":"secret-comment"},"reporting_manager":{"status":"completed","work_email":"private@example.invalid","phone":"secret-phone","rating":5,"invitation_url":"secret-url","token":"secret-token"}}"#.utf8)
        let dto = try APIJSONCoder.makeDecoder().decode(CandidateReferences.self, from: data)
        XCTAssertEqual(dto.completedCount, 2)
        let output = String(decoding: try APIJSONCoder.makeEncoder().encode(dto), as: UTF8.self)
        for forbidden in ["secret-", "private@", "rating", "invitation_url"] { XCTAssertFalse(output.contains(forbidden)) }
    }
    func testReferenceScopeAndCountFailClosed() throws {
        let dto = CandidateReferences(employmentId: "a", completedCount: 3, totalCount: 2, hrReference: .init(status: "completed"), reportingManager: .init(status: "completed"))
        XCTAssertThrowsError(try dto.validated(for: "a")); XCTAssertThrowsError(try dto.validated(for: "b"))
    }
    func testAddressValidationUsesStructuredIndianAddress() {
        var value = ClaimedPermanentAddress(addressLine1: "10 Synthetic Road", city: "Test", state: "Test", postalCode: "110001")
        XCTAssertTrue(value.isValid)
        value.postalCode = "000001"; XCTAssertFalse(value.isValid)
        value.postalCode = "110001"; value.addressLine1 = "Test\nRoad"; XCTAssertFalse(value.isValid)
        value.addressLine1 = "10 Road"; value.country = "US"; XCTAssertFalse(value.isValid)
    }
    func testStructuredAddressUsesExactUnderscoredNumberedContractKeys() throws {
        let original = ClaimedPermanentAddress(addressLine1: "10 Synthetic Road", addressLine2: "QA floor", city: "Test", state: "Test", postalCode: "110001")
        let data = try APIJSONCoder.makeEncoder().encode(original)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(body["address_line_1"], "10 Synthetic Road")
        XCTAssertEqual(body["address_line_2"], "QA floor")
        XCTAssertNil(body["address_line1"])
        XCTAssertEqual(try APIJSONCoder.makeDecoder().decode(ClaimedPermanentAddress.self, from: data), original)
    }
    func testApprovedDocumentAndThreeChecksCannotLocallyVerifyAddress() {
        let value = PermanentAddressState(enabled: true, status: "NEEDS_REVIEW", documentStatus: "APPROVED_MATCHING", successfulGpsChecks: 3, requiredGpsChecks: 3)
        XCTAssertFalse(value.isVerified); XCTAssertEqual(value.progress, "3 of 3 completed")
        XCTAssertTrue(PermanentAddressState(enabled: true, status: "PERMANENT_ADDRESS_VERIFIED").isVerified)
    }
    func testDocumentStatusMappingAndUnknownFailClosed() {
        let values = ["REQUIRED":"Required", "UPLOADING":"Upload not completed", "UPLOADED":"Ready to submit", "UNDER_REVIEW":"Under review", "NEEDS_REVIEW":"Under review", "MATCH":"Approved", "APPROVED_MATCHING":"Approved", "REJECTED":"Rejected", "MISMATCH":"Needs correction", "NEEDS_CORRECTION":"Needs correction", "SUPERSEDED":"Replaced"]
        for (status, label) in values { XCTAssertEqual(AddressDocumentState(status: status).label, label) }
        XCTAssertFalse(AddressDocumentState(status: "UNKNOWN").approved)
        XCTAssertEqual(AddressDocumentState(status: "UNKNOWN").label, "Status unavailable")
    }
    func testAddressDTODropsAdminDiagnosticsAndTargetCoordinates() throws {
        let value = try APIJSONCoder.makeDecoder().decode(PermanentAddressState.self, from: Data(#"{"enabled":true,"status":"NEEDS_REVIEW","target_latitude":12,"target_longitude":34,"reviewer_identity":"private-reviewer","risk_flags":["private-risk"],"s3_key":"private-key"}"#.utf8))
        let encoded = String(decoding: try APIJSONCoder.makeEncoder().encode(value), as: UTF8.self)
        for field in ["latitude", "longitude", "private-", "reviewer", "s3_"] { XCTAssertFalse(encoded.contains(field)) }
    }
    func testPrimingExcludedAndFiveSamplesNeedThirtySecondSpan() {
        var window = AddressSampleWindow(started: Date(timeIntervalSince1970: 100), uptime: 100)
        XCTAssertFalse(accept(&window, second: 100))
        for time in [101.0,107,113,119,125] { XCTAssertTrue(accept(&window, second: time)) }
        XCTAssertEqual(window.count, 5); XCTAssertFalse(window.complete)
        XCTAssertTrue(accept(&window, second: 131)); XCTAssertTrue(window.complete)
    }
    func testCachedFutureInaccurateAndCloselySpacedSamplesExcluded() {
        var window = AddressSampleWindow(started: Date(timeIntervalSince1970: 100), uptime: 100)
        XCTAssertFalse(window.accept(timestamp: Date(timeIntervalSince1970: 99), accuracy: 5, now: Date(timeIntervalSince1970: 100), nowUptime: 100))
        XCTAssertNil(window.priming)
        XCTAssertFalse(accept(&window, second: 100))
        XCTAssertFalse(window.accept(timestamp: Date(timeIntervalSince1970: 105), accuracy: 10, now: Date(timeIntervalSince1970: 101), nowUptime: 101))
        XCTAssertFalse(accept(&window, second: 101, accuracy: 51))
        XCTAssertTrue(accept(&window, second: 102))
        XCTAssertFalse(accept(&window, second: 107)); XCTAssertTrue(accept(&window, second: 108))
        XCTAssertFalse(accept(&window, second: 114, accuracy: .nan))
    }
    func testClockJumpStaleBatchAndTimeoutNeverCount() {
        var window = AddressSampleWindow(started: Date(timeIntervalSince1970: 100), uptime: 100)
        XCTAssertFalse(accept(&window, second: 100))
        XCTAssertFalse(window.accept(timestamp: Date(timeIntervalSince1970: 101), accuracy: 5, now: Date(timeIntervalSince1970: 105), nowUptime: 105))
        XCTAssertFalse(window.accept(timestamp: Date(timeIntervalSince1970: 120), accuracy: 5, now: Date(timeIntervalSince1970: 120), nowUptime: 105))
        XCTAssertFalse(accept(&window, second: 160)); XCTAssertTrue(window.expired(nowUptime: 160))
        XCTAssertEqual(window.count, 0)
    }
    func testPermissionDeniedStartsNoBackendSession() async {
        let service = CurrentParityFixtures(), collector = SyntheticAddressCollector(mode: .denied)
        do { _ = try await AddressLocationOperation(collector: collector, service: service).run(version: CurrentParityFixtures.version) { _ in }; XCTFail() }
        catch { XCTAssertEqual(error as? AddressCollectionError, .permission) }
        let starts = await service.starts; XCTAssertEqual(starts, 0); XCTAssertTrue(collector.cancelled)
    }
    func testLocationDisabledStartsNoBackendSession() async {
        let service = CurrentParityFixtures(), collector = SyntheticAddressCollector(mode: .disabled)
        do { _ = try await AddressLocationOperation(collector: collector, service: service).run(version: CurrentParityFixtures.version) { _ in }; XCTFail() }
        catch { XCTAssertEqual(error as? AddressCollectionError, .disabled) }
        let starts = await service.starts; XCTAssertEqual(starts, 0); XCTAssertTrue(collector.cancelled)
    }
    func testTimeoutStopsCollectorAndCancelsExactlyOnceWithoutComplete() async {
        let service = CurrentParityFixtures(), collector = SyntheticAddressCollector(mode: .timeout)
        let operation = AddressLocationOperation(collector: collector, service: service)
        do { _ = try await operation.run(version: CurrentParityFixtures.version) { _ in }; XCTFail() } catch { XCTAssertEqual(error as? AddressCollectionError, .timeout) }
        await operation.cancel()
        let starts = await service.starts, completes = await service.completions, cancels = await service.cancellations
        XCTAssertEqual(starts, 1); XCTAssertEqual(completes, 0); XCTAssertEqual(cancels, 1); XCTAssertTrue(collector.cancelled)
    }
    func testNeedsReviewFromServerStopsCollectorWithoutInferringSuccess() async throws {
        let service = CurrentParityFixtures(), collector = SyntheticAddressCollector()
        let state = try await AddressLocationOperation(collector: collector, service: service).run(version: CurrentParityFixtures.version) { _ in }
        XCTAssertTrue(collector.cancelled); XCTAssertFalse(state.isVerified); XCTAssertEqual(state.successfulGpsChecks, 0)
        XCTAssertEqual(state.lastLocationResult, "NEEDS_REVIEW")
        let count = await service.completions; XCTAssertEqual(count, 1)
    }
    func testPrecancelledOperationCannotAcquireOrStart() async {
        let service = CurrentParityFixtures(), collector = SyntheticAddressCollector()
        let operation = AddressLocationOperation(collector: collector, service: service)
        await operation.cancel()
        do { _ = try await operation.run(version: CurrentParityFixtures.version) { _ in }; XCTFail() } catch { XCTAssertEqual(error as? AddressCollectionError, .cancelled) }
        let count = await service.starts; XCTAssertEqual(count, 0)
    }
    func testCancellationDuringCollectionStopsAndCancelsServerExactlyOnce() async {
        let service = CurrentParityFixtures(), collector = WaitingAddressCollector()
        let operation = AddressLocationOperation(collector: collector, service: service)
        let running = Task { try await operation.run(version: CurrentParityFixtures.version) { _ in } }
        for _ in 0..<100 where !collector.started { await Task.yield() }
        XCTAssertTrue(collector.started)
        running.cancel()
        await operation.cancel()
        do { _ = try await running.value; XCTFail() } catch {}
        await operation.cancel()
        let cancels = await service.cancellations, completes = await service.completions
        XCTAssertEqual(cancels, 1); XCTAssertEqual(completes, 0); XCTAssertTrue(collector.stopped)
    }
    func testVersionChangeClearsApprovedDocumentAndProgress() async throws {
        let service = CurrentParityFixtures(scenario: "approved")
        let store = PermanentAddressStore(service: service, collector: SyntheticAddressCollector())
        store.refresh(); await wait(store)
        XCTAssertTrue(store.document?.approved == true)
        store.save(.init(addressLine1: "20 Synthetic Road", city: "Test", state: "Test", postalCode: "110001")); await wait(store)
        XCTAssertNotEqual(store.state?.addressVersionId, CurrentParityFixtures.version)
        XCTAssertEqual(store.document?.status, "REQUIRED"); XCTAssertEqual(store.state?.successfulGpsChecks, 0); XCTAssertFalse(store.state?.isVerified == true)
    }
    func testReviewRequiresExplicitConsentAndUploadedDocument() async {
        let service = CurrentParityFixtures(scenario: "uploaded")
        let store = PermanentAddressStore(service: service, collector: SyntheticAddressCollector())
        store.refresh(); await wait(store)
        store.submitDocument(confirmed: false); await wait(store)
        var count = await service.submissions; XCTAssertEqual(count, 0)
        store.submitDocument(confirmed: true); await wait(store)
        count = await service.submissions; XCTAssertEqual(count, 1)
        XCTAssertEqual(store.document?.status, "UNDER_REVIEW"); XCTAssertFalse(store.state?.isVerified == true)
    }
    func testUnchangedAddressSaveSignalsEditorCompletionWithoutInvalidatingApproval() async throws {
        let store = PermanentAddressStore(service: CurrentParityFixtures(scenario: "approved"), collector: SyntheticAddressCollector())
        store.refresh(); await wait(store)
        let address = try XCTUnwrap(store.state?.claimedAddress)
        let version = store.state?.addressVersionId
        store.save(address); await wait(store)
        XCTAssertEqual(store.addressSaveRevision, 1)
        XCTAssertEqual(store.state?.addressVersionId, version)
        XCTAssertTrue(store.document?.approved == true)
    }
    func testUploadDoesNotAutomaticallySubmitForReview() async {
        let service = CurrentParityFixtures()
        let store = PermanentAddressStore(service: service, collector: SyntheticAddressCollector())
        store.refresh(); await wait(store)
        store.upload(file: URL(fileURLWithPath: "/synthetic-not-read.pdf"), type: "voter_id", issued: nil); await wait(store)
        XCTAssertFalse(store.locationActive)
        XCTAssertEqual(store.document?.status, "UPLOADED")
        let count = await service.submissions; XCTAssertEqual(count, 0)
    }
    func testUploadFailureIsRetryableWithoutOptimisticApproval() async {
        let service = CurrentParityFixtures(scenario: "upload_failure")
        let store = PermanentAddressStore(service: service, collector: SyntheticAddressCollector())
        store.refresh(); await wait(store)
        store.upload(file: URL(fileURLWithPath: "/not-read.pdf"), type: "voter_id", issued: nil); await wait(store)
        XCTAssertNotNil(store.error); XCTAssertEqual(store.document?.status, "REQUIRED"); XCTAssertFalse(store.busy)
        let count = await service.uploads; XCTAssertEqual(count, 1)
    }
    func testFixtureGateRejectsProductionDemoAndNormalLaunch() {
        for build in AppBuildConfiguration.allCases {
            let config = AppConfiguration(buildConfiguration: build, environment: .staging, isDemoModeEnabled: false,
                apiBaseURL: APIConfiguration.baseURL(for: .staging), keychainService: "synthetic")
            XCTAssertEqual(CurrentParityQA.isEnabled(configuration: config, arguments: [UITestLaunchConfiguration.enabledArgument], environment: ["KAIRO_UI_TEST_CURRENT_PARITY":"1"]), build == .staging)
            XCTAssertFalse(CurrentParityQA.isEnabled(configuration: config, arguments: [], environment: ["KAIRO_UI_TEST_CURRENT_PARITY":"1"]))
        }
    }
    private func accept(_ window: inout AddressSampleWindow, second: Double, accuracy: Double = 10) -> Bool {
        window.accept(timestamp: Date(timeIntervalSince1970: second), accuracy: accuracy, now: Date(timeIntervalSince1970: second), nowUptime: second)
    }
    private func wait(_ store: PermanentAddressStore) async {
        for _ in 0..<200 where store.busy { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(store.busy)
    }
}

@MainActor private final class WaitingAddressCollector: AddressLocationCollecting {
    var started = false
    var stopped = false
    private var continuation: CheckedContinuation<[AddressLocationSample], Error>?
    func ensurePermission() async throws {}
    func collect() async throws -> [AddressLocationSample] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation; started = true
        }
    }
    func cancel() {
        stopped = true
        let pending = continuation; continuation = nil
        pending?.resume(throwing: AddressCollectionError.cancelled)
    }
}
