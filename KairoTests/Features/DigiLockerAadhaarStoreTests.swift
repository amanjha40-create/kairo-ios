import Foundation
import XCTest
@testable import Kairo

@MainActor
final class DigiLockerAadhaarStoreTests: XCTestCase {
    func testSummaryInventoryAndReturnNeverAutomaticallyCheckOrVerifyAadhaar() async throws {
        let service = try AadhaarStoreServiceStub()
        let store = DigiLockerStore(service: service)
        await store.loadSummaryIfNeeded()
        await store.refreshAll()
        await store.finishAuthentication(.connected, revision: store.identityRevision)

        XCTAssertEqual(store.aadhaarState, .idle)
        XCTAssertFalse(store.aadhaarConsent)
        let calls = await service.calls()
        XCTAssertEqual(calls.availability, 0)
        XCTAssertEqual(calls.verification, 0)
        XCTAssertEqual(calls.connect, 0)
    }

    func testAvailabilityIsNotVerificationAndRequiresFreshSeparateConsent() async throws {
        let service = try AadhaarStoreServiceStub()
        let store = DigiLockerStore(service: service)
        await store.refreshAll()
        _ = await store.verify([.pan])
        XCTAssertFalse(store.aadhaarConsent)
        store.aadhaarConsent = true
        let premature = await store.verifyAadhaar()
        XCTAssertFalse(premature)

        await store.checkAadhaarAvailability()
        XCTAssertEqual(store.aadhaarState, .available)
        XCTAssertFalse(store.aadhaarConsent)
        XCTAssertNil(store.savedAadhaar)
        XCTAssertFalse(store.identityIsVerified)
        let unconsented = await store.verifyAadhaar()
        XCTAssertFalse(unconsented)

        store.aadhaarConsent = true
        let completed = await store.verifyAadhaar()
        XCTAssertTrue(completed)
        XCTAssertEqual(store.aadhaarState, .verified)
        XCTAssertFalse(store.aadhaarConsent)
        XCTAssertEqual(store.savedAadhaar?.documentType, "EAADHAAR")
        XCTAssertTrue(store.savedAadhaar?.isVerified == true)
        let savedDescription = String(reflecting: store.savedAadhaar)
        for marker in ["123456789012", "XXXX XXXX 9012", "PRIVATE_PHOTO", "PRIVATE_XML"] {
            XCTAssertFalse(savedDescription.contains(marker))
        }
        XCTAssertFalse(store.identityIsVerified, "Trust must remain authoritative, not inferred from availability or a local result")
        let duplicate = await store.verifyAadhaar()
        XCTAssertFalse(duplicate)
        let calls = await service.calls()
        XCTAssertEqual(calls.availability, 1)
        XCTAssertEqual(calls.verification, 1)
        XCTAssertEqual(calls.issuedVerification, 1)
        XCTAssertEqual(calls.connect, 0)
    }

    func testAvailabilitySerializesProviderAndIssuedDocumentActions() async throws {
        let service = try AadhaarStoreServiceStub()
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        await service.suspend(.availability)
        let first = Task { await store.checkAadhaarAvailability() }
        await waitForCall(.availability, service: service)
        XCTAssertEqual(store.aadhaarState, .checking)
        XCTAssertTrue(store.actionInProgress)

        await store.checkAadhaarAvailability()
        let issued = await store.verify([.pan])
        let connection = await store.startConnection()
        XCTAssertFalse(issued)
        XCTAssertNil(connection)
        await service.release(.availability)
        await first.value

        XCTAssertEqual(store.aadhaarState, .available)
        XCTAssertFalse(store.actionInProgress)
        let calls = await service.calls()
        XCTAssertEqual(calls.availability, 1)
        XCTAssertEqual(calls.issuedVerification, 0)
        XCTAssertEqual(calls.connect, 0)
    }

