import Foundation

nonisolated enum ResumeUploadStatus: String, Equatable, Sendable {
    case pendingUpload = "pending_upload"
    case uploaded
    case deleted
    case unknown

    init(apiValue: String) {
        self = ResumeUploadStatus(rawValue: apiValue) ?? .unknown
    }
}

nonisolated enum ResumeProcessingStatus: String, Equatable, Sendable {
    case pendingUpload = "pending_upload"
    case uploaded
    case queued
    case extracting
    case extracted
    case parsing
    case needsReview = "needs_review"
    case failed
    case cancelled
    case deleted
    case unknown

    init(apiValue: String) {
        self = ResumeProcessingStatus(rawValue: apiValue) ?? .unknown
    }

    var isTerminal: Bool {
        switch self {
        case .needsReview, .failed, .cancelled, .deleted:
            true
        default:
            false
        }
    }

    var title: String {
        switch self {
        case .pendingUpload:
            "Preparing your upload"
        case .uploaded:
            "Upload complete"
        case .queued:
            "Queued for processing"
        case .extracting:
            "Extracting your resume"
        case .extracted:
            "Preparing parsed claims"
        case .parsing:
            "Organising your professional history"
        case .needsReview:
            "Ready for review"
        case .failed:
            "We couldn't process that resume"
        case .cancelled:
            "Resume processing cancelled"
        case .deleted:
            "Resume removed"
        case .unknown:
            "Processing resume"
        }
    }

    var message: String {
        switch self {
        case .pendingUpload:
            "Kairo is preparing a secure upload for your resume."
        case .uploaded:
            "Your file is uploaded. Kairo is about to start parsing it."
        case .queued:
            "Your resume is queued for backend processing."
        case .extracting:
            "Kairo is extracting structured information from your file."
        case .extracted:
            "Kairo is turning extracted content into reviewable candidate claims."
        case .parsing:
            "Review-first candidate claims are being prepared for your approval."
        case .needsReview:
            "Your parsed resume is ready. Review each claim before anything is imported."
        case .failed:
            "Kairo couldn't parse this resume. You can retry or choose a different file."
        case .cancelled:
            "This resume is no longer being processed."
        case .deleted:
            "This resume was removed."
        case .unknown:
            "Kairo is processing your resume."
        }
    }
}

