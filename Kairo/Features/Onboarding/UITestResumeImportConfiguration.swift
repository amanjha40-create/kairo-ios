import Foundation

struct UITestResumeImportConfiguration {
    enum ServiceScenario: String {
        case disabled
        case demo
        case authoritativeRecovery = "authoritative_recovery"
        case missingAuthoritativeReview = "missing_authoritative_review"
        case managementEmpty = "management_empty"
        case managementHistory = "management_history"
        case duplicateReview = "duplicate_review"
        case editorControls = "editor_controls"
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
    private var duplicatePossibleAction: ResumeImportAction = .skip
    private var duplicatePossibleVersion = 1
    private var deletedIDs: Set<String> = []
    private(set) var deleteCalls: [String] = []
    private let deleteMode: String
    private let singleResume: Bool

    init(scenario: UITestResumeImportConfiguration.ServiceScenario,
         deleteMode: String = ProcessInfo.processInfo.environment["KAIRO_UI_TEST_RESUME_DELETE_MODE"] ?? "success",
         singleResume: Bool = ProcessInfo.processInfo.environment["KAIRO_UI_TEST_RESUME_DELETE_SINGLE"] == "1") {
        self.scenario = scenario
        self.deleteMode = deleteMode
        self.singleResume = singleResume
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
        case .editorControls:
            return .init(resume: Self.authoritativeWorkflow.resume, reviewSession: editorReview, importBatch: nil)
        case .authoritativeRecovery:
            try await Task.sleep(for: .seconds(5))
            return Self.authoritativeWorkflow
        case .missingAuthoritativeReview:
            try await Task.sleep(for: .milliseconds(350))
            throw ResumeImportServiceError.reviewRecovery(.serverUnavailable)
        case .disabled, .demo, .managementEmpty, .managementHistory, .duplicateReview:
            return nil
        }
    }

    func resumeHistory(offset: Int, limit: Int) async throws -> ResumeHistoryPage {
        let all: [ResumeImportWorkflowSnapshot] = if scenario == .duplicateReview {
            [duplicateWorkflow]
        } else if scenario == .managementHistory {
            managementEntries
        } else {
            []
        }
        return ResumeHistoryPage(entries: Array(all.dropFirst(offset).prefix(limit)), total: all.count, offset: offset)
    }

    func restoreWorkflow(resumeID: String) async throws -> ResumeImportWorkflowSnapshot {
        if deleteMode == "unavailable", !deleteCalls.isEmpty { throw NetworkError.transport("Synthetic unavailable") }
        let entries = scenario == .duplicateReview ? [duplicateWorkflow] : managementEntries
        guard let entry = entries.first(where: { $0.resume.id == resumeID }) else {
            throw NetworkError.api(APIError.decode(from: Data(), statusCode: 404)!)
        }
        return entry
    }

    func deleteResume(resumeID: String) async throws {
        guard scenario == .managementHistory else { throw NetworkError.unavailableInDemoMode }
        deleteCalls.append(resumeID)
        try await Task.sleep(for: .seconds(deleteMode == "slow" ? 4 : 1))
        if deleteMode == "unavailable" { throw NetworkError.transport("Synthetic unavailable") }
        if deleteMode == "failure" { throw NetworkError.transport("Synthetic failure, not for display") }
        deletedIDs.insert(resumeID)
        if deleteMode == "ambiguous" { throw NetworkError.transport("Synthetic timeout, not for display") }
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
        if scenario == .duplicateReview {
            return duplicateReviewSession(status: imported ? .imported : .reviewing)
        }
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
        if scenario == .editorControls, let edited = payload.editedPayload {
            editorPayloads[itemID] = edited
            return editorReview
        }
        if scenario == .duplicateReview, itemID == "item_duplicate_possible" {
            guard payload.expectedVersion == duplicatePossibleVersion else {
                throw NetworkError.transport("Synthetic review conflict")
            }
            if payload.importAction == ResumeImportAction.createNew.rawValue {
                guard payload.confirmDistinctRole == true else {
                    throw NetworkError.transport("Synthetic confirmation required")
                }
                duplicatePossibleAction = .createNew
            } else if payload.importAction == ResumeImportAction.skip.rawValue {
                duplicatePossibleAction = .skip
            }
            duplicatePossibleVersion += 1
            return duplicateReviewSession(status: .reviewing)
        }
        _ = (reviewID, itemID, payload)
        throw NetworkError.unavailableInDemoMode
    }

