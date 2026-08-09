import XCTest
@testable import Kairo

final class ResumeImportStateTests: XCTestCase {
    func test_supportedFileTypesAreAccepted() throws {
        for fileName in ["resume.pdf", "resume.docx"] {
            let file = try ResumeImportFile.make(
                from: URL(fileURLWithPath: fileName),
                fileSizeOverride: 240_000
            )

            XCTAssertEqual(file.fileName, fileName)
            XCTAssertFalse(file.fileType.isEmpty)
        }
    }

    func test_unsupportedFileTypeIsRejected() {
        var state = ResumeImportState()

        state.selectFile(from: URL(fileURLWithPath: "resume.pages"))

        XCTAssertEqual(state.phase, .unsupportedFile)
        XCTAssertNil(state.selectedFile)
        XCTAssertEqual(state.errorMessage, "Choose a PDF or DOCX file.")
    }

    func test_docFileTypeIsRejected() {
        var state = ResumeImportState()

        state.selectFile(from: URL(fileURLWithPath: "resume.doc"))

        XCTAssertEqual(state.phase, .unsupportedFile)
        XCTAssertNil(state.selectedFile)
        XCTAssertEqual(state.errorMessage, "Choose a PDF or DOCX file.")
    }

    func test_hiddenFilenameIsRejected() {
        var state = ResumeImportState()

        state.selectFile(from: URL(fileURLWithPath: ".resume.pdf"), fileSizeOverride: 40_000)

        XCTAssertEqual(state.phase, .unsupportedFile)
        XCTAssertNil(state.selectedFile)
    }

    func test_extensionlessFilenameIsRejected() {
        var state = ResumeImportState()

        state.selectFile(from: URL(fileURLWithPath: "resume"), fileSizeOverride: 40_000)

        XCTAssertEqual(state.phase, .unsupportedFile)
        XCTAssertNil(state.selectedFile)
    }

    func test_oversizedFileIsRejected() {
        var state = ResumeImportState()

        state.selectFile(
            from: URL(fileURLWithPath: "resume.pdf"),
            fileSizeOverride: ResumeImportFile.maximumByteCount + 1
        )

        XCTAssertEqual(state.phase, .failed)
        XCTAssertNil(state.selectedFile)
        XCTAssertEqual(state.errorMessage, "Your resume must be 10 MB or smaller.")
    }

    func test_selectedFileRetainsMetadataOnly() throws {
        let file = try ResumeImportFile.make(
            from: URL(fileURLWithPath: "resume.pdf"),
            fileSizeOverride: 240_000
        )

        let labels = Mirror(reflecting: file).children.compactMap(\.label)

        XCTAssertEqual(labels, [
            "fileName",
            "fileType",
            "fileSizeDescription",
            "fileExtension",
            "byteSize",
            "mimeType"
        ])
        XCTAssertEqual(file.fileName, "resume.pdf")
        XCTAssertEqual(file.fileType, "PDF Document")
        XCTAssertEqual(file.fileExtension, "pdf")
        XCTAssertEqual(file.byteSize, 240_000)
        XCTAssertEqual(file.mimeType, "application/pdf")
        XCTAssertFalse(file.fileSizeDescription.isEmpty)
    }

    func test_selectingNewFileReplacesExistingFile() {
        var state = ResumeImportState()

        state.selectFile(from: URL(fileURLWithPath: "resume.pdf"), fileSizeOverride: 200_000)
        state.selectFile(from: URL(fileURLWithPath: "updated_resume.docx"), fileSizeOverride: 280_000)

        XCTAssertEqual(state.phase, .selected)
        XCTAssertEqual(state.selectedFile?.fileName, "updated_resume.docx")
        XCTAssertEqual(state.selectedFile?.fileType, "Word Document (.docx)")
    }

    func test_removeSelectionReturnsToInitialState() {
        var state = ResumeImportState()
        state.selectFile(from: URL(fileURLWithPath: "resume.pdf"), fileSizeOverride: 200_000)

        state.clearSelection()

        XCTAssertEqual(state.phase, .initial)
        XCTAssertNil(state.selectedFile)
        XCTAssertNil(state.errorMessage)
    }

    func test_processingSuccessTransitionsIntoReviewState() {
        var state = ResumeImportState()
        state.selectFile(from: URL(fileURLWithPath: "resume.pdf"), fileSizeOverride: 200_000)

        state.beginProcessing()
        XCTAssertEqual(state.phase, .processingPreparing)

        state.advanceProcessing()
        XCTAssertEqual(state.phase, .processingOrganising)

        state.advanceProcessing()
        XCTAssertEqual(state.phase, .readyForReview)
        XCTAssertEqual(state.processingAttemptCount, 1)
    }