nonisolated struct ResumeRecord: Equatable, Sendable {
    let id: String
    let originalFilename: String
    let contentType: String
    let fileSizeBytes: Int
    let uploadStatus: ResumeUploadStatus
    let processingStatus: ResumeProcessingStatus
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct ResumeUploadIntent: Equatable, Sendable {
    let resumeID: String
    let uploadURL: URL
    let expiresIn: Int
    let objectKey: String
}

nonisolated struct ResumeProcessJob: Equatable, Sendable {
    let resumeID: String
    let jobID: String
    let status: ResumeProcessingStatus
}

nonisolated struct ResumeParsedResult: Equatable, Sendable {
    let resumeID: String
    let jobID: String
    let schemaVersion: String
    let status: String
    let structuredResult: [String: JSONValue]
    let warnings: [String]
}

nonisolated enum ResumeReviewStatus: String, Equatable, Sendable {
    case draft
    case reviewing
    case readyToImport = "ready_to_import"
    case importing
    case partiallyImported = "partially_imported"
    case imported
    case cancelled
    case failed
    case unknown

    init(apiValue: String) {
        self = ResumeReviewStatus(rawValue: apiValue) ?? .unknown
    }
}

nonisolated enum ResumeImportAction: String, Equatable, Sendable {
    case createNew = "create_new"
    case skip
    case linkExisting = "link_existing"
    case updateExisting = "update_existing"
    case none
    case unknown

    init(apiValue: String) {
        self = ResumeImportAction(rawValue: apiValue) ?? .unknown
    }

    var title: String {
        switch self {
        case .createNew:
            "Create new"
        case .skip:
            "Excluded"
        case .linkExisting:
            "Link existing"
        case .updateExisting:
            "Update existing"
        case .none, .unknown:
            "Pending decision"
        }
    }
}

nonisolated enum ResumeDuplicateStatus: String, Equatable, Sendable {
    case noMatch = "no_match"
    case possibleMatch = "possible_match"
    case probableMatch = "probable_match"
    case exactMatch = "exact_match"
    case conflict
    case unknown

    init(apiValue: String) {
        self = ResumeDuplicateStatus(rawValue: apiValue) ?? .unknown
    }

    var title: String {
        switch self {
        case .noMatch:
            "No match"
        case .possibleMatch:
            "Possible match"
        case .probableMatch:
            "Probable match"
        case .exactMatch:
            "Exact match"
        case .conflict:
            "Conflict"
        case .unknown:
            "Pending match review"
        }
    }
}

nonisolated struct ResumeReviewItem: Equatable, Sendable, Identifiable {
    let id: String
    let claimType: String
    let sourceClaimID: String
    let originalPayload: [String: JSONValue]
    let editedPayload: [String: JSONValue]
    let selected: Bool
    let reviewStatus: String
    let duplicateStatus: ResumeDuplicateStatus
    let duplicateCandidates: [[String: JSONValue]]
    let conflictWarnings: [String]
    let importAction: ResumeImportAction
    let targetRecordID: String?
    let importedRecordType: String?
    let importedRecordID: String?
    let sourceReference: String?
    let confidence: Double?
    let version: Int
}

nonisolated struct ResumeReviewSession: Equatable, Sendable {
    let id: String
    let resumeID: String
    let parsedResultID: String
    let status: ResumeReviewStatus
    let schemaVersion: String
    let version: Int
    let items: [ResumeReviewItem]
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct ResumeReviewPlanItem: Equatable, Sendable, Identifiable {
    let itemID: String
    let claimType: String
    let action: String
    let targetModel: String?
    let duplicateStatus: ResumeDuplicateStatus
    let targetRecordID: String?
    let fieldsToCreate: [String]
    let fieldsIgnored: [String]
    let blockers: [String]
    let warnings: [String]
    let verifiedRecordProtected: Bool

    var id: String { itemID }
}

nonisolated struct ResumeReviewPlan: Equatable, Sendable {
    let sessionID: String
    let ready: Bool
    let version: Int
    let items: [ResumeReviewPlanItem]

    var blockers: [String] {
        items.flatMap(\.blockers)
    }
}

nonisolated struct ResumeImportResultItem: Equatable, Sendable, Identifiable {
    let reviewItemID: String
    let outcome: String
    let recordType: String?
    let recordID: String?
    let sanitizedErrorCode: String?
    let warnings: [String]

    var id: String { reviewItemID }
}

nonisolated struct ResumeImportEntitySummary: Equatable, Sendable {
    let detected: Int
    let imported: Int
    let incomplete: Int
    let failed: Int
}

nonisolated enum ResumeImportBatchStatus: String, Equatable, Sendable {
    case processing
    case completed
    case partiallyCompleted = "partially_completed"
    case unknown

    init(apiValue: String) {
        self = ResumeImportBatchStatus(rawValue: apiValue) ?? .unknown
    }
}

nonisolated struct ResumeImportBatch: Equatable, Sendable {
    let id: String
    let reviewSessionID: String
    let status: String
    let totalCount: Int
    let importedCount: Int
    let linkedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let blockedCount: Int
    let incompleteCount: Int
    let entityCounts: [String: ResumeImportEntitySummary]
    let results: [ResumeImportResultItem]
    let createdAt: Date
    let updatedAt: Date

    var resolvedStatus: ResumeImportBatchStatus {
        ResumeImportBatchStatus(apiValue: status)
    }

    var isTerminal: Bool {
        switch resolvedStatus {
        case .completed, .partiallyCompleted:
            true
        case .processing, .unknown:
            false
        }
    }

    var isSuccessful: Bool {
        resolvedStatus == .completed &&
            failedCount == 0 &&
            blockedCount == 0 &&
            incompleteCount == 0
    }

    var isCompletedWithoutHardFailures: Bool {
        resolvedStatus == .completed &&
            failedCount == 0 &&
            blockedCount == 0
    }

    var isPartiallyCompleted: Bool {
        resolvedStatus == .partiallyCompleted
    }
}

nonisolated struct ResumeImportPreparedSelection: Equatable, Sendable {
    let file: ResumeImportFile
    let temporaryFileURL: URL
}

nonisolated struct ResumeImportWorkflowSnapshot: Equatable, Sendable {
    let resume: ResumeRecord
    let reviewSession: ResumeReviewSession?
    let importBatch: ResumeImportBatch?
}

nonisolated struct ResumeImportCompletionResult: Equatable, Sendable {
    let user: AppUser
    let onboardingStatus: OnboardingStatusResponseDTO

    var isOnboardingComplete: Bool {
        onboardingStatus.isOnboardingComplete
    }

    var requiresAdditionalProfileCompletion: Bool {
        !onboardingStatus.isOnboardingComplete
    }
}

nonisolated enum ResumeImportRecoveryDisposition: Equatable, Sendable {
    case noImportToResume
    case importInProgress
    case importPartiallyCompleted
    case importCompleted
}

nonisolated struct ResumeImportRecoveryState: Equatable, Sendable {
    let reviewSession: ResumeReviewSession
    let importBatch: ResumeImportBatch?
    let completionResult: ResumeImportCompletionResult?
    let disposition: ResumeImportRecoveryDisposition
}