    func testVerificationConsumesConsentAndCannotBeSubmittedTwice() async throws {
        let service = try AadhaarStoreServiceStub()
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        await store.checkAadhaarAvailability()
        store.aadhaarConsent = true
        await service.suspend(.verification)
        let first = Task { await store.verifyAadhaar() }
        await waitForCall(.verification, service: service)
        XCTAssertEqual(store.aadhaarState, .verifying)
        XCTAssertTrue(store.actionInProgress)
        XCTAssertFalse(store.aadhaarConsent)

        let duplicate = await store.verifyAadhaar()
        await store.checkAadhaarAvailability()
        let issued = await store.verify([.drivingLicence])
        let connection = await store.startConnection()
        XCTAssertFalse(duplicate)
        XCTAssertFalse(issued)
        XCTAssertNil(connection)
        await service.release(.verification)
        let completed = await first.value
        XCTAssertTrue(completed)
        XCTAssertFalse(store.actionInProgress)
        let calls = await service.calls()
        XCTAssertEqual(calls.availability, 1)
        XCTAssertEqual(calls.verification, 1)
        XCTAssertEqual(calls.issuedVerification, 0)
        XCTAssertEqual(calls.connect, 0)
    }

    func testCancellationAndIdentityResetDiscardLateAvailabilityAndVerification() async throws {
        for operation: AadhaarStoreServiceStub.Operation in [.availability, .verification] {
            for changesIdentity in [false, true] {
                let service = try AadhaarStoreServiceStub(savedAadhaar: true)
                let store = DigiLockerStore(service: service)
                await store.refreshSummary()
                let previousHistory = store.history
                if operation == .verification { await store.checkAadhaarAvailability() }
                store.aadhaarConsent = true
                await service.suspend(operation)
                let pending = Task {
                    if operation == .availability {
                        await store.checkAadhaarAvailability()
                        return false
                    }
                    return await store.verifyAadhaar()
                }
                await waitForCall(operation, service: service)
                if changesIdentity { store.resetForIdentityChange() }
                else { store.cancelAadhaarOperation() }
                let needsReconciliation = operation == .verification && !changesIdentity
                let expectedState: DigiLockerAadhaarState = needsReconciliation ? .uncertain : .idle
                XCTAssertEqual(store.aadhaarState, expectedState)
                XCTAssertEqual(store.aadhaarNeedsReconciliation, needsReconciliation)
                XCTAssertFalse(store.isReconcilingAadhaar)
                XCTAssertFalse(store.aadhaarConsent)
                XCTAssertFalse(store.actionInProgress)

                // The stub deliberately ignores cancellation and returns a late success.
                await service.release(operation)
                let accepted = await pending.value
                XCTAssertFalse(accepted)
                let observedCancellation = await service.observedCancellation(operation)
                XCTAssertTrue(observedCancellation, "Cancellation must reach the provider task")
                XCTAssertEqual(store.aadhaarState, expectedState)
                XCTAssertEqual(store.aadhaarNeedsReconciliation, needsReconciliation)
                XCTAssertFalse(store.isReconcilingAadhaar)
                XCTAssertFalse(store.actionInProgress)
                XCTAssertFalse(store.aadhaarConsent)
                if changesIdentity {
                    XCTAssertNil(store.status)
                    XCTAssertNil(store.history)
                    XCTAssertNil(store.savedAadhaar)
                } else {
                    XCTAssertEqual(store.history, previousHistory)
                    XCTAssertNotNil(store.savedAadhaar)
                }
            }
        }
    }

    func testInterruptedVerificationBlocksProviderActionsUntilSavedTruthIsRecovered() async throws {
        let service = try AadhaarStoreServiceStub()
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        await store.checkAadhaarAvailability()
        await service.suspend(.verification)
        store.aadhaarConsent = true
        let verification = Task { await store.verifyAadhaar() }
        await waitForCall(.verification, service: service)
        store.cancelAadhaarOperation()
        await service.release(.verification)
        let accepted = await verification.value
        XCTAssertFalse(accepted)
        XCTAssertEqual(store.aadhaarState, .uncertain)
        XCTAssertTrue(store.aadhaarNeedsReconciliation)
        XCTAssertFalse(store.aadhaarConsent)
        XCTAssertNil(store.savedAadhaar, "A late provider response must not update observable state")
        await assertProviderActionsBlocked(store, service: service)

        await service.failSummary()
        await store.reconcileAadhaarSavedResults()
        XCTAssertTrue(store.summaryError)
        XCTAssertTrue(store.aadhaarNeedsReconciliation)
        XCTAssertFalse(store.isReconcilingAadhaar)
        XCTAssertNil(store.savedAadhaar)
        await assertProviderActionsBlocked(store, service: service)

        await service.recoverSummary()
        await service.suspend(.history)
        let reconciliation = Task { await store.reconcileAadhaarSavedResults() }
        await waitForCall(.history, service: service)
        XCTAssertTrue(store.isReconcilingAadhaar)
        XCTAssertTrue(store.actionInProgress)
        XCTAssertTrue(store.aadhaarNeedsReconciliation)
        await assertProviderActionsBlocked(store, service: service)
        await service.release(.history)
        await reconciliation.value

        XCTAssertFalse(store.summaryError)
        XCTAssertFalse(store.aadhaarNeedsReconciliation)
        XCTAssertFalse(store.isReconcilingAadhaar)
        XCTAssertFalse(store.actionInProgress)
        XCTAssertTrue(store.savedAadhaar?.isVerified == true)
        XCTAssertFalse(store.aadhaarConsent)
        let reconciledCalls = await service.calls()
        XCTAssertEqual(reconciledCalls.availability, 1)
        XCTAssertEqual(reconciledCalls.verification, 1)
        XCTAssertEqual(reconciledCalls.history, 3)
        XCTAssertEqual(reconciledCalls.status, 3)
        XCTAssertEqual(reconciledCalls.trust, 3)

        await store.checkAadhaarAvailability()
        XCTAssertEqual(store.aadhaarState, .available)
        XCTAssertFalse(store.aadhaarConsent)
        let unconsented = await store.verifyAadhaar()
        XCTAssertFalse(unconsented)
        let finalCalls = await service.calls()
        XCTAssertEqual(finalCalls.availability, 2)
        XCTAssertEqual(finalCalls.verification, 1)
    }

