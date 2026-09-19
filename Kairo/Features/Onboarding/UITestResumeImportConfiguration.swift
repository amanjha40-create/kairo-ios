import Foundation

struct UITestResumeImportConfiguration {
    enum ServiceScenario: String {
        case disabled
        case demo
        case authoritativeRecovery = "authoritative_recovery"
        case missingAuthoritativeReview = "missing_authoritative_review"
        case managementEmpty = "management_empty"
        case managementHistory = "management_history"
    }

    enum EnvironmentKey {
        static let phase = "KAIRO_UI_TEST_RESUME_IMPORT_PHASE"
        static let processingPolicy = "KAIRO_UI_TEST_RESUME_IMPORT_POLICY"
        static let fileName = "KAIRO_UI_TEST_RESUME_IMPORT_FILE_NAME"
        static let fileSize = "KAIRO_UI_TEST_RESUME_IMPORT_FILE_SIZE"
        static let autoAdvance = "KAIRO_UI_TEST_RESUME_IMPORT_AUTO_ADVANCE"
        static let serviceScenario = "KAIRO_UI_TEST_RESUME_IMPORT_SERVICE_SCENARIO"
    }

    let state: ResumeImportState
    let serviceScenario: ServiceScenario

    var usesDemoReview: Bool {
        serviceScenario == .demo
    }

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestResumeImportConfiguration {
        guard UITestLaunchConfiguration.current(arguments: arguments, environment: environment).isEnabled else {
            return UITestResumeImportConfiguration(
                state: ResumeImportState(),
                serviceScenario: .disabled
            )
        }

        let phase = ResumeImportPhase(rawValue: environment[EnvironmentKey.phase] ?? "") ?? .initial
        let processingPolicy = ResumeImportProcessingPolicy(
            rawValue: environment[EnvironmentKey.processingPolicy] ?? ""
        ) ?? .succeed
        let autoAdvance = parseBool(environment[EnvironmentKey.autoAdvance]) ?? true
        let serviceScenario = ServiceScenario(
            rawValue: environment[EnvironmentKey.serviceScenario] ?? ""
        ) ?? .demo
        let seededFile = seededFile(
            fileName: environment[EnvironmentKey.fileName] ?? "Aman_Jha_Resume.pdf",
            fileSize: Int(environment[EnvironmentKey.fileSize] ?? "248000")
        )

        return UITestResumeImportConfiguration(
            state: ResumeImportState(
                phase: phase,
                selectedFile: phase == .initial || phase == .unsupportedFile ? nil : seededFile,
                errorMessage: errorMessage(for: phase),
                processingPolicy: processingPolicy,
                processingAttemptCount: phase == .failed ? 1 : (phase.isProcessing ? 1 : 0),
                autoAdvanceProcessing: autoAdvance
            ),
            serviceScenario: serviceScenario
        )
    }

    private static func seededFile(fileName: String, fileSize: Int?) -> ResumeImportFile? {
        let url = URL(fileURLWithPath: fileName, isDirectory: false)
        return try? ResumeImportFile.make(from: url, fileSizeOverride: fileSize)
    }

    private static func errorMessage(for phase: ResumeImportPhase) -> String? {
        switch phase {
        case .unsupportedFile:
            "Choose a PDF or DOCX file."
        case .failed:
            "KairoID couldn't finish this local demo import. Retry to keep reviewing from the same resume, or choose another file."
        default:
            nil
        }
    }

    private static func parseBool(_ rawValue: String?) -> Bool? {
        guard let rawValue else {
            return nil
        }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }
}

