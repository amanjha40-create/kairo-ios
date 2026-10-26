import Foundation

nonisolated enum ResumePresentationContext: Equatable, Sendable {
    case onboarding
    case authenticated
}

nonisolated enum ResumeCareerAction: Equatable, Sendable {
    case loading
    case importResume
    case processing(resumeID: String)
    case continueReview(resumeID: String, reviewID: String?)
    case retry(resumeID: String)
    case unavailable

    static func resolve(_ snapshot: ResumeImportWorkflowSnapshot?) -> ResumeCareerAction {
        guard let snapshot else { return .importResume }

        switch snapshot.resume.processingStatus {
        case .pendingUpload, .uploaded, .queued, .extracting, .extracted, .parsing:
            return .processing(resumeID: snapshot.resume.id)
        case .needsReview:
            if snapshot.isImported || snapshot.reviewSession?.status == .cancelled {
                return .importResume
            }
            return .continueReview(
                resumeID: snapshot.resume.id,
                reviewID: snapshot.reviewSession?.id
            )
        case .failed:
            return .retry(resumeID: snapshot.resume.id)
        case .cancelled, .deleted:
            return .importResume
        case .unknown:
            return .unavailable
        }
    }

    static func resolveLatest(_ snapshots: [ResumeImportWorkflowSnapshot]) -> ResumeCareerAction {
        let latest = snapshots
            .filter {
                $0.resume.uploadStatus != .deleted && $0.resume.processingStatus != .deleted
            }
            .sorted { $0.resume.createdAt > $1.resume.createdAt }
            .first
        return resolve(latest)
    }

    var title: String {
        switch self {
        case .loading: "Checking resume status"
        case .importResume: "Import resume"
        case .processing: "View resume processing"
        case .continueReview: "Continue resume review"
        case .retry: "Resume needs attention"
        case .unavailable: "Resume status unavailable"
        }
    }

    var message: String {
        switch self {
        case .loading: "Checking your latest resume before offering another upload."
        case .importResume: "Upload a resume and review every claim before adding it to Career."
        case .processing: "Your latest resume is still being processed."
        case .continueReview: "Return to the same saved review and continue where you left off."
        case .retry: "Open the existing resume to review the failure and available retry action."
        case .unavailable: "KairoID couldn't confirm your latest resume state. Try again before uploading."
        }
    }

    var resumeID: String? {
        switch self {
        case .processing(let resumeID), .continueReview(let resumeID, _), .retry(let resumeID):
            resumeID
        case .loading, .importResume, .unavailable:
            nil
        }
    }

    var isEnabled: Bool {
        switch self {
        case .importResume, .processing, .continueReview, .retry: true
        case .loading, .unavailable: false
        }
    }
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
    func deleteResume(resumeID: String) async throws {
        throw NetworkError.unavailableInDemoMode
    }

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