    func testEarlierOverlappingRefreshCannotOverwriteFinalVerificationResult() async throws {
        let service = try AadhaarStoreServiceStub()
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        await store.checkAadhaarAvailability()
        await service.suspend(.verification)
        store.aadhaarConsent = true
        let verification = Task { await store.verifyAadhaar() }
        await waitForCall(.verification, service: service)

        // Capture empty history before verification commits, then deliver it late.
        await service.suspend(.history)
        let earlierRefresh = Task { await store.refreshSummary() }
        await waitForCall(.history, service: service)
        await service.release(.verification)
        await waitForReconciliation(store)
        XCTAssertTrue(store.isLoadingSummary)
        XCTAssertTrue(store.aadhaarNeedsReconciliation)
        XCTAssertTrue(store.savedAadhaar?.isVerified == true)
        let waitingCalls = await service.calls()
        XCTAssertEqual(waitingCalls.history, 2, "Reconciliation must wait for the earlier read")
        await assertProviderActionsBlocked(store, service: service)

        await service.release(.history)
        await earlierRefresh.value
        let accepted = await verification.value
        XCTAssertTrue(accepted)
        XCTAssertEqual(store.aadhaarState, .verified)
        XCTAssertTrue(store.savedAadhaar?.isVerified == true)
        XCTAssertEqual(store.history?.items.map(\.documentType), ["EAADHAAR"])
        XCTAssertFalse(store.aadhaarNeedsReconciliation)
        XCTAssertFalse(store.isReconcilingAadhaar)
        XCTAssertFalse(store.actionInProgress)
        let finalCalls = await service.calls()
        XCTAssertEqual(finalCalls.history, 3, "A fresh saved-history read must follow the older response")
        XCTAssertEqual(finalCalls.status, 3)
        XCTAssertEqual(finalCalls.trust, 3)
        XCTAssertEqual(finalCalls.availability, 1)
        XCTAssertEqual(finalCalls.verification, 1)
        XCTAssertEqual(finalCalls.connect, 0)
    }

    func testIdentityResetDuringReconciliationDiscardsLateSavedTruthAndClearsFlags() async throws {
        let service = try AadhaarStoreServiceStub()
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        await store.checkAadhaarAvailability()
        await service.suspend(.history)
        store.aadhaarConsent = true
        let verification = Task { await store.verifyAadhaar() }
        await waitForCall(.history, service: service)
        XCTAssertTrue(store.isReconcilingAadhaar)
        XCTAssertTrue(store.aadhaarNeedsReconciliation)
        store.resetForIdentityChange()
        XCTAssertEqual(store.aadhaarState, .idle)
        XCTAssertFalse(store.aadhaarNeedsReconciliation)
        XCTAssertFalse(store.isReconcilingAadhaar)
        await service.release(.history)
        let accepted = await verification.value
        XCTAssertFalse(accepted)
        XCTAssertEqual(store.aadhaarState, .idle)
        XCTAssertFalse(store.aadhaarNeedsReconciliation)
        XCTAssertFalse(store.isReconcilingAadhaar)
        XCTAssertFalse(store.actionInProgress)
        XCTAssertFalse(store.aadhaarConsent)
        XCTAssertNil(store.status)
        XCTAssertNil(store.history)
        XCTAssertNil(store.savedAadhaar)
    }

