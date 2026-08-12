import Foundation
import XCTest
@testable import Kairo

final class CareerMutationStateTests: XCTestCase {
    func test_employmentCreateRequestUsesCurrentUserIdentityAndOmitsEndDateForCurrentRole() {
        var draft = CareerEmploymentDraft()
        draft.employerLegalName = "  Northline Career Services  "
        draft.jobTitle = " Trust Operations Lead "
        draft.workLocationCountry = "India"
        draft.workLocationRegion = " Karnataka "
        draft.isCurrentlyWorking = true
        draft.startDate = makeUTCTimestamp(year: 2024, month: 1, day: 1)

        let request = draft.createRequest(currentUser: makeUser())

        XCTAssertEqual(request.subjectFullName, "Aarav Mehta")
        XCTAssertEqual(request.subjectEmail, "aarav@example.com")
        XCTAssertEqual(request.employerLegalName, "Northline Career Services")
        XCTAssertEqual(request.jobTitle, "Trust Operations Lead")
        XCTAssertEqual(request.verificationMethod, "document")
        XCTAssertEqual(request.startDate, "2024-01-01")
        XCTAssertNil(request.endDate)
        XCTAssertEqual(request.workLocationCountry, "IN")
        XCTAssertEqual(request.workLocationRegion, "Karnataka")
    }

    func test_employmentValidationRejectsEndDateEarlierThanStartDate() {
        var draft = CareerEmploymentDraft()
        draft.employerLegalName = "Northline Career Services"
        draft.jobTitle = "Trust Operations Lead"
        draft.workLocationCountry = "India"
        draft.isCurrentlyWorking = false
        draft.startDate = makeUTCTimestamp(year: 2024, month: 5, day: 1)
        draft.endDate = makeUTCTimestamp(year: 2024, month: 4, day: 1)

        XCTAssertEqual(
            draft.validationErrors()["end_date"],
            "End date must be after the start date."
        )
    }

    func test_educationCreateRequestPreservesYearPrecisionAndCurrentStudySemantics() {
        var draft = CareerEducationDraft()
        draft.institutionName = "Riverdale Institute of Technology"
        draft.degree = "Bachelor of Technology"
        draft.fieldOfStudy = "Information Technology"
        draft.educationLevel = .bachelors
        draft.startDate = makeUTCTimestamp(year: 2015, month: 6, day: 1)
        draft.startPrecision = .year
        draft.isCurrentlyStudying = true
        draft.includesEndDate = false

        let request = draft.createRequest()

        XCTAssertEqual(request.startDate, "2015-01-01")
        XCTAssertEqual(request.startDatePrecision, "year")
        XCTAssertNil(request.endDate)
        XCTAssertNil(request.endDatePrecision)
        XCTAssertTrue(request.isCurrentlyStudying)
    }

    func test_certificationDraftFromSparseImportedRecordKeepsMissingDatesAbsent() {
        let record = CareerCertificationRecord(
            id: "cert_1",
            title: "Certified Scrum Product Owner",
            issuer: "Scrum Alliance",
            issueDate: nil,
            expiryDate: nil,
            doesNotExpire: false,
            credentialID: nil,
            credentialURL: nil,
            originalFilename: "resume.pdf",
            contentType: "application/pdf",
            byteSize: 128,
            verificationStatus: .notVerified,
            rawVerificationStatus: "draft"
        )

        let draft = CareerCertificationDraft(record: record)

        XCTAssertFalse(draft.includesExpiryDate)
        XCTAssertFalse(draft.doesNotExpire)
        XCTAssertEqual(draft.title, "Certified Scrum Product Owner")
        XCTAssertEqual(draft.issuingOrganization, "Scrum Alliance")
    }

    func test_projectUpdateRequestOmitsEndDateForOngoingProject() {
        var draft = CareerProjectDraft()
        draft.title = "Vendor Intelligence Platform"
        draft.role = "Product Operations Manager"
        draft.includesStartDate = true
        draft.startDate = makeUTCTimestamp(year: 2025, month: 1, day: 1)
        draft.includesEndDate = true
        draft.endDate = makeUTCTimestamp(year: 2025, month: 6, day: 1)
        draft.isOngoing = true

        let request = draft.updateRequest()

        XCTAssertEqual(request.startDate, "2025-01-01")
        XCTAssertNil(request.endDate)
        XCTAssertEqual(request.isOngoing, true)
    }

    func test_skillValidationRejectsCaseInsensitiveDuplicates() {
        let draft = CareerSkillDraft(name: "sql")

        XCTAssertEqual(
            draft.validationErrors(existingNames: ["SQL"])["name"],
            "That skill already exists."
        )
    }

    func test_errorMapperFlattensValidationErrors() {
        let apiError = APIError(
            statusCode: 422,
            code: .validationError,
            message: "Request validation failed.",
            fieldErrors: [
                "job_title": ["Enter the job title."]
            ],
            globalErrors: [],
            validationDetails: []
        )

        let error = CareerMutationErrorMapper.map(NetworkError.api(apiError), fallbackTitle: "Employment unavailable")

        XCTAssertEqual(error.title, "Employment unavailable")
        XCTAssertEqual(error.message, "Request validation failed.")
        XCTAssertEqual(error.fieldErrors["job_title"], "Enter the job title.")
    }

    func test_errorMapperDistinguishesForbiddenAndNotFound() {
        let forbidden = APIError(
            statusCode: 403,
            code: .forbidden,
            message: "Forbidden",
            fieldErrors: [:],
            globalErrors: [],
            validationDetails: []
        )
        let notFound = APIError(
            statusCode: 404,
            code: .notFound,
            message: "Missing",
            fieldErrors: [:],
            globalErrors: [],
            validationDetails: []
        )

        XCTAssertEqual(
            CareerMutationErrorMapper.map(NetworkError.api(forbidden), fallbackTitle: "Fallback").title,
            "You can't change this record"
        )
        XCTAssertEqual(
            CareerMutationErrorMapper.map(NetworkError.api(notFound), fallbackTitle: "Fallback").title,
            "This record is no longer available"
        )
    }

    func test_errorMapperShowsOfflineMessageForTransportErrors() {
        let error = CareerMutationErrorMapper.map(
            NetworkError.transport("offline"),
            fallbackTitle: "Career unavailable"
        )

        XCTAssertEqual(error.title, "You're offline")
        XCTAssertTrue(error.message.contains("couldn't reach"))
    }

    private func makeUser() -> AppUser {
        AppUser(
            id: "user_123",
            email: "aarav@example.com",
            fullName: "Aarav Mehta",
            profileSlug: "aarav-mehta",
            phone: "+919876543210",
            currentRole: "Trust Operations Lead",
            industry: "Technology",
            yearsOfExperience: 7,
            location: "Bengaluru, India",
            locationCity: "Bengaluru",
            locationRegion: "Karnataka",
            locationCountry: "India",
            headline: "Trust Operations Lead",
            bio: nil,
            dateOfBirth: nil,
            avatarURL: nil,
            role: "user",
            isActive: true,
            phoneVerifiedAt: nil,
            emailVerifiedAt: nil,
            employmentOnboardingCompletedAt: nil,
            languages: [],
            professionalLinks: [],
            profileCompletionPercentage: 100,
            createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 1)
        )
    }

    private func makeUTCTimestamp(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