    func test_reviewStateExposesConfirmationCopy() {
        var state = ResumeImportState()
        state.selectFile(from: URL(fileURLWithPath: "resume.pdf"), fileSizeOverride: 200_000)

        state.beginProcessing()
        state.advanceProcessing()
        state.advanceProcessing()

        XCTAssertEqual(state.phase, .readyForReview)
        XCTAssertTrue(state.canConfirm)
        XCTAssertEqual(state.readyTitle, "Ready for review")
        XCTAssertEqual(
            state.readyMessage,
            "Your local demo preview is ready. Nothing is added to your Trust Passport until you confirm it."
        )
    }

    func test_processingFailureCanRetryIntoSuccess() {
        var state = ResumeImportState(processingPolicy: .failOnce)
        state.selectFile(from: URL(fileURLWithPath: "resume.pdf"), fileSizeOverride: 200_000)

        state.beginProcessing()
        state.advanceProcessing()
        state.advanceProcessing()

        XCTAssertEqual(state.phase, .failed)
        XCTAssertNotNil(state.errorMessage)

        state.retryProcessing()
        state.advanceProcessing()
        state.advanceProcessing()

        XCTAssertEqual(state.phase, .readyForReview)
        XCTAssertEqual(state.processingAttemptCount, 2)
    }

    func test_confirmingReviewTransitionsIntoConfirmedState() {
        var state = ResumeImportState()
        state.selectFile(from: URL(fileURLWithPath: "resume.pdf"), fileSizeOverride: 200_000)
        state.beginProcessing()
        state.advanceProcessing()
        state.advanceProcessing()

        state.confirmReview()

        XCTAssertEqual(state.phase, .confirmed)
    }

    func test_applyPreparedSelectionResetsLiveWorkflowArtifacts() throws {
        var state = ResumeImportState(
            phase: .readyForReview,
            selectedFile: try ResumeImportFile.make(
                from: URL(fileURLWithPath: "old.pdf"),
                fileSizeOverride: 120_000
            ),
            selectedTemporaryFileURL: URL(fileURLWithPath: "/tmp/old.pdf"),
            errorMessage: "Old error",
            liveResume: makeResumeRecord(processingStatus: .needsReview),
            liveReviewSession: makeReviewSession(),
            liveReviewPlan: ResumeReviewPlan(sessionID: "review_123", ready: true, version: 3, items: []),
            liveImportBatch: makeImportBatch(status: "importing"),
            currentProcessingStatus: .needsReview,
            statusTitleOverride: "Old title",
            statusMessageOverride: "Old message",
            importIdempotencyKey: "old-key"
        )

        let selection = ResumeImportPreparedSelection(
            file: try ResumeImportFile.make(
                from: URL(fileURLWithPath: "new_resume.docx"),
                fileSizeOverride: 220_000
            ),
            temporaryFileURL: URL(fileURLWithPath: "/tmp/new_resume.docx")
        )

        state.applyPreparedSelection(selection)

        XCTAssertEqual(state.phase, .selected)
        XCTAssertEqual(state.selectedFile?.fileName, "new_resume.docx")
        XCTAssertEqual(state.selectedTemporaryFileURL?.lastPathComponent, "new_resume.docx")
        XCTAssertNil(state.liveResume)
        XCTAssertNil(state.liveReviewSession)
        XCTAssertNil(state.liveReviewPlan)
        XCTAssertNil(state.liveImportBatch)
        XCTAssertNil(state.currentProcessingStatus)
        XCTAssertNil(state.statusTitleOverride)
        XCTAssertNil(state.statusMessageOverride)
        XCTAssertNil(state.importIdempotencyKey)
    }

    func test_applyRestoredWorkflowWithReviewSessionReturnsToReviewState() {
        var state = ResumeImportState()
        let snapshot = ResumeImportWorkflowSnapshot(
            resume: makeResumeRecord(processingStatus: .needsReview),
            reviewSession: makeReviewSession(),
            importBatch: nil
        )

        state.applyRestoredWorkflow(snapshot)

        XCTAssertEqual(state.phase, .readyForReview)
        XCTAssertEqual(state.currentProcessingStatus, .needsReview)
        XCTAssertEqual(state.selectedFile?.fileName, "Aman_Jha_Resume.pdf")
        XCTAssertNotNil(state.liveReviewSession)
    }

    func test_applyRestoredWorkflowWithActiveImportReturnsToImportingState() {
        var state = ResumeImportState()
        let snapshot = ResumeImportWorkflowSnapshot(
            resume: makeResumeRecord(processingStatus: .needsReview),
            reviewSession: makeReviewSession(status: .importing),
            importBatch: makeImportBatch(status: "importing")
        )

        state.applyRestoredWorkflow(snapshot)

        XCTAssertEqual(state.phase, .importing)
        XCTAssertEqual(state.currentProcessingStatus, .needsReview)
        XCTAssertEqual(state.liveImportBatch?.status, "importing")
    }

