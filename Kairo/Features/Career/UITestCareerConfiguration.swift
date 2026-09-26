import SwiftUI

struct UITestCareerConfiguration {
    static let stateEnvironmentKey = "KAIRO_UI_TEST_CAREER_STATE"

    let state: CareerOverviewState?
    var showsAttachedCertificationEditor = false
    var showsHierarchyFixture = false

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestCareerConfiguration {
        let launchConfiguration = UITestLaunchConfiguration.current(
            arguments: arguments,
            environment: environment
        )

        guard launchConfiguration.isEnabled,
              launchConfiguration.route == .demoHome,
              let rawValue = environment[stateEnvironmentKey],
              let kind = CareerOverviewFixtureKind(rawValue: rawValue) else {
            return UITestCareerConfiguration(state: nil)
        }

        let state: CareerOverviewState = switch kind {
        case .populated:
            .populatedFixture()
        case .empty:
            .emptyFixture()
        case .loading:
            .loadingFixture()
        case .error:
            .errorFixture()
        }

        return UITestCareerConfiguration(
            state: state,
            showsAttachedCertificationEditor: environment["KAIRO_UI_TEST_ATTACHED_CERTIFICATION"] == "1",
            showsHierarchyFixture: environment["KAIRO_UI_TEST_CAREER_HIERARCHY"] == "1"
        )
    }
}

/// Explicitly guarded UI-test fixture. Add and verification use canonical sheets;
/// saves/submissions are unavailable and no live record or service is involved.
struct CareerHierarchyFixtureHostView: View {
    let state: CareerOverviewState
    @State private var presentedSheet: CareerMutationSheet?
    @State private var verificationPreset: VerificationInitiationPreset?

    var body: some View {
        CareerOverviewScreenView(state: state,
            addEmploymentAction: { presentedSheet = .employment(mode: .create, recordID: nil, draft: .init()) },
            editEmploymentAction: { item in presentedSheet = .employment(mode: .edit, recordID: item.routeID, draft: .init()) },
            startEmploymentVerificationAction: { verificationPreset = .employment(id: $0.routeID) },
            addEducationAction: { presentedSheet = .education(mode: .create, recordID: nil, draft: .init()) },
            editEducationAction: { item in presentedSheet = .education(mode: .edit, recordID: item.routeID, draft: .init()) },
            addCertificationAction: { presentedSheet = .certification(mode: .create, recordID: nil, draft: .init()) },
            editCertificationAction: { item in presentedSheet = .certification(mode: .edit, recordID: item.routeID, draft: .init()) },
            addProjectAction: { presentedSheet = .project(mode: .create, recordID: nil, draft: .init()) },
            editProjectAction: { item in presentedSheet = .project(mode: .edit, recordID: item.routeID, draft: .init()) },
            addPortfolioAction: { presentedSheet = .portfolio(mode: .create, recordID: nil, draft: .init()) },
            editPortfolioAction: { item in
                presentedSheet = .portfolio(
                    mode: .edit,
                    recordID: item.routeID,
                    draft: CareerPortfolioDraft(record: .init(
                        id: item.routeID,
                        title: item.title,
                        description: item.description,
                        url: item.url,
                        tags: item.tags,
                        originalFilename: item.originalFilename,
                        contentType: item.hasDocument ? "application/pdf" : nil,
                        byteSize: item.byteSize,
                        uploadCompletedAt: item.hasDocument ? Date() : nil,
                        verificationStatus: "draft"
                    ))
                )
            })
            .environment(\.careerDocumentService, DemoCareerDocumentService())
            .sheet(item: $presentedSheet) { sheet in
                mutationSheet(for: sheet)
            }
            .verificationInitiationSheet(preset: $verificationPreset, service: CareerHierarchyVerificationFixture()) { _ in }
    }

    init(state: CareerOverviewState) {
        self.state = state
    }

    @ViewBuilder
    private func mutationSheet(for sheet: CareerMutationSheet) -> some View {
        switch sheet {
        case .employment(let mode, _, let draft):
            CareerEmploymentEditorSheet(mode: mode, draft: draft) { _ in throw URLError(.unsupportedURL) }
        case .education(let mode, _, let draft):
            CareerEducationEditorSheet(mode: mode, draft: draft) { _ in throw URLError(.unsupportedURL) }
        case .certification(let mode, _, let draft):
            CareerCertificationEditorSheet(mode: mode, draft: draft) { _, _ in throw URLError(.unsupportedURL) }
        case .project(let mode, _, let draft):
            CareerProjectEditorSheet(mode: mode, draft: draft) { _ in throw URLError(.unsupportedURL) }
        case .portfolio(let mode, _, let draft):
            CareerPortfolioEditorSheet(mode: mode, draft: draft) { _ in throw URLError(.unsupportedURL) }
        case .skill(let mode, _, let draft, let existingNames):
            CareerSkillEditorSheet(mode: mode, existingNames: existingNames, draft: draft) { _ in throw URLError(.unsupportedURL) }
        }
    }
}

