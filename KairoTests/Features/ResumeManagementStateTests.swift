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

    func testCareerActionContinuesTheExactAuthoritativeReview() {
        let action = ResumeCareerAction.resolve(snapshot(.needsReview, reviewStatus: .reviewing))
        XCTAssertEqual(action, .continueReview(resumeID: "selected-history-id", reviewID: "review-id"))
        XCTAssertEqual(action.title, "Continue resume review")
    }

    func testCareerActionRoutesProcessingAndFailureWithoutOfferingUpload() {
        for status in [ResumeProcessingStatus.pendingUpload, .uploaded, .queued, .extracting, .extracted, .parsing] {
            XCTAssertEqual(
                ResumeCareerAction.resolve(snapshot(status)),
                .processing(resumeID: "selected-history-id")
            )
        }
        XCTAssertEqual(
            ResumeCareerAction.resolve(snapshot(.failed)),
            .retry(resumeID: "selected-history-id")
        )
    }

    func testCareerActionOffersUploadOnlyWhenNoActiveResumeRemains() {
        XCTAssertEqual(ResumeCareerAction.resolve(nil), .importResume)
        XCTAssertEqual(ResumeCareerAction.resolve(snapshot(.deleted)), .importResume)
        XCTAssertEqual(ResumeCareerAction.resolve(snapshot(.cancelled)), .importResume)
    }

    func testImportedReviewClearsStaleContinueAction() {
        XCTAssertEqual(
            ResumeCareerAction.resolve(snapshot(.needsReview, reviewStatus: .imported)),
            .importResume
        )
        XCTAssertEqual(
            ResumeCareerAction.resolve(
                snapshot(.needsReview, reviewStatus: .reviewing, importCompleted: true)
            ),
            .importResume
        )
    }

    func testUnknownBackendStateFailsClosedInsteadOfStartingDuplicateUpload() {
        let action = ResumeCareerAction.resolve(snapshot(.unknown))
        XCTAssertEqual(action, .unavailable)
        XCTAssertFalse(action.isEnabled)
    }

    func testLatestSelectionIgnoresDeletedRowsAndUsesNewestRemainingWorkflow() {
        let deleted = snapshot(.deleted, createdAt: Date(timeIntervalSince1970: 200))
        let review = snapshot(
            .needsReview,
            reviewStatus: .reviewing,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(
            ResumeCareerAction.resolveLatest([deleted, review]),
            .continueReview(resumeID: "selected-history-id", reviewID: "review-id")
        )
    }

    private func snapshot(
        _ status: ResumeProcessingStatus,
        reviewStatus: ResumeReviewStatus? = nil,
        importCompleted: Bool = false,
        createdAt: Date = .distantPast
    ) -> ResumeImportWorkflowSnapshot {
        let review = reviewStatus.map {
            ResumeReviewSession(
                id: "review-id",
                resumeID: "selected-history-id",
                parsedResultID: "parsed-id",
                status: $0,
                schemaVersion: "resume_review_v1",
                version: 1,
                items: [],
                createdAt: .distantPast,
                updatedAt: .distantPast
            )
        }
        let batch = importCompleted ? ResumeImportBatch(
            id: "batch-id",
            reviewSessionID: "review-id",
            status: "completed",
            totalCount: 1,
            importedCount: 1,
            linkedCount: 0,
            skippedCount: 0,
            failedCount: 0,
            blockedCount: 0,
            incompleteCount: 0,
            entityCounts: [:],
            results: [],
            createdAt: .distantPast,
            updatedAt: .distantPast
        ) : nil
        return ResumeImportWorkflowSnapshot(resume: ResumeRecord(id: "selected-history-id", originalFilename: "synthetic.pdf",
            contentType: "application/pdf", fileSizeBytes: 128, uploadStatus: .uploaded, processingStatus: status,
            createdAt: createdAt, updatedAt: createdAt), reviewSession: review, importBatch: batch)
    }
}