    func testConnectionChangeClearsConsentAndRetainsSavedAadhaar() async throws {
        let service = try AadhaarStoreServiceStub(savedAadhaar: true)
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        let saved = store.savedAadhaar
        await store.checkAadhaarAvailability()
        store.aadhaarConsent = true
        await service.setStatus(.init(connected: false, status: .reconnectRequired))
        await store.refreshAll()

        XCTAssertEqual(store.aadhaarState, .idle)
        XCTAssertFalse(store.aadhaarConsent)
        XCTAssertEqual(store.savedAadhaar, saved)
        await store.checkAadhaarAvailability()
        let verified = await store.verifyAadhaar()
        XCTAssertFalse(verified)
        let calls = await service.calls()
        XCTAssertEqual(calls.availability, 1)
        XCTAssertEqual(calls.verification, 0)
    }

    func testNotLinkedAvailabilityDoesNotEraseHistoryOrAllowVerification() async throws {
        let service = try AadhaarStoreServiceStub(savedAadhaar: true, available: false)
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        let saved = store.history
        await store.checkAadhaarAvailability()
        XCTAssertEqual(store.aadhaarState, .notLinked)
        XCTAssertEqual(store.history, saved)
        store.aadhaarConsent = true
        let verified = await store.verifyAadhaar()
        XCTAssertFalse(verified)
        let calls = await service.calls()
        XCTAssertEqual(calls.verification, 0)
    }

    func testSummaryFailurePreservesSavedHistoryAndBlocksProviderActions() async throws {
        let service = try AadhaarStoreServiceStub(savedAadhaar: true)
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        let saved = store.history
        await service.failSummary()
        await store.refreshAll()
        XCTAssertTrue(store.summaryError)
        XCTAssertEqual(store.history, saved)
        XCTAssertNotNil(store.savedAadhaar)
        await store.checkAadhaarAvailability()
        store.aadhaarConsent = true
        let verified = await store.verifyAadhaar()
        XCTAssertFalse(verified)
        let calls = await service.calls()
        XCTAssertEqual(calls.availability, 0)
        XCTAssertEqual(calls.verification, 0)
    }

    func testAvailabilityErrorsUseSafeStatesWithoutRetryAndPreserveHistory() async throws {
        let cases: [(String, Int, DigiLockerAadhaarState)] = [
            ("digilocker_aadhaar_not_linked", 400, .notLinked),
            ("not_found", 404, .unavailable),
            ("digilocker_insufficient_scope", 403, .accessUnavailable),
            ("digilocker_account_unavailable", 400, .accessUnavailable),
            ("forbidden", 403, .accessUnavailable),
            ("digilocker_invalid_token", 400, .reconnectRequired),
            ("digilocker_reconnect_required", 400, .reconnectRequired),
            ("digilocker_integrity_failed", 503, .integrityFailure),
            ("unauthorized", 401, .reconnectRequired),
            ("digilocker_not_configured", 503, .uncertain),
            ("digilocker_provider_unavailable", 503, .uncertain)
        ]
        for (code, status, expected) in cases {
            let service = try AadhaarStoreServiceStub(savedAadhaar: true)
            await service.fail(.availability, with: backendFailure(code, status: status))
            let store = DigiLockerStore(service: service)
            await store.refreshSummary()
            let previousHistory = store.history
            await store.checkAadhaarAvailability()

            XCTAssertEqual(store.aadhaarState, expected, code)
            XCTAssertEqual(store.history, previousHistory, code)
            XCTAssertFalse(store.actionInProgress)
            assertSafe(store.aadhaarState.message)
            let calls = await service.calls()
            XCTAssertEqual(calls.availability, 1, code)
            XCTAssertEqual(calls.verification, 0, code)
            XCTAssertEqual(calls.connect, 0, code)
        }
    }

