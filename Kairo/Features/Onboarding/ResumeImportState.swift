import Foundation
import UniformTypeIdentifiers

enum ResumeImportPhase: String, Equatable, Sendable {
    case initial
    case selected
    case processingPreparing
    case processingOrganising
    case failed
    case readyForReview
    case confirmed
    case unsupportedFile

    var isProcessing: Bool {
        switch self {
        case .processingPreparing, .processingOrganising:
            true
        default:
            false
        }
    }
}

enum ResumeImportProcessingPolicy: String, Equatable, Sendable {
    case succeed
    case failOnce
}

struct ResumeImportFile: Equatable, Sendable {
    let fileName: String
    let fileType: String
    let fileSizeDescription: String
    let fileExtension: String

    static let supportedExtensions = ["pdf", "doc", "docx"]

    static var supportedContentTypes: [UTType] {
        var types: [UTType] = []

        let extensionTypes = supportedExtensions.compactMap { fileExtension in
            UTType.types(tag: fileExtension, tagClass: .filenameExtension, conformingTo: nil).first
        }

        for type in [UTType.pdf] + extensionTypes {
            if !types.contains(type) {
                types.append(type)
            }
        }

        return types
    }

    static func make(
        from url: URL,
        fileSizeOverride: Int? = nil
    ) throws -> ResumeImportFile {
        let fileExtension = url.pathExtension.lowercased()

        guard supportedExtensions.contains(fileExtension) else {
            throw ResumeImportSelectionError.unsupportedFileType
        }

        let size = if let fileSizeOverride {
            fileSizeOverride
        } else {
            try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        }

        return ResumeImportFile(
            fileName: url.lastPathComponent,
            fileType: fileTypeDisplayName(for: fileExtension),
            fileSizeDescription: readableFileSize(for: size),
            fileExtension: fileExtension
        )
    }

    private static func fileTypeDisplayName(for fileExtension: String) -> String {
        switch fileExtension {
        case "pdf":
            "PDF Document"
        case "doc":
            "Word Document (.doc)"
        case "docx":
            "Word Document (.docx)"
        default:
            fileExtension.uppercased()
        }
    }

    private static func readableFileSize(for byteCount: Int?) -> String {
        guard let byteCount else {
            return "Unknown size"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

enum ResumeImportSelectionError: Error, Equatable, Sendable {
    case unsupportedFileType
}

struct ResumeImportReviewPreview: Equatable, Sendable {
    struct Section: Equatable, Identifiable, Sendable {
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

struct ResumeImportState: Equatable, Sendable {
    var phase: ResumeImportPhase
    var selectedFile: ResumeImportFile?
    var errorMessage: String?
    var processingPolicy: ResumeImportProcessingPolicy
    var processingAttemptCount: Int
    var autoAdvanceProcessing: Bool

    init(
        phase: ResumeImportPhase = .initial,
        selectedFile: ResumeImportFile? = nil,
        errorMessage: String? = nil,
        processingPolicy: ResumeImportProcessingPolicy = .succeed,
        processingAttemptCount: Int = 0,
        autoAdvanceProcessing: Bool = true
    ) {
        self.phase = phase
        self.selectedFile = selectedFile
        self.errorMessage = errorMessage
        self.processingPolicy = processingPolicy
        self.processingAttemptCount = processingAttemptCount
        self.autoAdvanceProcessing = autoAdvanceProcessing
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
        selectedFile != nil && phase == .failed
    }

    var canConfirm: Bool {
        selectedFile != nil && phase == .readyForReview
    }

    var currentProcessingTitle: String? {
        switch phase {
        case .processingPreparing:
            "Preparing your resume"
        case .processingOrganising:
            "Organising your professional history"
        default:
            nil
        }
    }

    var currentProcessingMessage: String? {
        switch phase {
        case .processingPreparing:
            "Kairo is preparing a local preview of your resume without sending it anywhere."
        case .processingOrganising:
            "Kairo is arranging a structured draft for your review before anything becomes part of your Trust Passport."
        default:
            nil
        }
    }

    var readyTitle: String {
        "Ready for review"
    }

    var readyMessage: String {
        "Your local demo preview is ready. Nothing is added to your Trust Passport until you confirm it."
    }

    mutating func selectFile(from url: URL, fileSizeOverride: Int? = nil) {
        do {
            selectedFile = try ResumeImportFile.make(from: url, fileSizeOverride: fileSizeOverride)
            errorMessage = nil
            phase = .selected
            processingAttemptCount = 0
        } catch ResumeImportSelectionError.unsupportedFileType {
            selectedFile = nil
            errorMessage = "Choose a PDF, DOC, or DOCX resume to continue."
            phase = .unsupportedFile
            processingAttemptCount = 0
        } catch {
            selectedFile = nil
            errorMessage = "Kairo couldn't read that file. Choose another resume to continue."
            phase = .failed
            processingAttemptCount = 0
        }
    }

    mutating func clearSelection() {
        selectedFile = nil
        errorMessage = nil
        phase = .initial
        processingAttemptCount = 0
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

    private var shouldFailCurrentAttempt: Bool {
        processingPolicy == .failOnce && processingAttemptCount == 1
    }
}
