import XCTest
@testable import Kairo

@MainActor
final class Batch2EvidenceTests: XCTestCase {
    func testStoredLocationNeverInfersCountryFromLocaleOrRegion() {
        for (city, country, expected): (String, String?, String) in [
            ("Jaipur", "IN", "Jaipur, India"), ("Mumbai", "India", "Mumbai, India"),
            ("Bengaluru", "IN", "Bengaluru, India"), ("London", "GB", "London, United Kingdom"),
            ("Jaipur", nil, "Jaipur"), ("Jaipur", "", "Jaipur")
        ] {
            let record = CareerEmploymentRecord(id: "synthetic", subjectFullName: nil, subjectEmail: nil, company: "Synthetic", employerLegalName: "Synthetic", employerTradeName: nil, role: "QA", employmentType: nil, startDate: nil, endDate: nil, currentlyWorking: false, workLocationCountry: country, workLocationRegion: "United Kingdom", workLocationCity: city, workArrangement: "onsite", verificationMethod: nil, verificationStatus: .notVerified, rawVerificationStatus: "draft")
            XCTAssertEqual(CareerOverviewMapper.employmentLocation(record), expected)
            XCTAssertEqual(CareerEmploymentDraft(record: record).workLocationCountry, country ?? "")
        }
    }

    func testZeroOneTwoAndSameCategoryPrimaryEvidence() {
        for count in 0...3 {
            let documents = (0..<count).map { doc("\($0)", .primary) }
            let value = draft(documents, count: count)
            XCTAssertEqual(value.canSubmit, count >= 2)
            XCTAssertEqual(value.employmentEligibility?.progress,
                           count < 2 ? "\(count) of 2 documents added" : "\(count) documents added")
        }
    }

    func testSupportingAndLegacyNeverCountEvenWhenSelected() {
        for role: EmploymentEvidenceRole? in [.supporting, nil] {
            XCTAssertFalse(draft([doc("a", .primary), doc("b", role)], count: 1).canSubmit)
            // Server count can include other documents, but selected attachments must qualify too.
            XCTAssertFalse(draft([doc("a", .primary), doc("b", role)], count: 2).canSubmit)
        }
    }

    func testDistinctCompletedAndServerEligibleAllRequired() {
        XCTAssertFalse(draft([doc("a", .primary), doc("a", .primary)], count: 2).canSubmit)
        XCTAssertFalse(draft([doc("a", .primary), doc("b", .primary, complete: false)], count: 2).canSubmit)
        var value = draft([doc("a", .primary), doc("b", .primary)], count: 2)
        value.employmentEligibility = nil
        XCTAssertFalse(value.canSubmit)
        value.employmentEligibility = .init(eligiblePrimaryCount: 2, minimumRequired: 2, eligible: false)
        XCTAssertFalse(value.canSubmit)
        value.employmentEligibility = .init(eligiblePrimaryCount: 1, minimumRequired: 2, eligible: true)
        XCTAssertFalse(value.canSubmit)
    }

    func testCompletedMetadataNotUploadPercentageControlsClassification() {
        let checksum = String(repeating: "a", count: 64)
        for status in ["pending_upload", "failed", "detached", "deleted", "100%"] {
            XCTAssertFalse(EmploymentEvidenceEligibility.isCompleted(status: status, checksum: checksum))
        }
        for checksum: String? in [nil, "", "abc", String(repeating: "0", count: 64)] {
            XCTAssertFalse(EmploymentEvidenceEligibility.isCompleted(status: "pending_review", checksum: checksum))
        }
        for status in ["pending_review", "approved", "rejected"] {
            XCTAssertTrue(EmploymentEvidenceEligibility.isCompleted(status: status, checksum: checksum))
        }
    }

    func testLegacyClassificationUpdatesOnlyAfterAuthoritativeResult() {
        var document = CareerDocument(id: "legacy", documentType: "other", originalFilename: "synthetic.pdf", contentType: "application/pdf", byteSize: 1, verificationStatus: "pending_review", checksumSha256: String(repeating: "a", count: 64))
        XCTAssertTrue(document.canClassifyLegacyEvidence)
        document.evidenceRole = .supporting
        XCTAssertFalse(document.canClassifyLegacyEvidence)
    }

    func testWithdrawalNeutralCareerAndPreservedVerifyHistory() {
        for value in ["withdrawn", "withdrawn_by_candidate"] {
            let status = CareerVerificationStatus(rawBackendValue: value)
            XCTAssertEqual(status, .notVerified)
            XCTAssertTrue(status.canStartVerification)
        }
        XCTAssertEqual(ProductStatusLanguage.title(for: "withdrawn_by_candidate"), "Withdrawn")
        XCTAssertFalse(VerifyVerificationStatus(rawBackendValue: "withdrawn_by_candidate").canCandidateWithdraw)
    }

    func testOwnerPresentationDoesNotRemoveUnderlyingPassportRecords() {
        guard case .populated(let content) = PassportOverviewState.populatedFixture().phase else { return XCTFail() }
        XCTAssertTrue(content.visibleSections.contains(.careerDetails))
        XCTAssertTrue(content.visibleSections.contains(.passportStrength))
        XCTAssertTrue(content.visibleSections.contains(.identity))
        XCTAssertFalse(content.visibleSections.contains(.employment))
        XCTAssertFalse(content.employment.isEmpty)
        XCTAssertFalse(content.education.isEmpty)
        XCTAssertFalse(content.skills.isEmpty)
    }

    private func doc(_ id: String, _ role: EmploymentEvidenceRole?, complete: Bool = true) -> VerificationEvidenceDocument {
        .init(id: id, documentType: "other", filename: "synthetic.pdf", isUploadComplete: complete, evidenceRole: role)
    }
    private func draft(_ documents: [VerificationEvidenceDocument], count: Int) -> VerificationInitiationDraft {
        var value = VerificationInitiationDraft(subject: .init(id: "employment", kind: .employment, title: "Synthetic", subtitle: "QA", verificationStatus: .notVerified, hasActiveRequest: false), documents: documents)
        value.selectedDocumentIDs = Set(documents.map(\.id))
        value.employmentEligibility = .init(eligiblePrimaryCount: count, minimumRequired: 2, eligible: count >= 2)
        value.contactEmail = "qa@example.invalid"
        value.consentsToClaimFields = true
        value.consentsToEvidence = true
        return value
    }
}