    func validateReview(reviewID: String, expectedVersion: Int) async throws -> ResumeReviewPlan {
        if scenario == .managementHistory || scenario == .duplicateReview {
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
        if scenario == .duplicateReview {
            try await Task.sleep(for: .milliseconds(350))
            imported = true
            return duplicateBatch(reviewID: reviewID)
        }
        if scenario == .managementHistory {
            try await Task.sleep(for: .milliseconds(500))
            imported = true
            return managementBatch(reviewID: reviewID)
        }
        _ = (reviewID, expectedVersion, idempotencyKey)
        throw NetworkError.unavailableInDemoMode
    }

    func latestImportStatus(reviewID: String) async throws -> ResumeImportBatch {
        if scenario == .duplicateReview { return duplicateBatch(reviewID: reviewID) }
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

    private var duplicateWorkflow: ResumeImportWorkflowSnapshot {
        ResumeImportWorkflowSnapshot(
            resume: ResumeRecord(
                id: "duplicate-review",
                originalFilename: "Synthetic_employment_duplicate_review.pdf",
                contentType: "application/pdf",
                fileSizeBytes: 48_000,
                uploadStatus: .uploaded,
                processingStatus: .needsReview,
                createdAt: Date(timeIntervalSince1970: 1_788_530_480),
                updatedAt: Date(timeIntervalSince1970: 1_788_530_480)
            ),
            reviewSession: duplicateReviewSession(status: imported ? .imported : .reviewing),
            importBatch: imported ? duplicateBatch(reviewID: "review-duplicate") : nil
        )
    }

    private func duplicateReviewSession(status: ResumeReviewStatus) -> ResumeReviewSession {
        ResumeReviewSession(
            id: "review-duplicate",
            resumeID: "duplicate-review",
            parsedResultID: "parsed-duplicate",
            status: status,
            schemaVersion: "resume_review_v1",
            version: duplicatePossibleVersion,
            items: [
                duplicateItem(
                    id: "item_duplicate_exact",
                    role: "Senior Product Analyst",
                    start: "2022-01",
                    end: "2024-06",
                    duplicateStatus: .exactMatch,
                    action: .linkExisting,
                    version: 1
                ),
                duplicateItem(
                    id: "item_duplicate_possible",
                    role: "Product Analytics Lead",
                    start: "2024-07",
                    end: nil,
                    duplicateStatus: .possibleMatch,
                    action: duplicatePossibleAction,
                    version: duplicatePossibleVersion
                )
            ],
            createdAt: Date(timeIntervalSince1970: 1_788_530_480),
            updatedAt: Date(timeIntervalSince1970: 1_788_530_480)
        )
    }

    private func duplicateItem(
        id: String,
        role: String,
        start: String,
        end: String?,
        duplicateStatus: ResumeDuplicateStatus,
        action: ResumeImportAction,
        version: Int
    ) -> ResumeReviewItem {
        let payload: [String: JSONValue] = [
            "employer_legal_name": .string("Meridian Trust"),
            "job_title": .string(role),
            "start_date": .string(start),
            "end_date": end.map(JSONValue.string) ?? .null,
            "work_location_city": .string("Bengaluru")
        ]
        let candidate: [String: JSONValue] = [
            "record_id": .string("employment-existing"),
            "employer": .string("Meridian Trust"),
            "title": .string("Senior Product Analyst"),
            "start_date": .string("2022-01"),
            "end_date": .string("2024-06"),
            "location": .string("Bengaluru")
        ]

        return ResumeReviewItem(
            id: id,
            claimType: "employment",
            sourceClaimID: "claim-\(id)",
            originalPayload: payload,
            editedPayload: payload,
            selected: true,
            reviewStatus: imported ? "imported" : "selected",
            duplicateStatus: duplicateStatus,
            duplicateCandidates: [candidate],
            conflictWarnings: [],
            importAction: action,
            targetRecordID: action == .linkExisting ? "employment-existing" : nil,
            importedRecordType: imported ? "employment" : nil,
            importedRecordID: imported ? "employment-result-\(id)" : nil,
            sourceReference: "page_1",
            confidence: 0.98,
            version: version
        )
    }

    private func duplicateBatch(reviewID: String) -> ResumeImportBatch {
        let possibleWasAdded = duplicatePossibleAction == .createNew
        return ResumeImportBatch(
            id: "duplicate-batch",
            reviewSessionID: reviewID,
            status: "completed",
            totalCount: 2,
            importedCount: possibleWasAdded ? 1 : 0,
            linkedCount: 1,
            skippedCount: possibleWasAdded ? 0 : 1,
            failedCount: 0,
            blockedCount: 0,
            incompleteCount: 0,
            entityCounts: [
                "employment": ResumeImportEntitySummary(
                    detected: 2,
                    imported: possibleWasAdded ? 1 : 0,
                    incomplete: 0,
                    failed: 0
                )
            ],
            results: [
                ResumeImportResultItem(
                    reviewItemID: "item_duplicate_exact",
                    outcome: "linked",
                    recordType: "employment",
                    recordID: "employment-existing",
                    sanitizedErrorCode: nil,
                    warnings: []
                ),
                ResumeImportResultItem(
                    reviewItemID: "item_duplicate_possible",
                    outcome: possibleWasAdded ? "imported" : "skipped",
                    recordType: "employment",
                    recordID: possibleWasAdded ? "employment-new-role" : nil,
                    sanitizedErrorCode: nil,
                    warnings: []
                )
            ],
            createdAt: Date(timeIntervalSince1970: 1_788_530_500),
            updatedAt: Date(timeIntervalSince1970: 1_788_530_510)
        )
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
        }.filter { !deletedIDs.contains($0.resume.id) && (!singleResume || $0.resume.id == "current") }
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

    private var editorPayloads: [String: [String: JSONValue]] = [:]
    private var editorReview: ResumeReviewSession {
        let defaults: [(String, [String: JSONValue])] = [
            ("education", ["institution_name": .string("Synthetic Institute"), "degree": .string("Legacy degree"),
                           "start_date": .string("2020-02-29"), "end_date": .string("2024-06-01")]),
            ("employment", ["company_name": .string("Synthetic Employer"), "role_title": .string("Analyst"),
                            "start_date": .string("2024-07-01")])
        ]
        return ResumeReviewSession(id: "editor-review", resumeID: "resume_recovered", parsedResultID: "editor-parsed",
            status: .reviewing, schemaVersion: "resume_review_v1", version: 1,
            items: defaults.map { type, fields in
                ResumeReviewItem(id: type, claimType: type, sourceClaimID: type, originalPayload: fields,
                    editedPayload: editorPayloads[type] ?? fields, selected: true, reviewStatus: "selected",
                    duplicateStatus: .noMatch, duplicateCandidates: [], conflictWarnings: [], importAction: .createNew,
                    targetRecordID: nil, importedRecordType: nil, importedRecordID: nil, sourceReference: "synthetic",
                    confidence: 0.99, version: 1)
            }, createdAt: .distantPast, updatedAt: .distantPast)
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
