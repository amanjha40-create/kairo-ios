import XCTest
@testable import Kairo

@MainActor
final class ResumeDeletionStateTests: XCTestCase {
    private let previous = ResumeDeletionTarget(id: "previous", filename: "same-name.pdf")

    func testCancelKeepsHistoryAndMakesNoRequest() async throws {
        let state = ResumeDeletionState()
        let service = UITestResumeImportService(scenario: .managementHistory)
        state.requestConfirmation(previous); state.cancel()
        XCTAssertNil(state.beginDeletion())
        let page = try await service.resumeHistory(offset: 0, limit: 20)
        let calls = await service.deleteCalls
        XCTAssertEqual(page.total, 3); XCTAssertTrue(calls.isEmpty)
    }

    func testExactPreviousDeletionRefreshesHistoryAndPreservesOtherImports() async throws {
        let state = ResumeDeletionState()
        let service = UITestResumeImportService(scenario: .managementHistory)
        state.requestConfirmation(previous)
        let operation = try XCTUnwrap(state.beginDeletion())
        XCTAssertNil(state.beginDeletion())
        state.requestConfirmation(.init(id: "current", filename: "same-name.pdf"))
        XCTAssertNil(state.confirmation)
        let page = await state.performDeletion(operation, using: service)
        let calls = await service.deleteCalls
        XCTAssertEqual(calls, ["previous"])
        XCTAssertEqual(page?.entries.map(\.resume.id), ["current", "failed"])
        XCTAssertEqual(state.message, "Resume deleted. Imported Career records were not deleted.")
        XCTAssertFalse(state.isDeleting); XCTAssertFalse(state.needsReconciliation)
        // State depends only on Resume service; it has no Career/Auth/Trust mutation dependency.
        let duplicate = await state.performDeletion(operation, using: service)
        XCTAssertNil(duplicate)
    }

    func testLastDeletionReturnsAuthoritativeEmptyHistory() async throws {
        let state = ResumeDeletionState()
        let service = UITestResumeImportService(scenario: .managementHistory, singleResume: true)
        state.requestConfirmation(.init(id: "current", filename: "synthetic.pdf"))
        let operation = try XCTUnwrap(state.beginDeletion())
        let page = await state.performDeletion(operation, using: service)
        XCTAssertEqual(page?.total, 0); XCTAssertEqual(page?.entries, [])
    }

    func testFailureKeepsHistoryAndDoesNotExposeRawMessage() async throws {
        let state = ResumeDeletionState()
        let service = UITestResumeImportService(scenario: .managementHistory, deleteMode: "failure")
        state.requestConfirmation(previous)
        let operation = try XCTUnwrap(state.beginDeletion())
        let page = await state.performDeletion(operation, using: service)
        XCTAssertEqual(page?.total, 3)
        XCTAssertTrue(state.message?.contains("still available") == true)
        XCTAssertFalse(state.message?.contains("Synthetic") == true)
        let calls = await service.deleteCalls; XCTAssertEqual(calls.count, 1)
    }

    func testAmbiguousCommittedResultUses404WithoutClaimingDeleteSuccess() async throws {
        let state = ResumeDeletionState()
        let service = UITestResumeImportService(scenario: .managementHistory, deleteMode: "ambiguous")
        state.requestConfirmation(previous)
        let operation = try XCTUnwrap(state.beginDeletion())
        let page = await state.performDeletion(operation, using: service)
        XCTAssertEqual(page?.total, 2)
        XCTAssertTrue(state.message?.contains("no longer available") == true)
        XCTAssertFalse(state.message?.contains("Resume deleted") == true)
        let calls = await service.deleteCalls; XCTAssertEqual(calls, ["previous"])
    }

    func testUnresolvedResultBlocksDeleteAndOnlyRechecksReadOnly() async throws {
        let state = ResumeDeletionState()
        let service = UITestResumeImportService(scenario: .managementHistory, deleteMode: "unavailable")
        state.requestConfirmation(previous)
        let operation = try XCTUnwrap(state.beginDeletion())
        let page = await state.performDeletion(operation, using: service)
        XCTAssertNil(page); XCTAssertTrue(state.needsReconciliation)
        state.requestConfirmation(previous); XCTAssertNil(state.beginDeletion())
        _ = await state.reconcile(using: service)
        let calls = await service.deleteCalls; XCTAssertEqual(calls, ["previous"])
        XCTAssertTrue(state.needsReconciliation); XCTAssertFalse(state.isDeleting)
    }
}
