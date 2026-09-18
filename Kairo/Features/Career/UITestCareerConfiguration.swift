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
    @State private var addingEmployment = false
    @State private var verificationPreset: VerificationInitiationPreset?

    var body: some View {
        CareerOverviewScreenView(state: state,
            addEmploymentAction: { addingEmployment = true },
            startEmploymentVerificationAction: { verificationPreset = .employment(id: $0.routeID) })
            .sheet(isPresented: $addingEmployment) {
                CareerEmploymentEditorSheet(mode: .create, draft: .init()) { _ in throw URLError(.unsupportedURL) }
            }
            .verificationInitiationSheet(preset: $verificationPreset, service: CareerHierarchyVerificationFixture()) { _ in }
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
