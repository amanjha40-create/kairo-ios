import XCTest
@testable import Kairo

final class ResumeManagementStateTests: XCTestCase {
    func testUnknownAndPendingUploadNeverOfferUnsupportedReview() {
        let unknown = snapshot(.unknown)
        XCTAssertEqual(unknown.historyStatus, "Status unavailable")
        XCTAssertTrue(unknown.isReadOnlyHistory)
        XCTAssertTrue(snapshot(.pendingUpload).isReadOnlyHistory)
    }

    func testHistoryStatusesNeverImplyVerificationOrTrust() {
        for status in [ResumeProcessingStatus.uploaded, .queued, .extracting, .parsing, .needsReview, .failed, .cancelled] {
            let entry = snapshot(status)
            XCTAssertFalse(entry.historyStatus.lowercased().contains("verified"))
            XCTAssertFalse(entry.historyStatus.lowercased().contains("score"))
        }
    }

    func testBackendPaginationHasNoFabricatedHistory() {
        let page = ResumeHistoryPage(entries: [snapshot(.failed)], total: 25, offset: 20)
        XCTAssertEqual(page.nextOffset, 21)
        XCTAssertTrue(page.hasMore)
        XCTAssertFalse(ResumeHistoryPage(entries: [], total: 25, offset: 25).hasMore)
    }

    func testRestorationKeepsExactIdentityAndRetryDoesNotCreateAnotherSelection() {
        var state = ResumeImportState()
        state.applyRestoredWorkflow(snapshot(.failed))
        XCTAssertEqual(state.liveResume?.id, "selected-history-id")
        XCTAssertTrue(state.canRetry)
        state.retryProcessing()
        XCTAssertEqual(state.liveResume?.id, "selected-history-id")
        XCTAssertNil(state.selectedTemporaryFileURL)
        XCTAssertFalse(state.canPrepareResume)
    }

    private func snapshot(_ status: ResumeProcessingStatus) -> ResumeImportWorkflowSnapshot {
        ResumeImportWorkflowSnapshot(resume: ResumeRecord(id: "selected-history-id", originalFilename: "synthetic.pdf",
            contentType: "application/pdf", fileSizeBytes: 128, uploadStatus: .uploaded, processingStatus: status,
            createdAt: .distantPast, updatedAt: .distantPast), reviewSession: nil, importBatch: nil)
    }
}