    func testUncertainVerificationRefreshesSavedTruthWithoutRepeatingProviderOperation() async throws {
        let errors: [any Error & Sendable] = [
            URLError(.timedOut), DigiLockerServiceError.invalidResponse,
            NetworkError.transport("PRIVATE_PROVIDER_BODY HMAC 123456789012")
        ]
        for error in errors {
            let service = try AadhaarStoreServiceStub(savedAadhaar: true)
            let store = DigiLockerStore(service: service)
            await store.refreshSummary()
            let previousHistory = store.history
            await store.checkAadhaarAvailability()
            await service.fail(.verification, with: error)
            let before = await service.calls()
            store.aadhaarConsent = true
            _ = await store.verifyAadhaar()

            XCTAssertEqual(store.aadhaarState, .uncertain)
            XCTAssertFalse(store.aadhaarConsent)
            XCTAssertFalse(store.actionInProgress)
            XCTAssertEqual(store.history, previousHistory)
            assertSafe(store.aadhaarState.message)
            let after = await service.calls()
            XCTAssertEqual(after.availability, 1)
            XCTAssertEqual(after.verification, 1)
            XCTAssertEqual(after.status, before.status + 1)
            XCTAssertEqual(after.history, before.history + 1)
            XCTAssertEqual(after.trust, before.trust + 1)
            XCTAssertEqual(after.connect, 0)
        }
    }

    func testCorruptedOrNonmatchingAadhaarCannotProjectVerified() async throws {
        let variants = [
            (false, "VERIFIED_MATCH", "verified", "\"2026-10-01T10:00:00Z\""),
            (true, "PARTIAL_MATCH", "verified", "\"2026-10-01T10:00:00Z\""),
            (true, "MISMATCH", "verified", "\"2026-10-01T10:00:00Z\""),
            (true, "UNABLE_TO_VERIFY", "verified", "\"2026-10-01T10:00:00Z\""),
            (true, "VERIFIED_MATCH", "failed", "\"2026-10-01T10:00:00Z\""),
            (true, "VERIFIED_MATCH", "verified", "\"2099-10-01T10:00:00Z\""),
            (true, "VERIFIED_MATCH", "verified", "\"1970-01-01T00:00:00Z\""),
            (true, "VERIFIED_MATCH", "verified", "null")
        ]
        for (current, match, integrity, date) in variants {
            let result = try APIJSONCoder.makeDecoder().decode(DigiLockerVerificationDTO.self, from: Data("""
            {"document_type":"EAADHAAR","source":"digilocker","source_type":"eaadhaar",
             "current":\(current),"match_result":"\(match)","match_reason":null,
             "integrity_result":"\(integrity)","verified_at":\(date)}
            """.utf8))
            XCTAssertFalse(result.isVerified)
            let service = try AadhaarStoreServiceStub(result: result)
            let store = DigiLockerStore(service: service)
            await store.refreshSummary()
            await store.checkAadhaarAvailability()
            store.aadhaarConsent = true
            _ = await store.verifyAadhaar()
            XCTAssertEqual(store.aadhaarState, .needsReview)
            XCTAssertFalse(store.savedAadhaar?.isVerified == true)
        }
    }

    private func backendFailure(_ code: String, status: Int) -> DigiLockerBackendError {
        let body = Data("""
        {"error":{"code":"\(code)","message":"PRIVATE_PROVIDER_BODY HMAC 123456789012 entitlement-debug"}}
        """.utf8)
        return DigiLockerBackendError.decode(from: body, statusCode: status)
    }

    private func assertSafe(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(message.isEmpty, file: file, line: line)
        for forbidden in ["PRIVATE_PROVIDER_BODY", "HMAC", "123456789012", "entitlement", "digilocker_", "403", "404", "503"] {
            XCTAssertFalse(message.localizedCaseInsensitiveContains(forbidden), file: file, line: line)
        }
    }

