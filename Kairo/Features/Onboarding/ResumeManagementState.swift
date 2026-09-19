import Foundation

nonisolated enum ResumePresentationContext: Equatable, Sendable {
    case onboarding
    case authenticated
}

nonisolated struct ResumeHistoryPage: Equatable, Sendable {
    let entries: [ResumeImportWorkflowSnapshot]
    let total: Int
    let offset: Int
    var nextOffset: Int { offset + entries.count }
    var hasMore: Bool { !entries.isEmpty && nextOffset < total }
}

extension ResumeImportWorkflowSnapshot {
    nonisolated var historyStatus: String {
        if reviewSession?.status == .imported || importBatch?.isCompletedWithoutHardFailures == true {
            return "Imported"
        }
        if reviewSession?.status == .partiallyImported || importBatch?.isPartiallyCompleted == true {
            return "Partially imported — review needed"
        }
        if reviewSession?.status == .importing { return "Importing approved claims" }
        if reviewSession?.status == .cancelled { return "Review cancelled" }
        if reviewSession?.status == .failed { return "Import needs attention" }
        if reviewSession?.status == .unknown { return "Review status unavailable" }
        if reviewSession?.status == .readyToImport { return "Ready to import" }
        if resume.processingStatus == .unknown { return "Status unavailable" }
        return resume.processingStatus.title
    }

    nonisolated var isImported: Bool {
        reviewSession?.status == .imported || importBatch?.isCompletedWithoutHardFailures == true
    }

    nonisolated var isReadOnlyHistory: Bool {
        isImported || [.pendingUpload, .deleted, .unknown].contains(resume.processingStatus) ||
            reviewSession.map { [.cancelled, .unknown].contains($0.status) } == true
    }
}

extension ResumeImportServiceProtocol {
    // Non-live implementations must explicitly provide history. Never manufacture backend history.
    func resumeHistory(offset: Int, limit: Int) async throws -> ResumeHistoryPage {
        throw NetworkError.unavailableInDemoMode
    }

    func restoreWorkflow(resumeID: String) async throws -> ResumeImportWorkflowSnapshot {
        throw NetworkError.unavailableInDemoMode
    }

    func reconcileImportRecovery(
        reviewID: String, context: ResumePresentationContext
    ) async throws -> ResumeImportRecoveryState {
        if context == .onboarding { return try await reconcileImportRecovery(reviewID: reviewID) }
        let review = try await refreshReviewSession(reviewID: reviewID)
        var batch: ResumeImportBatch?
        if [.importing, .imported, .partiallyImported].contains(review.status) {
            do { batch = try await latestImportStatus(reviewID: reviewID) }
            catch let error as NetworkError {
                guard case .api(let response) = error, response.statusCode == 404 else { throw error }
            }
        }
        let disposition: ResumeImportRecoveryDisposition
        if review.status == .imported || batch?.isCompletedWithoutHardFailures == true {
            disposition = .importCompleted
        } else if review.status == .partiallyImported || batch?.isPartiallyCompleted == true {
            disposition = .importPartiallyCompleted
        } else if review.status == .importing, batch != nil {
            disposition = .importInProgress
        } else {
            disposition = .noImportToResume
        }
        return ResumeImportRecoveryState(reviewSession: review, importBatch: batch,
                                         completionResult: nil, disposition: disposition)
    }
}
