import Foundation
import XCTest
@testable import Kairo

final class ManualProfileMapperTests: XCTestCase {
    func testInstitutionSelectionSurvivesOnboardingPayloadAndDraftRestore() throws {
        var draft = makeDraft()
        draft.updateEducation(id: 0) { $0.selectInstitution(.init(name: "Synthetic Institute", catalogueID: "synthetic-id", catalogueVersion: "test-v1")) }
        let restored = try JSONDecoder().decode(ManualProfileFlowState.self, from: JSONEncoder().encode(draft))
        let request = try ManualProfileMapper.makeSubmissionPayloads(draft: restored, currentUser: makeUser()).educations[0].request
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(json["institution_catalogue_id"] as? String, "synthetic-id")
        XCTAssertEqual(json["institution_catalogue_version"] as? String, "test-v1")
        draft.updateEducation(id: 0) { $0.institution = "Historical custom name" }
        let manual = try ManualProfileMapper.makeSubmissionPayloads(draft: draft, currentUser: makeUser()).educations[0].request
        let cleared = try XCTUnwrap(JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(manual)) as? [String: Any])
        XCTAssertTrue(cleared["institution_catalogue_id"] is NSNull)
        XCTAssertTrue(cleared["institution_catalogue_version"] is NSNull)
        XCTAssertEqual(cleared["institution_name"] as? String, "Historical custom name")
    }
    func testPickerNumericMonthRoundTripsHistoricalExactDate() throws {
        var draft = makeDraft()
        let selected = try XCTUnwrap(CandidateDateInput.date(year: "1999", month: 8, day: 29))
        let parts = CandidateDateInput.calendar.dateComponents([.day, .month, .year], from: selected)
        draft.updateEmployment(id: 0) {
            $0.startDay = String(parts.day!)
            $0.startMonth = String(parts.month!)
            $0.startYear = String(parts.year!)
        }
        let entry = draft.employmentEntries[0]
        let month = try XCTUnwrap(ManualProfileNormalization.normalizedMonthNumber(entry.startMonth))
        XCTAssertEqual(CandidateDateInput.date(year: entry.startYear, month: month, day: Int(entry.startDay)!), selected)
        let payload = try ManualProfileMapper.makeSubmissionPayloads(draft: draft, currentUser: makeUser())
        XCTAssertEqual(payload.employments[0].request.startDate, "1999-08-29")
    }

    func testMonthNamesAndAllPickerNumericMonthsNormalizeWithoutLosingPrecision() {
        for month in 1...12 {
            XCTAssertEqual(ManualProfileNormalization.normalizedMonthNumber(String(month)), month)
            XCTAssertEqual(ManualProfileNormalization.normalizedMonthNumber(String(format: "%02d", month)), month)
        }
        XCTAssertEqual(ManualProfileNormalization.normalizedMonthNumber("August"), 8)
        for invalid in ["0", "13", "2x", "1.2", "-1", ""] {
            XCTAssertNil(ManualProfileNormalization.normalizedMonthNumber(invalid), invalid)
        }
    }

    func test_optionalLocationStudyAndEndDatesAreOmittedUsingAPI43Contract() throws {
        var draft = makeDraft()
        draft.basicProfile.currentCity = ""
        draft.basicProfile.currentCountry = ""
        draft.updateEmployment(id: 0) { $0.workCountry = ""; $0.isCurrentlyWorking = false; $0.endDay = ""; $0.endMonth = ""; $0.endYear = "" }
        draft.updateEducation(id: 0) { $0.fieldOfStudy = ""; $0.endYear = ""; $0.isCurrentlyStudying = true }
        let payload = try ManualProfileMapper.makeSubmissionPayloads(draft: draft, currentUser: makeUser())
        XCTAssertNil(payload.employments[0].request.workLocationCountry)
        XCTAssertNil(payload.employments[0].request.endDate)
        XCTAssertNil(payload.educations[0].request.fieldOfStudy)
        XCTAssertNil(payload.educations[0].request.endDate)
        XCTAssertNil(payload.educations[0].request.endDatePrecision)
        XCTAssertTrue(payload.educations[0].request.isCurrentlyStudying)
    }

    func test_zeroExperienceSubmissionEmitsNoEmploymentOrEducationCreates() throws {
        var draft = makeDraft()
        draft.basicProfile.yearsOfExperience = "0"
        draft.skipEmployment()
        draft.skipEducation()
        let payload = try ManualProfileMapper.makeSubmissionPayloads(draft: draft, currentUser: makeUser())
        XCTAssertTrue(payload.employments.isEmpty)
        XCTAssertTrue(payload.educations.isEmpty)
        XCTAssertEqual(payload.profile.yearsOfExperience, 0)
    }
    func test_makeSubmissionPayloadsMapsBasicProfileEmploymentAndEducation() throws {
        let payloads = try ManualProfileMapper.makeSubmissionPayloads(
            draft: makeDraft(),
            currentUser: makeUser()
        )

        XCTAssertEqual(payloads.profile.fullName, "Aman Jha")
        XCTAssertEqual(payloads.profile.headline, "Trust Operations Specialist")
        XCTAssertEqual(payloads.profile.currentRole, "Trust Operations Specialist")
        XCTAssertEqual(payloads.profile.industry, "Technology")
        XCTAssertEqual(payloads.profile.yearsOfExperience, 4)
        XCTAssertEqual(payloads.profile.location, "Bengaluru, India")
        XCTAssertEqual(payloads.profile.locationCity, "Bengaluru")
        XCTAssertEqual(payloads.profile.locationCountry, "IN")

        XCTAssertEqual(payloads.employments.count, 1)
        XCTAssertEqual(payloads.employments[0].request.subjectFullName, "Aman Jha")
        XCTAssertEqual(payloads.employments[0].request.subjectEmail, "aman@example.com")
        XCTAssertEqual(payloads.employments[0].request.employerLegalName, "Meridian Trust")
        XCTAssertEqual(payloads.employments[0].request.employmentType, "full_time")
        XCTAssertEqual(payloads.employments[0].request.startDate, "2022-01-01")
        XCTAssertNil(payloads.employments[0].request.endDate)
        XCTAssertEqual(payloads.employments[0].request.workLocationCountry, "IN")

        XCTAssertEqual(payloads.educations.count, 1)
        XCTAssertEqual(payloads.educations[0].request.institutionName, "Delhi Institute of Technology")
        XCTAssertEqual(payloads.educations[0].request.degree, "B.Tech")
        XCTAssertEqual(payloads.educations[0].request.educationLevel, "bachelors")
        XCTAssertEqual(payloads.educations[0].request.startDate, "2016-01-01")
        XCTAssertEqual(payloads.educations[0].request.startDatePrecision, "year")
        XCTAssertEqual(payloads.educations[0].request.endDate, "2020-01-01")
        XCTAssertEqual(payloads.educations[0].request.endDatePrecision, "year")
        XCTAssertFalse(payloads.educations[0].request.isCurrentlyStudying)
    }

    func test_makeSubmissionPayloadsFallsBackToCreateAccountNameWhenCurrentUserNameMissing() throws {
        var draft = makeDraft()
        draft.basicProfile.fullName = "Aman Jha"

        let payloads = try ManualProfileMapper.makeSubmissionPayloads(
            draft: draft,
            currentUser: makeUser(fullName: nil)
        )

        XCTAssertEqual(payloads.profile.fullName, "Aman Jha")
        XCTAssertEqual(payloads.employments[0].request.subjectFullName, "Aman Jha")
    }

    func test_makeSubmissionPayloadsUsesDraftFullNameWhenCurrentUserNameMissing() throws {
        var draft = makeDraft()
        draft.basicProfile.fullName = "Aman QA"

        let payloads = try ManualProfileMapper.makeSubmissionPayloads(
            draft: draft,
            currentUser: makeUser(fullName: nil)
        )

        XCTAssertEqual(payloads.profile.fullName, "Aman QA")
        XCTAssertEqual(payloads.employments[0].request.subjectFullName, "Aman QA")
    }

    func test_makeSubmissionPayloadsAcceptsMonthWithInvisibleSeparatorCharacters() throws {
        var draft = makeDraft()
        draft.updateEmployment(id: 0) { entry in
            entry.startMonth = "Ja\u{200B}nuary"
        }

        let payloads = try ManualProfileMapper.makeSubmissionPayloads(
            draft: draft,
            currentUser: makeUser()
        )

        XCTAssertEqual(payloads.employments[0].request.startDate, "2022-01-01")
    }

    func test_makeSubmissionPayloadsRejectsMissingFullNameWhenNoSourcesExist() {
        var draft = makeDraft()
        draft.basicProfile.fullName = ""

        XCTAssertThrowsError(
            try ManualProfileMapper.makeSubmissionPayloads(
                draft: draft,
                currentUser: makeUser(fullName: nil)
            )
        ) { error in
            XCTAssertEqual(error as? ManualProfileMappingError, .missingFullName)
        }
    }

    func test_makeSubmissionPayloadsRejectsUnsupportedEmploymentType() {
        var draft = makeDraft()
        draft.updateEmployment(id: 0) { entry in
            entry.employmentType = "Volunteer"
        }

        XCTAssertThrowsError(
            try ManualProfileMapper.makeSubmissionPayloads(
                draft: draft,
                currentUser: makeUser()
            )
        ) { error in
            XCTAssertEqual(
                error as? ManualProfileMappingError,
                .employment(
                    entryID: 0,
                    field: .employmentType,
                    message: "Choose a supported employment type."
                )
            )
        }
    }

    func test_makeSubmissionPayloadsRejectsUnsupportedEducationLevel() {
        var draft = makeDraft()
        draft.updateEducation(id: 0) { entry in
            entry.educationLevel = "Bootcamp"
        }

        XCTAssertThrowsError(
            try ManualProfileMapper.makeSubmissionPayloads(
                draft: draft,
                currentUser: makeUser()
            )
        ) { error in
            XCTAssertEqual(
                error as? ManualProfileMappingError,
                .education(
                    entryID: 0,
                    field: .educationLevel,
                    message: "Choose a supported education level."
                )
            )
        }
    }

    func test_makeSubmissionPayloadsSkipsPersistedImportedRecords() throws {
        var draft = makeDraft()
        draft.employmentEntries = [
            ManualEmploymentEntry(
                id: 0,
                isPersisted: true,
                company: "Northstar Analytics Private Limited",
                jobTitle: "Product Operations Manager",
                employmentType: "Other",
                workCountry: "",
                startDay: "",
                startMonth: "",
                startYear: "",
                endDay: "",
                endMonth: "",
                endYear: "",
                isCurrentlyWorking: true
            )
        ]
        draft.educationEntries = [
            ManualEducationEntry(
                id: 0,
                isPersisted: true,
                institution: "Riverdale Institute of Technology",
                degree: "Bachelor of Technology (B.Tech)",
                educationLevel: "Bachelor's",
                fieldOfStudy: "Information Technology",
                startYear: "",
                endYear: ""
            )
        ]

        let payloads = try ManualProfileMapper.makeSubmissionPayloads(
            draft: draft,
            currentUser: makeUser(fullName: "Resume QA")
        )

        XCTAssertEqual(payloads.employments, [])
        XCTAssertEqual(payloads.educations, [])
    }

    private func makeDraft() -> ManualProfileFlowState {
        var draft = ManualProfileFlowState()
        draft.basicProfile = ManualProfileBasicDraft(
            fullName: "Aman Jha",
            professionalHeadline: "Trust Operations Specialist",
            currentRole: "Trust Operations Specialist",
            industry: "Technology",
            yearsOfExperience: "4",
            currentCity: "Bengaluru",
            currentCountry: "India"
        )
        draft.updateEmployment(id: 0) { entry in
            entry.company = "Meridian Trust"
            entry.jobTitle = "Trust Operations Specialist"
            entry.employmentType = "Full-time"
            entry.workCountry = "India"
            entry.startDay = "1"
            entry.startMonth = "January"
            entry.startYear = "2022"
            entry.isCurrentlyWorking = true
        }
        draft.updateEducation(id: 0) { entry in
            entry.institution = "Delhi Institute of Technology"
            entry.degree = "B.Tech"
            entry.educationLevel = "Bachelor's"
            entry.fieldOfStudy = "Information Technology"
            entry.startYear = "2016"
            entry.endYear = "2020"
        }
        return draft
    }

    private func makeUser(fullName: String? = "Aman Jha") -> AppUser {
        AppUser(
            id: "user_123",
            email: "aman@example.com",
            fullName: fullName,
            profileSlug: "aman-jha",
            phone: "+919876543210",
            currentRole: nil,
            industry: nil,
            yearsOfExperience: nil,
            location: nil,
            locationCity: nil,
            locationRegion: nil,
            locationCountry: nil,
            headline: nil,
            bio: nil,
            dateOfBirth: nil,
            avatarURL: nil,
            role: "user",
            isActive: true,
            phoneVerifiedAt: Date(),
            emailVerifiedAt: Date(),
            employmentOnboardingCompletedAt: nil,
            languages: [],
            professionalLinks: [],
            profileCompletionPercentage: 75,
            createdAt: Date()
        )
    }
}