    private func waitForCall(_ operation: AadhaarStoreServiceStub.Operation, service: AadhaarStoreServiceStub) async {
        for _ in 0..<200 {
            if await service.isSuspended(operation) { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Expected the provider operation to reach its suspension point")
    }

    private func waitForReconciliation(_ store: DigiLockerStore) async {
        for _ in 0..<200 {
            if store.isReconcilingAadhaar { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Expected reconciliation to wait for the earlier saved-results read")
    }

    private func assertProviderActionsBlocked(_ store: DigiLockerStore, service: AadhaarStoreServiceStub) async {
        let before = await service.calls()
        await store.checkAadhaarAvailability()
        let aadhaar = await store.verifyAadhaar()
        let issued = await store.verify([.pan])
        let connection = await store.startConnection()
        XCTAssertFalse(aadhaar)
        XCTAssertFalse(issued)
        XCTAssertNil(connection)
        let after = await service.calls()
        XCTAssertEqual(after.availability, before.availability)
        XCTAssertEqual(after.verification, before.verification)
        XCTAssertEqual(after.issuedVerification, before.issuedVerification)
        XCTAssertEqual(after.connect, before.connect)
    }
}

private actor AadhaarStoreServiceStub: DigiLockerServiceProtocol {
    nonisolated enum Operation: Hashable, Sendable { case availability, verification, history }
    nonisolated struct Calls: Sendable {
        var availability = 0
        var verification = 0
        var issuedVerification = 0
        var connect = 0
        var status = 0
        var history = 0
        var trust = 0
    }

    private var counts = Calls()
    private var connection = DigiLockerStatusDTO(connected: true, status: .active)
    private var historyValue: DigiLockerVerificationHistoryDTO
    private let availabilityValue: DigiLockerAadhaarAvailabilityDTO
    private let verificationValue: DigiLockerVerificationDTO
    private var failures: [Operation: any Error & Sendable] = [:]
    private var summaryFails = false
    private var cancelledOperations: Set<Operation> = []
    private var suspended: Set<Operation> = []
    private var continuations: [Operation: CheckedContinuation<Void, Never>] = [:]

    init(savedAadhaar: Bool = false, available: Bool = true, result: DigiLockerVerificationDTO? = nil) throws {
        let decoder = APIJSONCoder.makeDecoder()
        availabilityValue = try decoder.decode(DigiLockerAadhaarAvailabilityDTO.self, from: Data("""
        {"available":\(available),"entitlement_confirmed":false}
        """.utf8))
        verificationValue = try result ?? decoder.decode(DigiLockerVerificationDTO.self, from: Data("""
        {"document_type":"EAADHAAR","source":"digilocker","source_type":"eaadhaar","current":true,
         "match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified",
         "verified_at":"2026-10-01T10:00:00Z","document_number":"123456789012",
         "masked_number":"XXXX XXXX 9012","photo":"PRIVATE_PHOTO","xml":"PRIVATE_XML"}
        """.utf8))
        historyValue = .init(items: savedAadhaar ? [verificationValue] : [], identityVerified: false)
    }

    func calls() -> Calls { counts }
    func failSummary() { summaryFails = true }
    func recoverSummary() { summaryFails = false }
    func observedCancellation(_ operation: Operation) -> Bool { cancelledOperations.contains(operation) }
    func setStatus(_ value: DigiLockerStatusDTO) { connection = value }
    func fail(_ operation: Operation, with error: any Error & Sendable) { failures[operation] = error }
    func suspend(_ operation: Operation) { suspended.insert(operation) }
    func isSuspended(_ operation: Operation) -> Bool { continuations[operation] != nil }
    func release(_ operation: Operation) {
        suspended.remove(operation)
        continuations.removeValue(forKey: operation)?.resume()
    }
    private func pauseIfNeeded(_ operation: Operation) async {
        if suspended.contains(operation) {
            await withCheckedContinuation { continuations[operation] = $0 }
        }
        if Task.isCancelled { cancelledOperations.insert(operation) }
    }

    func status() async throws -> DigiLockerStatusDTO {
        counts.status += 1
        if summaryFails { throw DigiLockerBackendError(statusCode: 503, code: .notConfigured) }
        return connection
    }
    func connect() async throws -> DigiLockerConnectResponseDTO {
        counts.connect += 1
        throw DigiLockerServiceError.invalidAuthorizationURL
    }
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO { .init(items: []) }
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO {
        counts.history += 1
        let snapshot = historyValue
        await pauseIfNeeded(.history)
        return snapshot
    }
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO {
        counts.trust += 1
        return .init(state: .unverified, sources: [])
    }
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        counts.issuedVerification += 1
        return historyValue
    }
    func aadhaarAvailability() async throws -> DigiLockerAadhaarAvailabilityDTO {
        counts.availability += 1
        await pauseIfNeeded(.availability)
        if let failure = failures[.availability] { throw failure }
        return availabilityValue
    }
    func verifyAadhaar() async throws -> DigiLockerVerificationDTO {
        counts.verification += 1
        await pauseIfNeeded(.verification)
        if let failure = failures[.verification] { throw failure }
        historyValue = .init(items: [verificationValue], identityVerified: false)
        return verificationValue
    }
}