actor UITestResumeImportService: ResumeImportServiceProtocol {
    private let scenario: UITestResumeImportConfiguration.ServiceScenario
    private var imported = false
    private var retried = false

    init(scenario: UITestResumeImportConfiguration.ServiceScenario) {
        self.scenario = scenario
    }

    nonisolated func prepareSelection(from pickedURL: URL) throws -> ResumeImportPreparedSelection {
        let file = try ResumeImportFile.make(from: pickedURL)
        return ResumeImportPreparedSelection(file: file, temporaryFileURL: pickedURL)
    }

    nonisolated func cleanupSelection(at temporaryFileURL: URL) {
        _ = temporaryFileURL
    }

    func restoreLatestWorkflow() async throws -> ResumeImportWorkflowSnapshot? {
        switch scenario {
        case .authoritativeRecovery:
            try await Task.sleep(for: .seconds(5))
            return Self.authoritativeWorkflow
        case .missingAuthoritativeReview:
            try await Task.sleep(for: .milliseconds(350))
            throw ResumeImportServiceError.reviewRecovery(.serverUnavailable)
        case .disabled, .demo, .managementEmpty, .managementHistory:
            return nil
        }
    }

    func resumeHistory(offset: Int, limit: Int) async throws -> ResumeHistoryPage {
        let all = scenario == .managementHistory ? managementEntries : []
        return ResumeHistoryPage(entries: Array(all.dropFirst(offset).prefix(limit)), total: all.count, offset: offset)
    }

    func restoreWorkflow(resumeID: String) async throws -> ResumeImportWorkflowSnapshot {
        guard let entry = managementEntries.first(where: { $0.resume.id == resumeID }) else {
            throw NetworkError.invalidResponse
        }
        return entry
    }

    func upload(selection: ResumeImportPreparedSelection) async throws -> ResumeRecord {
        _ = selection
        throw NetworkError.unavailableInDemoMode
    }

    func startProcessing(resumeID: String) async throws -> ResumeProcessJob {
        if scenario == .managementHistory {
            retried = true
            try await Task.sleep(for: .milliseconds(500))
            return ResumeProcessJob(resumeID: resumeID, jobID: "synthetic-job", status: .needsReview)
        }
        _ = resumeID
        throw NetworkError.unavailableInDemoMode
    }

    func processingStatus(resumeID: String) async throws -> ResumeProcessJob {
        if scenario == .managementHistory {
            return ResumeProcessJob(resumeID: resumeID, jobID: "synthetic-job", status: retried ? .needsReview : .failed)
        }
        _ = resumeID
        throw NetworkError.unavailableInDemoMode
    }

    func loadOrCreateReviewSession(resumeID: String) async throws -> ResumeReviewSession {
        if scenario == .managementHistory { return managementReview(resumeID: resumeID, status: .reviewing) }
        _ = resumeID
        throw NetworkError.unavailableInDemoMode
    }

    func refreshReviewSession(reviewID: String) async throws -> ResumeReviewSession {
        if scenario == .managementHistory {
            return managementReview(resumeID: reviewID.replacingOccurrences(of: "review-", with: ""), status: imported ? .imported : .reviewing)
        }
        _ = reviewID
        throw NetworkError.unavailableInDemoMode
    }

    func updateReviewItem(
        reviewID: String,
        itemID: String,
        payload: ResumeReviewItemUpdateRequestDTO
    ) async throws -> ResumeReviewSession {
        _ = (reviewID, itemID, payload)
        throw NetworkError.unavailableInDemoMode
    }

    func validateReview(reviewID: String, expectedVersion: Int) async throws -> ResumeReviewPlan {
        if scenario == .managementHistory {
            return ResumeReviewPlan(sessionID: reviewID, ready: true, version: expectedVersion, items: [])
        }
        _ = (reviewID, expectedVersion)
        throw NetworkError.unavailableInDemoMode
    }

    func importReview(
        reviewID: String,
        expectedVersion: Int,
        idempotencyKey: String
    ) async throws -> ResumeImportBatch {
        if scenario == .managementHistory {
            try await Task.sleep(for: .milliseconds(500))
            imported = true
            return managementBatch(reviewID: reviewID)
        }
        _ = (reviewID, expectedVersion, idempotencyKey)
        throw NetworkError.unavailableInDemoMode
    }

    func latestImportStatus(reviewID: String) async throws -> ResumeImportBatch {
        if scenario == .managementHistory { return managementBatch(reviewID: reviewID) }
        _ = reviewID
        throw NetworkError.unavailableInDemoMode
    }

    func reconcileImportRecovery(reviewID: String) async throws -> ResumeImportRecoveryState {
        _ = reviewID
        throw NetworkError.unavailableInDemoMode
    }

    func completeOnboardingIfNeeded() async throws -> ResumeImportCompletionResult {
        // Authenticated management tests fail if they accidentally reach onboarding completion.
        throw NetworkError.unavailableInDemoMode
    }

    private var managementEntries: [ResumeImportWorkflowSnapshot] {
        [("current", ResumeProcessingStatus.needsReview, imported ? ResumeReviewStatus.imported : .reviewing),
         ("previous", .needsReview, .imported), ("failed", retried ? .needsReview : .failed, .reviewing)].map { id, status, reviewStatus in
            let review = status == .needsReview ? managementReview(resumeID: id, status: reviewStatus) : nil
            return ResumeImportWorkflowSnapshot(resume: ResumeRecord(id: id,
                originalFilename: "Synthetic_\(id)_resume_with_a_deliberately_long_filename_for_accessibility.pdf",
                contentType: "application/pdf", fileSizeBytes: 4096, uploadStatus: .uploaded,
                processingStatus: status, createdAt: Date(timeIntervalSince1970: id == "current" ? 1_788_530_480 : 1_780_530_480),
                updatedAt: Date(timeIntervalSince1970: 1_788_530_480)), reviewSession: review,
                importBatch: reviewStatus == .imported ? managementBatch(reviewID: "review-\(id)") : nil)
        }
    }

    private func managementReview(resumeID: String, status: ResumeReviewStatus) -> ResumeReviewSession {
        let template = Self.authoritativeWorkflow.reviewSession!
        return ResumeReviewSession(id: "review-\(resumeID)", resumeID: resumeID, parsedResultID: "synthetic-parsed-\(resumeID)",
            status: status, schemaVersion: template.schemaVersion, version: 1, items: template.items,
            createdAt: template.createdAt, updatedAt: template.updatedAt)
    }

    private func managementBatch(reviewID: String) -> ResumeImportBatch {
        ResumeImportBatch(id: "synthetic-batch", reviewSessionID: reviewID, status: "completed", totalCount: 1,
            importedCount: 1, linkedCount: 0, skippedCount: 0, failedCount: 0, blockedCount: 0, incompleteCount: 0,
            entityCounts: [:], results: [], createdAt: .distantPast, updatedAt: .distantPast)
    }

    nonisolated private static let authoritativeWorkflow = ResumeImportWorkflowSnapshot(
        resume: ResumeRecord(
            id: "resume_recovered",
            originalFilename: "multi_page_long.pdf",
            contentType: "application/pdf",
            fileSizeBytes: 248_000,
            uploadStatus: .uploaded,
            processingStatus: .needsReview,
            createdAt: Date(timeIntervalSince1970: 1_788_530_400),
            updatedAt: Date(timeIntervalSince1970: 1_788_530_460)
        ),
        reviewSession: ResumeReviewSession(
            id: "review_recovered",
            resumeID: "resume_recovered",
            parsedResultID: "parsed_recovered",
            status: .reviewing,
            schemaVersion: "resume_review_v1",
            version: 1,
            items: [
                ResumeReviewItem(
                    id: "item_recovered_employment",
                    claimType: "employment",
                    sourceClaimID: "claim_recovered_employment",
                    originalPayload: [
                        "job_title": .string("Staff Software Engineer"),
                        "employer_legal_name": .string("Authoritative Systems")
                    ],
                    editedPayload: [
                        "job_title": .string("Staff Software Engineer"),
                        "employer_legal_name": .string("Authoritative Systems")
                    ],
                    selected: true,
                    reviewStatus: "selected",
                    duplicateStatus: .noMatch,
                    duplicateCandidates: [],
                    conflictWarnings: [],
                    importAction: .createNew,
                    targetRecordID: nil,
                    importedRecordType: nil,
                    importedRecordID: nil,
                    sourceReference: "page_1",
                    confidence: 0.98,
                    version: 1
                )
            ],
            createdAt: Date(timeIntervalSince1970: 1_788_530_480),
            updatedAt: Date(timeIntervalSince1970: 1_788_530_480)
        ),
        importBatch: nil
    )
}
