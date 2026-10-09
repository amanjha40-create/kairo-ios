import XCTest
@testable import Kairo

@MainActor
final class DigiLockerReturnTests: XCTestCase {
    func testOnlyCanonicalCredentialFreeCallbacksAreAccepted() {
        let base = "com.kairoid.staging.digilocker://complete"
        XCTAssertEqual(DigiLockerReturnParser.parse(URL(string: base + "?result=connected")!), .connected)
        XCTAssertEqual(DigiLockerReturnParser.parse(URL(string: base + "?result=failed")!), .failed)
        for value in [
            "other://complete?result=connected", "com.kairoid.staging.digilocker://evil?result=connected",
            base + "/?result=connected", base + "?result=connected#fragment", base + "?result=unknown",
            base + "?result=connected&extra=x", base + "?result=connected&result=failed",
            base + "?result=connected&", base + "?%72esult=connected", base + "?result=con%6Eected",
            "com.kairoid.staging.digilocker://user@complete?result=connected",
            "com.kairoid.staging.digilocker://complete:443?result=connected", base,
            base + "?code=synthetic", base + "?state=synthetic"
        ] {
            XCTAssertEqual(DigiLockerReturnParser.parse(URL(string: value)!), .invalid)
        }
    }

    func testSingleSessionAndExactlyOnceCompletionForEveryOutcome() async {
        for outcome: DigiLockerReturnOutcome in [.connected, .failed, .cancelled, .invalid, .unavailable] {
            let browser = ReturnBrowserStub()
            let coordinator = DigiLockerAuthenticationCoordinator(browser: browser)
            let first = Task { await coordinator.connect { URL(string: "https://fixture.invalid")! } }
            while browser.completion == nil { await Task.yield() }
            XCTAssertTrue(coordinator.isActive)
            let duplicate = await coordinator.connect { XCTFail("Duplicate authorize"); return nil }
            XCTAssertNil(duplicate)
            browser.completion?(outcome)
            browser.completion?(.connected)
            let result = await first.value
            XCTAssertEqual(result, outcome)
            XCTAssertEqual(browser.starts, 1)
            XCTAssertEqual(browser.cancels, 1)
            XCTAssertFalse(coordinator.isActive)
        }
    }

    func testCancelAndStartFailureReleaseSessionWithoutRetry() async {
        let browser = ReturnBrowserStub()
        let coordinator = DigiLockerAuthenticationCoordinator(browser: browser)
        let first = Task { await coordinator.connect { URL(string: "https://fixture.invalid")! } }
        while browser.completion == nil { await Task.yield() }
        coordinator.cancel()
        let cancelled = await first.value
        XCTAssertEqual(cancelled, .cancelled)
        browser.startsSuccessfully = false
        let failed = await coordinator.connect { URL(string: "https://fixture.invalid")! }
        XCTAssertEqual(failed, .unavailable)
        XCTAssertFalse(coordinator.isActive)
        XCTAssertEqual(browser.starts, 2)
    }

    func testOutcomeCannotFabricateConnectionOrEraseHistoricalProvenance() async {
        for outcome: DigiLockerReturnOutcome in [.connected, .failed, .cancelled, .invalid] {
            let service = ReturnTruthService()
            let store = DigiLockerStore(service: service)
            await store.refreshAll()
            await store.finishAuthentication(outcome, revision: store.identityRevision)
            XCTAssertEqual(store.status?.connected, false)
            XCTAssertTrue(store.identityIsVerified)
            XCTAssertEqual(store.history?.items.count, 1)
            let reads = await service.reads
            XCTAssertEqual(reads, 2)
            XCTAssertEqual(store.actionErrorMessage, outcome.message)
        }
    }

    func testFailedRefreshPreservesHistoryAndDoesNotInferConnected() async {
        let service = ReturnTruthService()
        let store = DigiLockerStore(service: service)
        await store.refreshAll()
        await service.fail()
        await store.finishAuthentication(.connected, revision: store.identityRevision)
        XCTAssertTrue(store.summaryError)
        XCTAssertEqual(store.status?.connected, false)
        XCTAssertTrue(store.identityIsVerified)
        XCTAssertEqual(store.history?.items.count, 1)
    }