    func test_applyRestoredWorkflowMapsExtractingToOrganisingPhase() {
        var state = ResumeImportState()
        let snapshot = ResumeImportWorkflowSnapshot(
            resume: makeResumeRecord(processingStatus: .extracting),
            reviewSession: nil,
            importBatch: nil
        )

        state.applyRestoredWorkflow(snapshot)

        XCTAssertEqual(state.phase, .processingOrganising)
        XCTAssertEqual(state.currentProcessingStatus, .extracting)
    }

    func test_prepareForEntryIntoLiveResumeImportAllowsInitialStateToRestoreAgain() {
        var state = ResumeImportState(
            phase: .initial,
            restorationAttempted: true
        )

        state.prepareForEntryIntoLiveResumeImport()

        XCTAssertFalse(state.restorationAttempted)
    }

    func test_prepareForEntryIntoLiveResumeImportAllowsFailedStateToRestoreAgain() {
        var state = ResumeImportState(
            phase: .failed,
            restorationAttempted: true
        )

        state.prepareForEntryIntoLiveResumeImport()

        XCTAssertFalse(state.restorationAttempted)
    }

    func test_prepareForEntryIntoLiveResumeImportPreservesLocalSelectionPendingUpload() throws {
        var state = ResumeImportState(
            phase: .selected,
            selectedFile: try ResumeImportFile.make(
                from: URL(fileURLWithPath: "resume.pdf"),
                fileSizeOverride: 240_000
            ),
            selectedTemporaryFileURL: URL(fileURLWithPath: "/tmp/resume.pdf"),
            restorationAttempted: true
        )

        state.prepareForEntryIntoLiveResumeImport()

        XCTAssertTrue(state.restorationAttempted)
    }

    func test_prepareForEntryIntoLiveResumeImportAllowsLiveReviewRecoveryOnReentry() {
        var state = ResumeImportState(
            phase: .readyForReview,
            liveResume: makeResumeRecord(processingStatus: .needsReview),
            liveReviewSession: makeReviewSession(),
            restorationAttempted: true
        )

        state.prepareForEntryIntoLiveResumeImport()

        XCTAssertFalse(state.restorationAttempted)
    }

    func test_prepareForEntryIntoLiveResumeImportDoesNotRestartConfirmedState() {
        var state = ResumeImportState(
            phase: .confirmed,
            restorationAttempted: true
        )

        state.prepareForEntryIntoLiveResumeImport()

        XCTAssertTrue(state.restorationAttempted)
    }

    func test_ensureImportIdempotencyKeyIsStablePerReviewAndRotatesAcrossReviews() {
        var state = ResumeImportState()

        let first = state.ensureImportIdempotencyKey(for: "review_123")
        let second = state.ensureImportIdempotencyKey(for: "review_123")
        let third = state.ensureImportIdempotencyKey(for: "review_456")

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, third)
        XCTAssertFalse(first.isEmpty)
        XCTAssertFalse(third.isEmpty)
    }

    private func makeResumeRecord(processingStatus: ResumeProcessingStatus) -> ResumeRecord {
        ResumeRecord(
            id: "resume_123",
            originalFilename: "Aman_Jha_Resume.pdf",
            contentType: "application/pdf",
            fileSizeBytes: 240_000,
            uploadStatus: .uploaded,
            processingStatus: processingStatus,
            createdAt: Date(timeIntervalSince1970: 1_722_499_200),
            updatedAt: Date(timeIntervalSince1970: 1_722_499_260)
        )
    }

    private func makeReviewSession(
        status: ResumeReviewStatus = .reviewing
    ) -> ResumeReviewSession {
        ResumeReviewSession(
            id: "review_123",
            resumeID: "resume_123",
            parsedResultID: "parsed_123",
            status: status,
            schemaVersion: "resume_review_v1",
            version: 4,
            items: [],
            createdAt: Date(timeIntervalSince1970: 1_722_499_300),
            updatedAt: Date(timeIntervalSince1970: 1_722_499_320)
        )
    }

    private func makeImportBatch(status: String) -> ResumeImportBatch {
        ResumeImportBatch(
            id: "batch_123",
            reviewSessionID: "review_123",
            status: status,
            totalCount: 2,
            importedCount: 0,
            linkedCount: 0,
            skippedCount: 0,
            failedCount: 0,
            blockedCount: 0,
            incompleteCount: 0,
            entityCounts: [:],
            results: [],
            createdAt: Date(timeIntervalSince1970: 1_722_499_400),
            updatedAt: Date(timeIntervalSince1970: 1_722_499_460)
        )
    }
}
