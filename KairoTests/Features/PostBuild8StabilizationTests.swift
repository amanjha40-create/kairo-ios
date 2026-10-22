import Foundation
import XCTest
@testable import Kairo

@MainActor
final class PostBuild8StabilizationTests: XCTestCase {
    private func wire<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(value)) as? [String: Any])
    }

    func testAllTenCareerMetadataKeysHaveThreeDistinctWireStates() throws {
        let cases: [(String, String)] = [
            ("employerTradeName", "employer_trade_name"), ("fieldOfStudy", "field_of_study"),
            ("grade", "grade"), ("credentialID", "credential_id"), ("credentialURL", "credential_url"),
            ("role", "role"), ("description", "description"), ("projectURL", "project_url"),
            ("repositoryURL", "repository_url"), ("organizationName", "organization_name")
        ]
        for (key, jsonKey) in cases {
            for change: OptionalFieldChange<String> in [.unchanged, .set("new value"), .clear] {
                var employment = CareerEmploymentDraft().updateRequest()
                var education = CareerEducationDraft().updateRequest()
                var certification = CareerCertificationDraft().updateRequest()
                var project = CareerProjectDraft().updateRequest()
                employment.metadataChanges[key] = change; education.metadataChanges[key] = change
                certification.metadataChanges[key] = change; project.metadataChanges[key] = change
                let payloads = [try wire(employment), try wire(education), try wire(certification), try wire(project)]
                let owner = key == "employerTradeName" ? 0 : ["fieldOfStudy", "grade"].contains(key) ? 1 : ["credentialID", "credentialURL"].contains(key) ? 2 : 3
                let body = payloads[owner]
                switch change {
                case .unchanged: XCTAssertNil(body[jsonKey], key)
                case .set(let value): XCTAssertEqual(body[jsonKey] as? String, value, key)
                case .clear: XCTAssertTrue(body[jsonKey] is NSNull, key)
                }
                XCTAssertNil(body["metadata_changes"])
                // Existing date-removal contract must remain explicit null.
                XCTAssertTrue(body[owner == 2 ? "issued_date" : "start_date"] is NSNull)
            }
        }
    }

    func testEmploymentTradeNameClearSurvivesCanonicalRefetchAndNewDraft() throws {
        func draft(_ tradeName: String?) -> CareerEmploymentDraft {
            .init(record: .init(id: "synthetic", subjectFullName: nil, subjectEmail: nil,
                company: "Legal employer", employerLegalName: "Legal employer", employerTradeName: tradeName,
                role: "Engineer", employmentType: "full_time", startDate: nil, endDate: nil,
                currentlyWorking: true, workLocationCountry: nil, workLocationRegion: nil,
                verificationMethod: "document", verificationStatus: .notVerified, rawVerificationStatus: "draft"))
        }
        var edit = draft("Old trade name")
        XCTAssertNil(try wire(edit.updateRequest())["employer_trade_name"])
        edit.employerTradeName = "New trade name"
        XCTAssertEqual(try wire(edit.updateRequest())["employer_trade_name"] as? String, "New trade name")
        edit.employerTradeName = ""
        XCTAssertTrue(try wire(edit.updateRequest())["employer_trade_name"] is NSNull)
        // A new draft seeded with canonical null must not restore a fallback.
        // This unit test does not represent a physical app-process relaunch.
        for _ in 0..<2 {
            let reopened = draft(nil)
            XCTAssertEqual(reopened.employerTradeName, "")
            XCTAssertNil(try wire(reopened.updateRequest())["employer_trade_name"])
        }
    }

    func testEducationTextClearingAndLegacyDegreePreservation() throws {
        func draft(field: String?, grade: String?) -> CareerEducationDraft {
            .init(record: .init(id: "synthetic", institution: "Institution", degree: "Legacy custom degree",
                fieldOfStudy: field, educationLevel: nil, grade: grade, startDate: nil,
                startDatePrecision: nil, endDate: nil, endDatePrecision: nil, isCurrentlyStudying: false,
                verificationStatus: .notVerified, rawVerificationStatus: "draft"))
        }
        var edit = draft(field: "Physics", grade: "A")
        XCTAssertNil(try wire(edit.updateRequest())["field_of_study"])
        edit.fieldOfStudy = ""; edit.grade = ""
        let body = try wire(edit.updateRequest())
        XCTAssertTrue(body["field_of_study"] is NSNull); XCTAssertTrue(body["grade"] is NSNull)
        XCTAssertNil(body["degree"])
        let reopened = draft(field: nil, grade: nil)
        XCTAssertEqual(reopened.fieldOfStudy, ""); XCTAssertEqual(reopened.grade, "")
        XCTAssertEqual(reopened.degree, "Legacy custom degree")
        XCTAssertNil(try wire(reopened.updateRequest())["field_of_study"])
    }

    func testCertificationClearPreservesAttachmentAndNoURLFallback() throws {
        func draft(id: String?, url: URL?) -> CareerCertificationDraft {
            .init(record: .init(id: "synthetic", title: "Certificate", issuer: "Issuer", issueDate: nil,
                expiryDate: nil, doesNotExpire: false, credentialID: id, credentialURL: url,
                originalFilename: "synthetic.pdf", contentType: "application/pdf", byteSize: 10,
                verificationStatus: .notVerified, rawVerificationStatus: "draft"))
        }
        var edit = draft(id: "Old ID", url: URL(string: "https://example.com/credential"))
        XCTAssertNil(try wire(edit.updateRequest())["credential_url"])
        edit.credentialID = ""; edit.credentialURL = ""
        let body = try wire(edit.updateRequest())
        XCTAssertTrue(body["credential_id"] is NSNull); XCTAssertTrue(body["credential_url"] is NSNull)
        XCTAssertNil(body["original_filename"])
        let reopened = draft(id: nil, url: nil)
        XCTAssertEqual(reopened.credentialID, ""); XCTAssertEqual(reopened.credentialURL, "")
        XCTAssertEqual(reopened.existingDocumentFilename, "synthetic.pdf")
    }

    func testProjectAllOptionalTextAndURLsClearAndRemainAbsentOnReopen() throws {
        func draft(populated: Bool) -> CareerProjectDraft {
            .init(record: .init(id: "synthetic", title: "Project", role: populated ? "Developer" : "",
                description: populated ? "Description" : nil, startDate: nil, endDate: nil, isOngoing: true,
                projectURL: populated ? URL(string: "https://example.com/project") : nil,
                repositoryURL: populated ? URL(string: "https://example.com/repository") : nil,
                organizationName: populated ? "Organization" : nil, verificationStatus: .notVerified, rawVerificationStatus: "self_declared"))
        }
        var edit = draft(populated: true)
        XCTAssertNil(try wire(edit.updateRequest())["project_url"])
        edit.role = ""; edit.description = ""; edit.projectURL = ""; edit.repositoryURL = ""; edit.organizationName = ""
        let cleared = try wire(edit.updateRequest())
        let reopened = draft(populated: false)
        for key in ["role", "description", "project_url", "repository_url", "organization_name"] {
            XCTAssertTrue(cleared[key] is NSNull, key)
            XCTAssertNil(try wire(reopened.updateRequest())[key], key)
        }
    }

    func testProfileTextNumericAndDateClearWithoutEncodingInternalState() throws {
        var draft = ProfileEditDraft(user: user())
        XCTAssertTrue(try wire(draft.request).isEmpty)
        draft.phone = ""; draft.currentRole = ""; draft.industry = ""; draft.headline = ""
        draft.location = ""; draft.locationCity = ""; draft.locationRegion = ""; draft.locationCountry = ""
        draft.bio = ""; draft.dateOfBirth = ""; draft.yearsOfExperience = ""
        let body = try wire(draft.request)
        for key in ["phone", "current_role", "industry", "headline", "location", "location_city",
                    "location_region", "location_country", "bio", "date_of_birth", "years_of_experience"] {
            XCTAssertTrue(body[key] is NSNull, key)
        }
        XCTAssertNil(body["full_name"]); XCTAssertNil(body["field_changes"]); XCTAssertNil(body["experience_change"])
        draft.yearsOfExperience = "4"
        XCTAssertEqual(try wire(draft.request)["years_of_experience"] as? Int, 4)
    }

    func testLinkLabelClearVersusUnchanged() throws {
        let unchanged = ProfileLinkMutationDTO(linkType: .website, label: "Old", url: "https://example.com", labelChange: .unchanged)
        XCTAssertNil(try wire(unchanged)["label"])
        let clear = ProfileLinkMutationDTO(linkType: .website, label: nil, url: "https://example.com", labelChange: .clear)
        XCTAssertTrue(try wire(clear)["label"] is NSNull)
    }

    func testUnchangedOnboardingLocationIsOmittedAndExplicitClearIsNull() throws {
        let original = user()
        var draft = ManualProfileMapper.makeRemainingProfileDraft(currentUser: original,
            signupDraftFullName: nil, employments: [], educations: [])
        let unchanged = try wire(ManualProfileMapper.makeSubmissionPayloads(draft: draft, currentUser: original).profile)
        for key in ["location", "location_city", "location_region", "location_country"] { XCTAssertNil(unchanged[key], key) }
        draft.basicProfile.currentCity = ""; draft.basicProfile.currentCountry = ""; draft.basicProfile.currentRegion = ""
        let cleared = try wire(ManualProfileMapper.makeSubmissionPayloads(draft: draft, currentUser: original).profile)
        for key in ["location", "location_city", "location_region", "location_country"] { XCTAssertTrue(cleared[key] is NSNull, key) }
    }

    func testEmploymentRoleTaxonomyIsExactAndDisjoint() {
        XCTAssertEqual(EmploymentEvidenceTypePolicy.primary, Set(["relieving_letter", "employment_contract",
            "offer_letter", "payslip", "pay_stub", "appointment_letter", "experience_letter", "contract", "hr_letter"]))
        XCTAssertEqual(EmploymentEvidenceTypePolicy.supporting, Set(["bank_statement", "form_w2", "form_1099", "employment_id_card", "other"]))
        XCTAssertTrue(EmploymentEvidenceTypePolicy.primary.isDisjoint(with: EmploymentEvidenceTypePolicy.supporting))
        for role in EmploymentEvidenceRole.allCases {
            XCTAssertFalse(EmploymentEvidenceTypePolicy.allows("government_id", role: role))
            XCTAssertFalse(EmploymentEvidenceTypePolicy.allows("unknown_future_type", role: role))
        }
        XCTAssertFalse(EmploymentEvidenceTypePolicy.allows("other", role: .primary))
    }

    func testLegacyReplacementNeverInventsPrimaryRole() {
        var document = CareerDocument(id: "synthetic", documentType: "offer_letter",
            originalFilename: "synthetic.pdf", contentType: "application/pdf", byteSize: 10,
            verificationStatus: "pending_review", evidenceRole: nil, checksumSha256: String(repeating: "a", count: 64))
        XCTAssertFalse(document.canPreserveEmploymentReplacement)
        document.evidenceRole = .primary
        XCTAssertTrue(document.canPreserveEmploymentReplacement)
    }

    func testDegreeCatalogueHasKnownChoicesAndPreservesUnknownValues() {
        XCTAssertTrue(CandidateDegreeCatalogue.values.contains("Bachelor of Science (BSc)"))
        XCTAssertEqual(Set(CandidateDegreeCatalogue.values).count, CandidateDegreeCatalogue.values.count)
        XCTAssertTrue(CandidateDegreeCatalogue.isCustom("Legacy diploma — exact original"))
        XCTAssertFalse(CandidateDegreeCatalogue.isCustom(""))
        XCTAssertFalse(CandidateDegreeCatalogue.isCustom("Bachelor of Science (BSc)"))
    }

    func testWorldwideOfflineGeographyAndExplicitGaps() {
        XCTAssertEqual(CandidateGeography.countries.count, 250)
        for (country, region, city) in [("IN", "Maharashtra", "Mumbai"), ("US", "California", "Los Angeles"), ("CA", "Ontario", "Toronto")] {
            let data = CandidateGeography.country(country)
            XCTAssertTrue(data.regions.contains { $0.name == region }, country)
            XCTAssertTrue(data.cities(in: region).contains(city), country)
            XCTAssertTrue(data.cities(in: "Unlisted legacy province").isEmpty)
        }
        XCTAssertTrue(CandidateGeography.country("Unlisted legacy country").regions.isEmpty)
        XCTAssertEqual(CandidateGeography.countryCode("India"), "IN")
        XCTAssertTrue(CandidateGeography.country("AQ").regions.isEmpty)
    }

    private func user() -> AppUser {
        .init(id: "synthetic", email: "synthetic@example.com", fullName: "Synthetic Candidate", profileSlug: nil,
            phone: "+15555550101", currentRole: "Role", industry: "Industry", yearsOfExperience: 3,
            location: "City, Country", locationCity: "City", locationRegion: "Region", locationCountry: "IN",
            headline: "Headline", bio: "Bio", dateOfBirth: Date(timeIntervalSince1970: 946684800),
            avatarURL: nil, role: "user", isActive: true, phoneVerifiedAt: nil, emailVerifiedAt: nil,
            employmentOnboardingCompletedAt: nil, languages: [], professionalLinks: [],
            profileCompletionPercentage: 100, createdAt: Date(timeIntervalSince1970: 946684800))
    }
}
