import Foundation
import XCTest
@testable import Kairo

final class Batch2FormContractTests: XCTestCase {
    func testEmploymentOptionsMatchAPI43() {
        XCTAssertEqual(Set(CareerEmploymentTypeOption.allCases.map(\.rawValue)),
                       Set(["full_time", "part_time", "contract", "intern", "gig", "freelance", "other"]))
    }
    func testEducationLevelsMatchAPI43AndDoNotConstrainDegree() {
        XCTAssertEqual(Set(CareerEducationLevelOption.allCases.map(\.rawValue)),
                       Set(["high_school", "diploma", "bachelors", "masters", "doctorate", "certification", "other"]))
        var draft = education()
        draft.degree = "Diplôme spécialisé — uncommon qualification"
        XCTAssertEqual(draft.updateRequest().degree, draft.degree)
        XCTAssertNil(draft.validationErrors()["degree"])
    }
    func testUnknownEmploymentTypeAndArrangementRemainReadableAndOmitted() throws {
        var draft = employment(type: "legacy apprenticeship", arrangement: "legacy distributed")
        draft.jobTitle = "Changed title"
        XCTAssertEqual(draft.employmentTypeLabel, "legacy apprenticeship")
        XCTAssertEqual(draft.workArrangementLabel, "legacy distributed")
        let wire = try object(draft.updateRequest())
        XCTAssertNil(wire["employment_type"])
        XCTAssertNil(wire["work_arrangement"])
        XCTAssertEqual(wire["job_title"] as? String, "Changed title")
    }
    func testExplicitEmploymentSelectionReplacesLegacyValue() {
        var draft = employment(type: "legacy", arrangement: nil)
        draft.selectEmploymentType(.contract)
        XCTAssertEqual(draft.employmentTypeLabel, "Contract")
        XCTAssertEqual(draft.updateRequest().employmentType, "contract")
        draft.selectWorkArrangement(.remote)
        XCTAssertEqual(draft.updateRequest().workArrangement, "remote")
    }
    func testMissingEmploymentEnumsAreNotBackfilledByUnrelatedEdit() {
        var draft = employment(type: nil, arrangement: nil)
        draft.jobTitle = "Changed"
        XCTAssertNil(draft.updateRequest().employmentType)
        XCTAssertNil(draft.updateRequest().workArrangement)
    }
    func testStoredCountryIsNotSilentlyNormalized() throws {
        var draft = employment(country: "Legacy country")
        XCTAssertNil(draft.validationErrors()["work_location_country"])
        XCTAssertNil(try object(draft.updateRequest())["work_location_country"])
        draft.workLocationCountry = "IN"
        XCTAssertEqual(draft.updateRequest().workLocationCountry, "IN")
    }
    func testUnchangedTextFieldsAreOmittedOnEdit() throws {
        let draft = employment()
        let wire = try object(draft.updateRequest())
        XCTAssertNil(wire["employer_legal_name"])
        XCTAssertNil(wire["job_title"])
    }
    func testExplicitCountryRemovalEncodesNullButNotInternalPatchFlags() throws {
        var draft = employment(country: "IN")
        draft.workLocationCountry = ""
        let wire = try object(draft.updateRequest())
        XCTAssertTrue(wire["work_location_country"] is NSNull)
        XCTAssertNil(wire["updates_country"])
        XCTAssertNil(wire["updatesCity"])
    }
    func testEmploymentCreationRequiresStartButNotLocation() {
        var draft = CareerEmploymentDraft()
        draft.employerLegalName = "Synthetic employer"
        draft.jobTitle = "Engineer"
        XCTAssertNotNil(draft.validationErrors(mode: .create)["start_date"])
        XCTAssertNil(draft.validationErrors(mode: .create)["work_location_country"])
        XCTAssertNil(draft.validationErrors(mode: .create)["work_location_city"])
        draft.startDate = date()
        XCTAssertTrue(draft.validationErrors(mode: .create).isEmpty)
    }
    func testEmploymentCurrentConflictRetainsEndUntilExplicitRemoval() {
        var draft = employment()
        draft.endDate = date()
        draft.isCurrentlyWorking = true
        XCTAssertNotNil(draft.validationErrors()["end_date"])
        XCTAssertNotNil(draft.updateRequest().endDate)
        draft.includesEndDate = false
        XCTAssertNil(draft.validationErrors()["end_date"])
        XCTAssertNil(draft.updateRequest().endDate)
    }
    func testUnknownEducationLevelRemainsReadableAndOmitted() {
        var draft = education(level: "legacy degree level")
        XCTAssertEqual(draft.educationLevelLabel, "legacy degree level")
        XCTAssertNil(draft.updateRequest().educationLevel)
        draft.selectEducationLevel(.other)
        XCTAssertEqual(draft.updateRequest().educationLevel, "other")
    }
    func testYearPrecisionLegacyAnchorSurvivesUnrelatedEdit() {
        var draft = education(precision: "year")
        draft.grade = "Updated grade"
        XCTAssertEqual(draft.updateRequest().startDate, "2020-06-15")
        XCTAssertEqual(draft.updateRequest().startDatePrecision, "year")
    }
    func testMissingPrecisionSurvivesUnrelatedEdit() {
        var draft = education(precision: nil)
        draft.grade = "Updated grade"
        XCTAssertEqual(draft.updateRequest().startDate, "2020-06-15")
        XCTAssertNil(draft.updateRequest().startDatePrecision)
    }
    func testExplicitPrecisionChangeUsesCorrectWireAnchor() {
        var draft = education(precision: "day")
        draft.startPrecision = .month
        XCTAssertEqual(draft.updateRequest().startDate, "2020-06-01")
        XCTAssertEqual(draft.updateRequest().startDatePrecision, "month")
        draft.startPrecision = .year
        XCTAssertEqual(draft.updateRequest().startDate, "2020-01-01")
        XCTAssertEqual(draft.updateRequest().startDatePrecision, "year")
    }
    func testPrecisionDisplayChangesImmediatelyWithoutChangingDate() {
        let value = date()
        let day = CandidateDateInput.display(value, precision: .day)
        let month = CandidateDateInput.display(value, precision: .month)
        let year = CandidateDateInput.display(value, precision: .year)
        XCTAssertNotEqual(day, month)
        XCTAssertNotEqual(month, year)
        XCTAssertEqual(year, "2020")
        XCTAssertFalse(year.contains("Jan"))
        XCTAssertEqual(value, date())
    }
    func testNullDisplayAndNewDraftNeverInventDates() {
        XCTAssertEqual(CandidateDateInput.display(nil, precision: .year), "Not set")
        XCTAssertFalse(CareerEmploymentDraft().includesStartDate)
        XCTAssertFalse(CareerEducationDraft().includesStartDate)
        XCTAssertFalse(CareerCertificationDraft().includesIssuedDate)
        XCTAssertFalse(CareerProjectDraft().includesStartDate)
    }
    func testInvalidDatesAreNotNormalizedIntoDifferentDays() {
        XCTAssertNil(CandidateDateInput.date(year: "2025", month: 2, day: 29))
        XCTAssertNil(CandidateDateInput.date(year: "2026", month: 4, day: 31))
        XCTAssertNil(CandidateDateInput.date(year: "0"))
        XCTAssertNil(CandidateDateInput.date(year: "10000"))
        XCTAssertNil(CandidateDateInput.date(year: "invalid"))
        XCTAssertNotNil(CandidateDateInput.date(year: "2024", month: 2, day: 29))
    }
    func testEducationCreateRequiresLevelAndStartButNotStudyOrEnd() {
        var draft = CareerEducationDraft()
        draft.institutionName = "Synthetic institution"
        draft.degree = "Unlisted degree"
        XCTAssertNotNil(draft.validationErrors(mode: .create)["education_level"])
        XCTAssertNotNil(draft.validationErrors(mode: .create)["start_date"])
        draft.selectEducationLevel(.other)
        draft.startDate = date()
        XCTAssertTrue(draft.validationErrors(mode: .create).isEmpty)
        XCTAssertNil(draft.createRequest().endDate)
        XCTAssertNil(draft.createRequest().fieldOfStudy)
    }
    func testDateOrderingUsesEncodedPrecisionNotHiddenDayOrTime() {
        var draft = education(precision: "day")
        draft.endDate = CandidateDateInput.date(year: "2020", month: 6, day: 20)!
        draft.endPrecision = .month
        XCTAssertNotNil(draft.validationErrors()["end_date"], "June 1 would precede June 15 on the wire")
        var employment = employment()
        employment.startDate = date().addingTimeInterval(3600)
        employment.endDate = date()
        XCTAssertNil(employment.validationErrors()["end_date"], "The same calendar day must remain valid")
    }
    func testExpectedGraduationYearUsesBackendRangeRatherThanCurrentYearCutoff() {
        var entry = ManualEducationEntry.blank(id: 0)
        entry.startYear = "2026"; entry.endYear = "2032"
        XCTAssertNil(ManualProfileValidation.educationError(for: .endYear, in: entry))
    }
    func testCurrentEducationConflictRequiresExplicitResolution() {
        var draft = education()
        draft.endDate = date()
        draft.isCurrentlyStudying = true
        XCTAssertNotNil(draft.validationErrors()["end_date"])
        XCTAssertNotNil(draft.updateRequest().endDate)
        draft.includesEndDate = false
        XCTAssertNil(draft.updateRequest().endDate)
        XCTAssertNil(draft.updateRequest().endDatePrecision)
        XCTAssertNil(draft.validationErrors()["end_date"])
    }
    func testCertificationRequiredIssueAndExplicitExpiryConflict() {
        var draft = CareerCertificationDraft()
        draft.title = "Synthetic certificate"; draft.issuingOrganization = "Synthetic issuer"
        XCTAssertNotNil(draft.validationErrors(mode: .create)["issued_date"])
        draft.issuedDate = date(); draft.expiryDate = date(); draft.doesNotExpire = true
        XCTAssertNotNil(draft.validationErrors()["expiry_date"])
        XCTAssertNotNil(draft.updateRequest().expiryDate)
        draft.includesExpiryDate = false
        XCTAssertTrue(draft.validationErrors(mode: .create).isEmpty)
        XCTAssertNil(draft.updateRequest().expiryDate)
    }
    func testManualCurrentEducationAndOptionalFieldsValidate() {
        var entry = ManualEducationEntry.blank(id: 0)
        entry.institution = "Synthetic institution"; entry.degree = "Unlisted degree"
        entry.educationLevel = "other"; entry.startYear = "2020"; entry.isCurrentlyStudying = true
        XCTAssertTrue(ManualProfileValidation.isEducationEntryValid(entry))
        entry.endYear = "2024"
        XCTAssertNotNil(ManualProfileValidation.educationError(for: .endYear, in: entry))
    }
    private func date() -> Date { CandidateDateInput.date(year: "2020", month: 6, day: 15)! }
    private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(value)) as? [String: Any])
    }
    private func employment(type: String? = "full_time", arrangement: String? = "onsite", country: String? = nil) -> CareerEmploymentDraft {
        .init(record: .init(id: "synthetic", subjectFullName: nil, subjectEmail: nil,
            company: "Synthetic", employerLegalName: "Synthetic", employerTradeName: nil, role: "Engineer",
            employmentType: type, startDate: nil, endDate: nil, currentlyWorking: false,
            workLocationCountry: country, workLocationRegion: nil, workArrangement: arrangement,
            verificationMethod: "document", verificationStatus: .notVerified, rawVerificationStatus: "draft"))
    }
    private func education(level: String? = "bachelors", precision: String? = "year") -> CareerEducationDraft {
        .init(record: .init(id: "synthetic", institution: "Synthetic", degree: "Unlisted degree",
            fieldOfStudy: nil, educationLevel: level, grade: nil, startDate: date(), startDatePrecision: precision,
            endDate: nil, endDatePrecision: nil, isCurrentlyStudying: false,
            verificationStatus: .notVerified, rawVerificationStatus: "draft"))
    }
}