private struct CareerHierarchyVerificationFixture: VerificationInitiationServiceProtocol {
    func loadEligibility() async throws -> VerificationInitiationEligibility {
        .init(subjects: [.init(id: "fixture_employment_3", kind: .employment,
            title: "Horizon Works", subtitle: "Operations Analyst", verificationStatus: .notVerified, hasActiveRequest: false)])
    }
    func loadEvidence(for subject: VerificationInitiationSubject) async throws -> [VerificationEvidenceDocument] { [] }
    func submit(_ draft: VerificationInitiationDraft) async throws -> VerificationInitiationResult { throw URLError(.unsupportedURL) }
}

/// Isolated UI-test host for the real metadata editor and canonical Documents view.
/// The existing launch-argument/route guard above is required; no live service writes.
struct AttachedCertificationFixtureHostView: View {
    @State private var draft = CareerCertificationDraft(record: CareerCertificationRecord(
        id: "attached-certification-fixture", title: "Synthetic attached Certification",
        issuer: "Synthetic QA issuer", issueDate: Date(timeIntervalSince1970: 1_735_689_600),
        expiryDate: nil, doesNotExpire: true, credentialID: nil, credentialURL: nil,
        originalFilename: "demo-evidence.pdf", contentType: "application/pdf", byteSize: 128_000,
        verificationStatus: .notVerified, rawVerificationStatus: "draft"
    ))
    @State private var editsPresented = false
    @State private var documentsPresented = false

    var body: some View {
        VStack(spacing: KairoSpacing.medium) {
            Text(draft.title)
            Text(draft.existingDocumentFilename ?? "No attachment")
                .accessibilityIdentifier("fixture.certification.attachment")
            Button("Edit Certification") { editsPresented = true }
            Button("Documents") { documentsPresented = true }
        }
        .sheet(isPresented: $editsPresented) {
            CareerCertificationEditorSheet(mode: .edit, draft: draft) { updated, _ in
                draft = updated
            }
        }
        .sheet(isPresented: $documentsPresented) {
            CareerDocumentsView(presentation: .init(parent: .certification(
                id: "attached-certification-fixture", title: draft.title
            )))
            .environment(\.careerDocumentService, DemoCareerDocumentService())
        }
    }
}

/// In-memory Portfolio attachment lifecycle used only behind the UI-test launch guard.
/// It never contacts the backend or writes founder data.
actor PortfolioLifecycleFixtureService: CareerDocumentServiceProtocol {
    private var document: CareerDocument?

    init(scenario: String) {
        document = scenario == "removed" ? nil : CareerDocument(
            id: "portfolio-fixture-document",
            documentType: "project",
            originalFilename: "candidate-experience-case-study.pdf",
            contentType: "application/pdf",
            byteSize: 2_048_000,
            verificationStatus: "draft"
        )
    }

    nonisolated func documentTypes(for parent: CareerDocumentParent) -> [CareerDocumentType] {
        _ = parent
        return [.init(id: "project", label: "Project attachment")]
    }

    func listDocuments(for parent: CareerDocumentParent) async throws -> [CareerDocument] {
        _ = parent
        return document.map { [$0] } ?? []
    }

    func uploadDocument(fileURL: URL, documentType: String, to parent: CareerDocumentParent) async throws -> [CareerDocument] {
        _ = (fileURL, documentType, parent)
        let replacement = CareerDocument(
            id: "portfolio-fixture-document",
            documentType: "project",
            originalFilename: fileURL.lastPathComponent,
            contentType: "application/pdf",
            byteSize: 4_096,
            verificationStatus: "draft"
        )
        document = replacement
        return [replacement]
    }

    func downloadURL(for document: CareerDocument, parent: CareerDocumentParent) async throws -> URL {
        _ = (document, parent)
        throw NetworkError.unavailableInDemoMode
    }

    func deleteDocument(_ document: CareerDocument, parent: CareerDocumentParent) async throws -> [CareerDocument] {
        _ = (document, parent)
        self.document = nil
        return []
    }
}