    func testOldAccountCallbackIgnoredAndServerAloneCanConnect() async {
        let service = ReturnTruthService()
        let store = DigiLockerStore(service: service)
        let old = store.identityRevision
        store.resetForIdentityChange()
        await store.finishAuthentication(.connected, revision: old)
        XCTAssertNil(store.status)
        let reads = await service.reads
        XCTAssertEqual(reads, 0)
        await service.activate()
        await store.finishAuthentication(.failed, revision: store.identityRevision)
        XCTAssertEqual(store.status?.connected, true)
    }

    func testConsentRequiresSelectionAndExplicitConsentAndResetsOnEverySelectionChange() {
        var consent = DigiLockerConsent()
        XCTAssertFalse(consent.canVerify)
        consent.accepted = true
        XCTAssertFalse(consent.canVerify)
        consent.select(.pan, enabled: true)
        XCTAssertFalse(consent.accepted)
        consent.accepted = true
        XCTAssertTrue(consent.canVerify)
        consent.select(.drivingLicence, enabled: true)
        XCTAssertEqual(consent.selected.count, 2)
        XCTAssertFalse(consent.canVerify)
        consent.accepted = true
        XCTAssertTrue(consent.canVerify)
        consent.select(.pan, enabled: false)
        XCTAssertFalse(consent.canVerify)
        consent.select(.drivingLicence, enabled: false)
        XCTAssertTrue(consent.selected.isEmpty)
    }

    func testOptionalRecordPresentationDoesNotChangeCanonicalStatus() {
        XCTAssertNil(ProductStatusLanguage.optionalRecordTitle(CareerVerificationStatus.notVerified.badgeStyle.title))
        XCTAssertNil(ProductStatusLanguage.optionalRecordTitle(PassportVerificationStatus.notVerified.style.title))
        for title in ["Verified", "Pending", "Rejected", "Draft", "Status unavailable"] {
            XCTAssertEqual(ProductStatusLanguage.optionalRecordTitle(title), title)
        }
        XCTAssertEqual(CareerVerificationStatus.notVerified.badgeStyle.title, "Candidate-provided")
        XCTAssertEqual(PassportVerificationStatus.notVerified.style.title, "Candidate-provided")
    }
}

@MainActor
private final class ReturnBrowserStub: DigiLockerBrowserSession {
    var starts = 0
    var cancels = 0
    var startsSuccessfully = true
    var completion: (@MainActor (DigiLockerReturnOutcome) -> Void)?
    func start(url: URL, completion: @escaping @MainActor (DigiLockerReturnOutcome) -> Void) -> Bool {
        starts += 1
        self.completion = completion
        return startsSuccessfully
    }
    func cancel() { cancels += 1 }
}

private actor ReturnTruthService: DigiLockerServiceProtocol {
    var reads = 0
    var fails = false
    var connected = false
    func fail() { fails = true }
    func activate() { connected = true }
    func status() async throws -> DigiLockerStatusDTO {
        reads += 1
        if fails { throw DigiLockerServiceError.invalidResponse }
        return .init(connected: connected, status: connected ? .active : .disconnected)
    }
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO {
        .init(state: .verified, sources: [.init(source: .digilocker, documentType: "PANCR", current: true, matchResult: .verifiedMatch, reason: nil)])
    }
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO {
        .init(items: [.init(documentType: "PANCR", source: .digilocker, current: true, matchResult: .verifiedMatch, matchReason: nil, integrityResult: "verified", verifiedAt: nil)], identityVerified: true)
    }
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO { .init(items: []) }
    func connect() async throws -> DigiLockerConnectResponseDTO { XCTFail("No automatic OAuth retry"); throw DigiLockerServiceError.invalidResponse }
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO { XCTFail("No verification mutation"); throw DigiLockerServiceError.invalidResponse }
}
