import XCTest
@testable import Kairo

final class ResumeImportStateTests: XCTestCase {
    func test_supportedFileTypesAreAccepted() throws {
        for fileName in ["resume.pdf", "resume.doc", "resume.docx"] {
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
        XCTAssertEqual(state.errorMessage, "Choose a PDF, DOC, or DOCX resume to continue.")
    }

    func test_selectedFileRetainsOnlyMetadataFields() throws {
        let file = try ResumeImportFile.make(
            from: URL(fileURLWithPath: "resume.pdf"),
            fileSizeOverride: 240_000
        )

        let labels = Mirror(reflecting: file).children.compactMap(\.label)

        XCTAssertEqual(
            labels,
            ["fileName", "fileType", "fileSizeDescription", "fileExtension"]
        )
        XCTAssertEqual(file.fileName, "resume.pdf")
        XCTAssertEqual(file.fileType, "PDF Document")
        XCTAssertEqual(file.fileExtension, "pdf")
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
}
