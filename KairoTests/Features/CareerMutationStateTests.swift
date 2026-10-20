import Foundation
import XCTest
@testable import Kairo

final class CareerMutationStateTests: XCTestCase {
    func test_unknownEmploymentDatesSurviveUnrelatedEditAndEncodeExplicitNull() throws {
        let record = CareerEmploymentRecord(id: "synthetic", subjectFullName: nil, subjectEmail: nil,
            company: "Synthetic", employerLegalName: "Synthetic", employerTradeName: nil,
            role: "Engineer", employmentType: "full_time", startDate: nil, endDate: nil,
            currentlyWorking: false, workLocationCountry: nil, workLocationRegion: nil,
            verificationMethod: "document", verificationStatus: .notVerified, rawVerificationStatus: "draft")
        var draft = CareerEmploymentDraft(record: record)
        draft.jobTitle = "Updated role"
        XCTAssertFalse(draft.includesStartDate)
        XCTAssertFalse(draft.includesEndDate)
        let wire = try JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(draft.updateRequest())) as! [String: Any]
        XCTAssertTrue(wire["start_date"] is NSNull)
        XCTAssertTrue(wire["end_date"] is NSNull)
    }

    func test_unknownEducationDateAndPrecisionRemainNull() throws {
        let record = CareerEducationRecord(id: "synthetic", institution: "Synthetic", degree: "Degree",
            fieldOfStudy: nil, educationLevel: nil, grade: nil, startDate: nil, startDatePrecision: nil,
            endDate: nil, endDatePrecision: nil, isCurrentlyStudying: false,
            verificationStatus: .notVerified, rawVerificationStatus: "draft")
        var draft = CareerEducationDraft(record: record)
        draft.grade = "Updated"
        let wire = try JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(draft.updateRequest())) as! [String: Any]
        for key in ["start_date", "end_date", "start_date_precision", "end_date_precision"] {
            XCTAssertTrue(wire[key] is NSNull, key)
        }
    }

    func test_explicitOptionalDateRemovalEncodesNullNotOmission() throws {
        var certification = CareerCertificationDraft()
        certification.includesIssuedDate = false
        certification.includesExpiryDate = false
        let cert = try JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(certification.updateRequest())) as! [String: Any]
        XCTAssertTrue(cert["issued_date"] is NSNull)
        XCTAssertTrue(cert["expiry_date"] is NSNull)
        var project = CareerProjectDraft()
        project.includesStartDate = false
        project.includesEndDate = false
        let wire = try JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(project.updateRequest())) as! [String: Any]
        XCTAssertTrue(wire["start_date"] is NSNull)
        XCTAssertTrue(wire["end_date"] is NSNull)
    }
    func test_employmentCreateRequestUsesCurrentUserIdentityAndOmitsEndDateForCurrentRole() {
        var draft = CareerEmploymentDraft()
        draft.employerLegalName = "  Northline Career Services  "
        draft.jobTitle = " Trust Operations Lead "
        draft.workArrangement = .hybrid
        draft.workLocationCity = " Bengaluru "
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
        XCTAssertEqual(request.workLocationCity, "Bengaluru")
        XCTAssertEqual(request.workArrangement, "hybrid")
    }

    func test_remoteEmploymentClearsLocationFieldsUsingBackendContract() {
        var draft = CareerEmploymentDraft()
        draft.employerLegalName = "Northline Career Services"
        draft.jobTitle = "Trust Operations Lead"
        draft.workArrangement = .remote
        draft.workLocationCity = "Bengaluru"
        draft.workLocationCountry = "India"
        draft.workLocationRegion = "Karnataka"

        XCTAssertNil(draft.validationErrors()["work_location_city"])
        XCTAssertNil(draft.validationErrors()["work_location_country"])
        let request = draft.createRequest(currentUser: makeUser())
        XCTAssertEqual(request.workArrangement, "remote")
        XCTAssertNil(request.workLocationCity)
        XCTAssertNil(request.workLocationCountry)
        XCTAssertNil(request.workLocationRegion)
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
        XCTAssertEqual(draft.existingDocumentFilename, "resume.pdf")
        XCTAssertNil(draft.updateRequest().issuedDate, "Opening an imported unknown date must not invent today")
    }

    func test_attachedCertificationFixtureRequiresExplicitUITestLaunchGuard() {
        let environment = ["KAIRO_UI_TEST_CAREER_STATE": "populated", "KAIRO_UI_TEST_ATTACHED_CERTIFICATION": "1"]
        XCTAssertFalse(UITestCareerConfiguration.current(arguments: [], environment: environment).showsAttachedCertificationEditor)
    }

    func test_projectOngoingConflictRequiresExplicitEndDateRemoval() {
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
        XCTAssertEqual(request.endDate, "2025-06-01")
        XCTAssertNotNil(draft.validationErrors()["end_date"])
        draft.includesEndDate = false
        XCTAssertNil(draft.updateRequest().endDate)
        XCTAssertNil(draft.validationErrors()["end_date"])
        XCTAssertEqual(request.isOngoing, true)
    }

    func test_portfolioDraftBuildsValidCreateRequestAndNormalizesTags() {
        var draft = CareerPortfolioDraft()
        draft.title = "  Inclusive finance case study  "
        draft.description = "  Research and interaction design.  "
        draft.url = "https://example.com/work"
        draft.tags = "Accessibility, iOS, accessibility, Research"

        XCTAssertTrue(draft.validationErrors().isEmpty)
        let request = draft.createRequest()
        XCTAssertEqual(request.title, "Inclusive finance case study")
        XCTAssertEqual(request.description, "Research and interaction design.")
        XCTAssertEqual(request.url, "https://example.com/work")
        XCTAssertEqual(request.tags, ["Accessibility", "iOS", "Research"])
    }

    func test_portfolioDraftRejectsEmptyTitleAndUnsafeURLs() {
        for value in ["javascript:alert(1)", "data:text/plain,secret", "file:///private/work.pdf", "https://user:secret@example.com/work"] {
            var draft = CareerPortfolioDraft()
            draft.url = value
            let errors = draft.validationErrors()
            XCTAssertEqual(errors["title"], "Enter the portfolio title.")
            XCTAssertEqual(errors["url"], "Enter a valid HTTP or HTTPS URL.")
        }
    }

    func test_portfolioEditDraftPreservesExistingAttachmentMetadata() {
        let record = PortfolioRecord(
            id: "portfolio_1",
            title: "Case study",
            description: "Before",
            url: URL(string: "https://example.com/work"),
            tags: ["Research"],
            originalFilename: "private-case-study.pdf",
            contentType: "application/pdf",
            byteSize: 2_048,
            uploadCompletedAt: Date()
        )

        var draft = CareerPortfolioDraft(record: record)
        draft.description = "After"

        XCTAssertEqual(draft.existingAttachmentFilename, "private-case-study.pdf")
        XCTAssertEqual(draft.updateRequest().description, "After")
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
        XCTAssertEqual(error.message, "Review the highlighted fields and try again.")
        XCTAssertEqual(error.fieldErrors["job_title"], "Enter the job title.")
    }

    func test_errorMapperNeverExposesBackendOrSystemErrorDetails() {
        let apiError = APIError(
            statusCode: 422,
            code: .validationError,
            message: "s3://private-bucket/internal-object",
            fieldErrors: ["job_title": ["database constraint career_records_job_title"]],
            globalErrors: ["Bearer secret-token"],
            validationDetails: []
        )

        let mappedAPI = CareerMutationErrorMapper.map(
            NetworkError.api(apiError),
            fallbackTitle: "Employment unavailable"
        )
        let mappedSystem = CareerMutationErrorMapper.map(
            NSError(domain: "secret.internal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bearer secret-token"]),
            fallbackTitle: "Employment unavailable"
        )

        XCTAssertEqual(mappedAPI.message, "Review the highlighted fields and try again.")
        XCTAssertEqual(mappedAPI.fieldErrors["job_title"], "Enter the job title.")
        XCTAssertEqual(mappedSystem.message, "KairoID couldn't complete that Career change. Please try again.")
        XCTAssertFalse(mappedAPI.message.contains("s3://"))
        XCTAssertFalse(mappedSystem.message.contains("Bearer"))
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
