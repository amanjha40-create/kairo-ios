import Foundation

struct UITestResumeImportConfiguration {
    enum EnvironmentKey {
        static let phase = "KAIRO_UI_TEST_RESUME_IMPORT_PHASE"
        static let processingPolicy = "KAIRO_UI_TEST_RESUME_IMPORT_POLICY"
        static let fileName = "KAIRO_UI_TEST_RESUME_IMPORT_FILE_NAME"
        static let fileSize = "KAIRO_UI_TEST_RESUME_IMPORT_FILE_SIZE"
        static let autoAdvance = "KAIRO_UI_TEST_RESUME_IMPORT_AUTO_ADVANCE"
    }

    let state: ResumeImportState

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestResumeImportConfiguration {
        guard UITestLaunchConfiguration.current(arguments: arguments, environment: environment).isEnabled else {
            return UITestResumeImportConfiguration(state: ResumeImportState())
        }

        let phase = ResumeImportPhase(rawValue: environment[EnvironmentKey.phase] ?? "") ?? .initial
        let processingPolicy = ResumeImportProcessingPolicy(
            rawValue: environment[EnvironmentKey.processingPolicy] ?? ""
        ) ?? .succeed
        let autoAdvance = parseBool(environment[EnvironmentKey.autoAdvance]) ?? true
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
            )
        )
    }

    private static func seededFile(fileName: String, fileSize: Int?) -> ResumeImportFile? {
        let url = URL(fileURLWithPath: fileName, isDirectory: false)
        return try? ResumeImportFile.make(from: url, fileSizeOverride: fileSize)
    }

    private static func errorMessage(for phase: ResumeImportPhase) -> String? {
        switch phase {
        case .unsupportedFile:
            "Choose a PDF, DOC, or DOCX resume to continue."
        case .failed:
            "Kairo couldn't finish this local demo import. Retry to keep reviewing from the same resume, or choose another file."
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
