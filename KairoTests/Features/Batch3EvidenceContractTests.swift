import XCTest
@testable import Kairo

@MainActor
final class Batch3EvidenceContractTests: XCTestCase {
    func testEducationContactOptionsAreCanonicalWithoutEmploymentPrompts() {
        let kind = VerificationInitiationKind.education
        XCTAssertEqual(kind.contactTypes, [.authorizedRepresentative, .other])
        XCTAssertEqual(kind.contactHeading, "Institution contact")
        XCTAssertFalse(kind.contactEmailPrompt.contains("hr@"))
        XCTAssertFalse(kind.contactRolePrompt.contains("HR"))
        XCTAssertTrue(kind.workflowDescription.contains("institution"))
        XCTAssertFalse(kind.workflowDescription.contains("employer"))
    }
    func testEmploymentKeepsCanonicalContactOptions() {
        XCTAssertEqual(VerificationInitiationKind.employment.contactTypes, VerificationContactType.allCases)
        XCTAssertTrue(VerificationInitiationKind.employment.workflowDescription.contains("two completed primary"))
    }
    func testPrimaryGroupsAreFirstAndNeverInferRoleFromType() {
        let documents: [VerificationEvidenceDocument] = [
            .init(id: "s", documentType: "offer_letter", filename: "s.pdf", isUploadComplete: true, evidenceRole: .supporting),
            .init(id: "l", documentType: "offer_letter", filename: "l.pdf", isUploadComplete: true),
            .init(id: "p", documentType: "other", filename: "p.pdf", isUploadComplete: true, evidenceRole: .primary)
        ]
        var draft = VerificationInitiationDraft(subject: subject(.employment), documents: documents)
        draft.selectedDocumentIDs = ["s", "l", "p"]
        XCTAssertEqual(draft.evidenceGroups.map { $0.documents.map(\.id) }, [["p"], ["s"], ["l"]])
        XCTAssertEqual(draft.selectedPrimaryCount, 1)
        XCTAssertFalse(draft.evidenceReady)
    }
    func testEducationDoesNotAcquireEmploymentPrimaryRule() {
        var draft = VerificationInitiationDraft(subject: subject(.education), documents: [
            .init(id: "e", documentType: "transcript", filename: "e.pdf", isUploadComplete: true)
        ])
        draft.selectedDocumentIDs = ["e"]
        XCTAssertTrue(draft.evidenceReady)
        XCTAssertEqual(draft.evidenceGroups.map(\.title), ["Education documents"])
        XCTAssertTrue(draft.consentedFields.allSatisfy { $0.hasPrefix("education.") })
    }
    func testEducationUnknownCompletionIsNotClaimedCompleteAndRemainsServerValidated() {
        let document = VerificationEvidenceDocument(id: "e", documentType: "transcript", filename: "e.pdf",
            isUploadComplete: false, requiresCompletionValidation: true)
        var draft = VerificationInitiationDraft(subject: subject(.education), documents: [document])
        draft.selectedDocumentIDs = ["e"]
        XCTAssertFalse(document.isUploadComplete)
        XCTAssertTrue(draft.evidenceReady)
        var employment = VerificationInitiationDraft(subject: subject(.employment), documents: [document])
        employment.selectedDocumentIDs = ["e"]
        XCTAssertFalse(employment.evidenceReady)
    }
    func testSelectionCannotExceedContractMaximum() {
        var draft = VerificationInitiationDraft(subject: subject(.education), documents: (0..<21).map {
            .init(id: String($0), documentType: "transcript", filename: "synthetic.pdf", isUploadComplete: true)
        })
        draft.selectedDocumentIDs = Set(draft.documents.map(\.id))
        XCTAssertFalse(draft.evidenceReady)
    }
    func testSingleAttachmentSlotDisablesOnlyNewAddition() {
        for parent: CareerDocumentParent in [.certification(id: "c", title: "Synthetic"), .portfolio(id: "p", title: "Synthetic")] {
            XCTAssertTrue(parent.canAddDocument(existing: []))
            XCTAssertFalse(parent.canAddDocument(existing: [document]))
            XCTAssertTrue(parent.canUpload)
            XCTAssertTrue(parent.canDelete)
        }
    }
    func testRepeatedEmploymentAndEducationTypesRemainAllowed() {
        for parent: CareerDocumentParent in [.employment(id: "e", title: "Synthetic", canUpload: true, canDelete: true), .education(id: "e", title: "Synthetic")] {
            XCTAssertTrue(parent.canAddDocument(existing: [document, document]))
            XCTAssertFalse(parent.hasSingleAttachment)
        }
    }
    func testLockedEmploymentDoesNotGainUploadCapability() {
        let parent = CareerDocumentParent.employment(id: "e", title: "Synthetic", canUpload: false, canDelete: false)
        XCTAssertFalse(parent.canAddDocument(existing: []))
        XCTAssertFalse(parent.canAddDocument(existing: [document]))
    }
    func testVaultReplacementHistoryDoesNotCreateClientTypeUniqueness() {
        XCTAssertEqual(Set(VaultDocumentType.newUploadTypes.map(\.rawValue)).count, 7)
        XCTAssertFalse(VaultDocumentType.aadhaar.allowsDocumentNumber)
    }
    private func subject(_ kind: VerificationInitiationKind) -> VerificationInitiationSubject {
        .init(id: "synthetic", kind: kind, title: "Synthetic", subtitle: "Qualification", verificationStatus: .notVerified, hasActiveRequest: false)
    }
    private var document: CareerDocument {
        .init(id: "synthetic", documentType: "other", originalFilename: "synthetic.pdf", contentType: "application/pdf", byteSize: 1, verificationStatus: "rejected")
    }
}
