import Foundation
import UniformTypeIdentifiers

nonisolated enum ResumeImportPhase: String, Equatable, Sendable {
    case initial
    case selected
    case uploading
    case processingPreparing
    case processingOrganising
    case failed
    case readyForReview
    case importing
    case confirmed
    case unsupportedFile

    var isProcessing: Bool {
        switch self {
        case .uploading, .processingPreparing, .processingOrganising, .importing:
            true
        default:
            false
        }
    }
}

nonisolated enum ResumeImportProcessingPolicy: String, Equatable, Sendable {
    case succeed
    case failOnce
}

nonisolated struct ResumeImportFile: Equatable, Sendable {
    let fileName: String
    let fileType: String
    let fileSizeDescription: String
    let fileExtension: String
    let byteSize: Int
    let mimeType: String

    static let supportedExtensions = ["pdf", "docx"]
    static let maximumByteCount = 10_000_000

    static var supportedContentTypes: [UTType] {
        var types: [UTType] = [.pdf]

        if let docx = UTType.types(
            tag: "docx",
            tagClass: .filenameExtension,
            conformingTo: nil
        ).first, !types.contains(docx) {
            types.append(docx)
        }

        return types
    }

    static func make(
        from url: URL,
        fileSizeOverride: Int? = nil,
        mimeTypeOverride: String? = nil
    ) throws -> ResumeImportFile {
        let fileName = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileExtension = url.pathExtension.lowercased()
        let baseName = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !fileName.isEmpty, !fileName.hasPrefix("."), !baseName.isEmpty else {
            throw ResumeImportSelectionError.unsupportedFileType
        }

        guard supportedExtensions.contains(fileExtension) else {
            throw ResumeImportSelectionError.unsupportedFileType
        }

        let byteSize = if let fileSizeOverride {
            fileSizeOverride
        } else {
            try resolvedByteSize(for: url)
        }

        guard byteSize > 0 else {
            throw ResumeImportSelectionError.emptyFile
        }

        guard byteSize <= maximumByteCount else {
            throw ResumeImportSelectionError.fileTooLarge(maximumByteCount: maximumByteCount)
        }

        return ResumeImportFile(
            fileName: fileName,
            fileType: fileTypeDisplayName(for: fileExtension),
            fileSizeDescription: readableFileSize(for: byteSize),
            fileExtension: fileExtension,
            byteSize: byteSize,
            mimeType: mimeTypeOverride ?? mimeType(for: fileExtension)
        )
    }

    private static func fileTypeDisplayName(for fileExtension: String) -> String {
        switch fileExtension {
        case "pdf":
            "PDF Document"
        case "docx":
            "Word Document (.docx)"
        default:
            fileExtension.uppercased()
        }
    }

    private static func mimeType(for fileExtension: String) -> String {
        switch fileExtension {
        case "pdf":
            "application/pdf"
        case "docx":
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:
            "application/octet-stream"
        }
    }

    private static func readableFileSize(for byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    private static func resolvedByteSize(for url: URL) throws -> Int {
        if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
           let fileSize = resourceValues.fileSize {
            return fileSize
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

        if let fileSize = attributes[.size] as? NSNumber {
            return fileSize.intValue
        }

        if let fileSize = attributes[.size] as? Int {
            return fileSize
        }

        return 0
    }
}

nonisolated enum ResumeImportSelectionError: Error, Equatable, Sendable {
    case unsupportedFileType
    case emptyFile
    case fileTooLarge(maximumByteCount: Int)
}

nonisolated struct ResumeImportReviewPreview: Equatable, Sendable {
    nonisolated struct Section: Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let entries: [String]
    }

    let summary: String
    let sections: [Section]

    static func fixture(name: String, emailAddress: String) -> ResumeImportReviewPreview {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Candidate Profile"
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "name@example.com"
            : emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        return ResumeImportReviewPreview(
            summary: "Review and confirm everything before it becomes part of your Trust Passport.",
            sections: [
                Section(
                    id: "basic-details",
                    title: "Basic details",
                    entries: [
                        resolvedName,
                        resolvedEmail,
                        "India"
                    ]
                ),
                Section(
                    id: "employment",
                    title: "Employment",
                    entries: [
                        "Senior Product Analyst • Meridian Trust",
                        "Trust & Operations Associate • Northline Career Services"
                    ]
                ),
                Section(
                    id: "education",
                    title: "Education",
                    entries: [
                        "B.Tech, Information Technology • Delhi Institute of Technology"
                    ]
                ),
                Section(
                    id: "skills",
                    title: "Skills",
                    entries: [
                        "Identity verification",
                        "Candidate operations",
                        "Data quality",
                        "Stakeholder coordination"
                    ]
                )
            ]
        )
    }
}

nonisolated struct ResumeImportState: Equatable, Sendable {
    var phase: ResumeImportPhase
    var selectedFile: ResumeImportFile?
    var selectedTemporaryFileURL: URL?
    var errorMessage: String?
    var processingPolicy: ResumeImportProcessingPolicy
    var processingAttemptCount: Int
    var autoAdvanceProcessing: Bool
    var liveResume: ResumeRecord?
    var liveReviewSession: ResumeReviewSession?
    var liveReviewPlan: ResumeReviewPlan?
    var liveImportBatch: ResumeImportBatch?
    var currentProcessingStatus: ResumeProcessingStatus?
    var statusTitleOverride: String?
    var statusMessageOverride: String?
    var restorationAttempted: Bool
    var importIdempotencyReviewID: String?
    var importIdempotencyKey: String?

    init(
        phase: ResumeImportPhase = .initial,
        selectedFile: ResumeImportFile? = nil,
        selectedTemporaryFileURL: URL? = nil,
        errorMessage: String? = nil,
        processingPolicy: ResumeImportProcessingPolicy = .succeed,
        processingAttemptCount: Int = 0,
        autoAdvanceProcessing: Bool = true,
        liveResume: ResumeRecord? = nil,
        liveReviewSession: ResumeReviewSession? = nil,
        liveReviewPlan: ResumeReviewPlan? = nil,
        liveImportBatch: ResumeImportBatch? = nil,
        currentProcessingStatus: ResumeProcessingStatus? = nil,
        statusTitleOverride: String? = nil,
        statusMessageOverride: String? = nil,
        restorationAttempted: Bool = false,
        importIdempotencyReviewID: String? = nil,
        importIdempotencyKey: String? = nil
    ) {
        self.phase = phase
        self.selectedFile = selectedFile
        self.selectedTemporaryFileURL = selectedTemporaryFileURL
        self.errorMessage = errorMessage
        self.processingPolicy = processingPolicy
        self.processingAttemptCount = processingAttemptCount
        self.autoAdvanceProcessing = autoAdvanceProcessing
        self.liveResume = liveResume
        self.liveReviewSession = liveReviewSession
        self.liveReviewPlan = liveReviewPlan
        self.liveImportBatch = liveImportBatch
        self.currentProcessingStatus = currentProcessingStatus
        self.statusTitleOverride = statusTitleOverride
        self.statusMessageOverride = statusMessageOverride
        self.restorationAttempted = restorationAttempted
        self.importIdempotencyReviewID = importIdempotencyReviewID
        self.importIdempotencyKey = importIdempotencyKey
    }

    var canChooseResume: Bool {
        !phase.isProcessing
    }

    var canBuildProfileManually: Bool {
        !phase.isProcessing
    }

    var canPrepareResume: Bool {
        selectedFile != nil && phase == .selected
    }

    var canRetry: Bool {
        phase == .failed && (selectedFile != nil || liveResume != nil)
    }

    var canConfirm: Bool {
        switch phase {
        case .readyForReview:
            return selectedFile != nil || liveReviewSession != nil
        default:
            return false
        }
    }

    var currentProcessingTitle: String? {
        if let statusTitleOverride {
            return statusTitleOverride
        }

        if let currentProcessingStatus {
            return currentProcessingStatus.title
        }

        switch phase {
        case .uploading:
            return "Uploading your resume"
        case .processingPreparing:
            return "Preparing your resume"
        case .processingOrganising:
            return "Organising your professional history"
        case .importing:
            return "Importing approved claims"
        default:
            return nil
        }
    }

    var currentProcessingMessage: String? {
        if let statusMessageOverride {
            return statusMessageOverride
        }

        if let currentProcessingStatus {
            return currentProcessingStatus.message
        }

        switch phase {
        case .uploading:
            return "Kairo is securely uploading your resume before processing begins."
        case .processingPreparing:
            return "Kairo is preparing your uploaded file for backend parsing."
        case .processingOrganising:
            return "Kairo is converting parsed content into reviewable candidate claims."
        case .importing:
            return "Kairo is importing only the claims you approved."
        default:
            return nil
        }
    }

    var readyTitle: String {
        "Ready for review"
    }

    var readyMessage: String {
        liveReviewSession == nil
            ? "Your local demo preview is ready. Nothing is added to your Trust Passport until you confirm it."
            : "Review and confirm each candidate-provided claim before anything is added to your Trust Passport."
    }

    var reviewSections: [ResumeReviewSection] {
        guard let liveReviewSession else {
            return []
        }

        return ResumeImportMapper.groupedItems(from: liveReviewSession)
    }

    private var hasLiveBackendWorkflow: Bool {
        liveResume != nil || liveReviewSession != nil || liveImportBatch != nil
    }

    private var hasLocalSelectionPendingUpload: Bool {
        selectedTemporaryFileURL != nil && !hasLiveBackendWorkflow
    }

    mutating func prepareForEntryIntoLiveResumeImport() {
        guard restorationAttempted else {
            return
        }

        guard phase != .confirmed, phase != .unsupportedFile else {
            return
        }

        guard !hasLocalSelectionPendingUpload else {
            return
        }

        if phase == .initial || phase == .failed || hasLiveBackendWorkflow {
            restorationAttempted = false
        }
    }

    mutating func selectFile(
        from url: URL,
        fileSizeOverride: Int? = nil,
        mimeTypeOverride: String? = nil
    ) {
        do {
            selectedFile = try ResumeImportFile.make(
                from: url,
                fileSizeOverride: fileSizeOverride,
                mimeTypeOverride: mimeTypeOverride
            )
            selectedTemporaryFileURL = nil
            errorMessage = nil
            phase = .selected
            processingAttemptCount = 0
            statusTitleOverride = nil
            statusMessageOverride = nil
        } catch ResumeImportSelectionError.unsupportedFileType {
            selectedFile = nil
            selectedTemporaryFileURL = nil
            errorMessage = "Choose a PDF or DOCX file."
            phase = .unsupportedFile
            processingAttemptCount = 0
        } catch ResumeImportSelectionError.emptyFile {
            selectedFile = nil
            selectedTemporaryFileURL = nil
            errorMessage = "That file is empty. Choose another resume."
            phase = .failed
            processingAttemptCount = 0
        } catch ResumeImportSelectionError.fileTooLarge {
            selectedFile = nil
            selectedTemporaryFileURL = nil
            errorMessage = "Your resume must be 10 MB or smaller."
            phase = .failed
            processingAttemptCount = 0
        } catch {
            selectedFile = nil
            selectedTemporaryFileURL = nil
            errorMessage = "Kairo couldn't read that file. Choose another resume to continue."
            phase = .failed
            processingAttemptCount = 0
        }
    }

    mutating func applyPreparedSelection(_ selection: ResumeImportPreparedSelection) {
        selectedFile = selection.file
        selectedTemporaryFileURL = selection.temporaryFileURL
        errorMessage = nil
        phase = .selected
        processingAttemptCount = 0
        liveResume = nil
        liveReviewSession = nil
        liveReviewPlan = nil
        liveImportBatch = nil
        currentProcessingStatus = nil
        statusTitleOverride = nil
        statusMessageOverride = nil
        importIdempotencyReviewID = nil
        importIdempotencyKey = nil
    }

    mutating func clearSelection() {
        selectedFile = nil
        selectedTemporaryFileURL = nil
        errorMessage = nil
        phase = .initial
        processingAttemptCount = 0
        liveResume = nil
        liveReviewSession = nil
        liveReviewPlan = nil
        liveImportBatch = nil
        currentProcessingStatus = nil
        statusTitleOverride = nil
        statusMessageOverride = nil
        importIdempotencyReviewID = nil
        importIdempotencyKey = nil
    }

    mutating func chooseAnotherResume() {
        clearSelection()
    }

    mutating func beginProcessing() {
        guard selectedFile != nil else {
            return
        }

        processingAttemptCount += 1
        errorMessage = nil
        phase = .processingPreparing
    }

    mutating func retryProcessing() {
        guard canRetry else {
            return
        }

        if liveResume != nil {
            errorMessage = nil
            phase = .processingPreparing
            currentProcessingStatus = .queued
            statusTitleOverride = nil
            statusMessageOverride = nil
            return
        }

        beginProcessing()
    }

    mutating func advanceProcessing() {
        switch phase {
        case .processingPreparing:
            phase = .processingOrganising
        case .processingOrganising:
            if shouldFailCurrentAttempt {
                phase = .failed
                errorMessage = "Kairo couldn't finish this local demo import. Retry to keep reviewing from the same resume, or choose another file."
            } else {
                phase = .readyForReview
            }
        default:
            break
        }
    }

    mutating func confirmReview() {
        guard canConfirm else {
            return
        }

        phase = .confirmed
    }

    mutating func markRestorationAttempted() {
        restorationAttempted = true
    }

    mutating func applyRestoredWorkflow(_ snapshot: ResumeImportWorkflowSnapshot) {
        liveResume = snapshot.resume
        selectedFile = ResumeImportFile(
            fileName: snapshot.resume.originalFilename,
            fileType: snapshot.resume.contentType == "application/pdf"
                ? "PDF Document"
                : "Word Document (.docx)",
            fileSizeDescription: ByteCountFormatter.string(
                fromByteCount: Int64(snapshot.resume.fileSizeBytes),
                countStyle: .file
            ),
            fileExtension: snapshot.resume.originalFilename
                .split(separator: ".")
                .last
                .map(String.init)?
                .lowercased() ?? "pdf",
            byteSize: snapshot.resume.fileSizeBytes,
            mimeType: snapshot.resume.contentType
        )
        liveReviewSession = snapshot.reviewSession
        liveImportBatch = snapshot.importBatch
        selectedTemporaryFileURL = nil
        restorationAttempted = true

        if snapshot.reviewSession != nil {
            phase = .readyForReview
            currentProcessingStatus = .needsReview
            if let importBatch = snapshot.importBatch, !importBatch.isTerminal {
                phase = .importing
            }
            return
        }

        currentProcessingStatus = snapshot.resume.processingStatus
        switch snapshot.resume.processingStatus {
        case .failed, .cancelled:
            phase = .failed
            errorMessage = snapshot.resume.processingStatus.message
        case .needsReview:
            phase = .readyForReview
        case .uploaded, .queued, .pendingUpload:
            phase = .processingPreparing
            errorMessage = nil
        case .extracting, .extracted, .parsing, .unknown:
            phase = .processingOrganising
            errorMessage = nil
        case .deleted:
            phase = .initial
        }
    }

    mutating func applyUploadStarted(resume: ResumeRecord) {
        selectedFile = ResumeImportFile(
            fileName: resume.originalFilename,
            fileType: resume.contentType == "application/pdf"
                ? "PDF Document"
                : "Word Document (.docx)",
            fileSizeDescription: ByteCountFormatter.string(
                fromByteCount: Int64(resume.fileSizeBytes),
                countStyle: .file
            ),
            fileExtension: resume.originalFilename
                .split(separator: ".")
                .last
                .map(String.init)?
                .lowercased() ?? "pdf",
            byteSize: resume.fileSizeBytes,
            mimeType: resume.contentType
        )
        liveResume = resume
        liveReviewSession = nil
        liveReviewPlan = nil
        liveImportBatch = nil
        currentProcessingStatus = .uploaded
        errorMessage = nil
        phase = .uploading
        statusTitleOverride = "Uploading your resume"
        statusMessageOverride = "Kairo is securely uploading your resume before backend processing starts."
    }

    mutating func applyProcessingJob(_ job: ResumeProcessJob) {
        currentProcessingStatus = job.status
        liveResume = liveResume.map {
            ResumeRecord(
                id: $0.id,
                originalFilename: $0.originalFilename,
                contentType: $0.contentType,
                fileSizeBytes: $0.fileSizeBytes,
                uploadStatus: $0.uploadStatus,
                processingStatus: job.status,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
        statusTitleOverride = nil
        statusMessageOverride = nil

        switch job.status {
        case .uploaded, .queued, .pendingUpload:
            phase = .processingPreparing
        case .extracting, .extracted, .parsing, .unknown:
            phase = .processingOrganising
        case .needsReview:
            phase = .readyForReview
        case .failed, .cancelled:
            phase = .failed
            errorMessage = job.status.message
        case .deleted:
            phase = .initial
        }
    }

    mutating func applyReviewSession(_ review: ResumeReviewSession) {
        liveReviewSession = review
        liveReviewPlan = nil
        currentProcessingStatus = .needsReview
        errorMessage = nil
        phase = .readyForReview
        statusTitleOverride = nil
        statusMessageOverride = nil
    }

    mutating func applyReviewPlan(_ plan: ResumeReviewPlan) {
        liveReviewPlan = plan
        if let liveReviewSession {
            self.liveReviewSession = ResumeReviewSession(
                id: liveReviewSession.id,
                resumeID: liveReviewSession.resumeID,
                parsedResultID: liveReviewSession.parsedResultID,
                status: liveReviewSession.status,
                schemaVersion: liveReviewSession.schemaVersion,
                version: plan.version,
                items: liveReviewSession.items,
                createdAt: liveReviewSession.createdAt,
                updatedAt: liveReviewSession.updatedAt
            )
        }
    }

    mutating func beginImporting() {
        phase = .importing
        errorMessage = nil
        statusTitleOverride = "Importing approved claims"
        statusMessageOverride = "Kairo is importing only the resume claims you approved."
    }

    mutating func applyImportBatch(_ batch: ResumeImportBatch) {
        liveImportBatch = batch
        if batch.isTerminal {
            statusTitleOverride = nil
            statusMessageOverride = nil
        }
    }

    mutating func setError(_ message: String, phase: ResumeImportPhase = .failed) {
        self.phase = phase
        errorMessage = message
        if phase == .failed {
            currentProcessingStatus = .failed
        }
        statusTitleOverride = nil
        statusMessageOverride = nil
    }

    mutating func ensureImportIdempotencyKey(for reviewID: String) -> String {
        if importIdempotencyReviewID == reviewID, let importIdempotencyKey {
            return importIdempotencyKey
        }

        let newKey = UUID().uuidString
        importIdempotencyReviewID = reviewID
        importIdempotencyKey = newKey
        return newKey
    }

    private var shouldFailCurrentAttempt: Bool {
        processingPolicy == .failOnce && processingAttemptCount == 1
    }
}
