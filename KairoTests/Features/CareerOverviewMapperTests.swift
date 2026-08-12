import Foundation
import XCTest
@testable import Kairo

final class CareerOverviewMapperTests: XCTestCase {
    func test_mapCreatesPopulatedCareerStateFromLiveOverview() {
        let overview = CareerOverview(
            user: makeUser(),
            employments: [
                CareerEmploymentRecord(
                    id: "employment_1",
                    subjectFullName: "Aarav Mehta",
                    subjectEmail: "aarav@example.com",
                    company: "Northline Career Services",
                    employerLegalName: "Northline Career Services",
                    employerTradeName: nil,
                    role: "Trust & Operations Associate",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2024, month: 1, day: 1),
                    endDate: nil,
                    currentlyWorking: true,
                    workLocationCountry: "India",
                    workLocationRegion: "Karnataka",
                    verificationMethod: "document",
                    verificationStatus: .verified,
                    rawVerificationStatus: "approved"
                )
            ],
            educations: [
                CareerEducationRecord(
                    id: "education_1",
                    institution: "Christ University",
                    degree: "BBA",
                    fieldOfStudy: "Human Resources & Operations",
                    educationLevel: "bachelors",
                    grade: nil,
                    startDate: makeUTCTimestamp(year: 2016, month: 6, day: 1),
                    startDatePrecision: "year",
                    endDate: makeUTCTimestamp(year: 2019, month: 4, day: 1),
                    endDatePrecision: "year",
                    isCurrentlyStudying: false,
                    verificationStatus: .pending,
                    rawVerificationStatus: "pending"
                )
            ],
            certifications: [
                CareerCertificationRecord(
                    id: "certification_1",
                    title: "People Operations Foundations",
                    issuer: "Northline Academy",
                    issueDate: makeUTCTimestamp(year: 2025, month: 3, day: 1),
                    expiryDate: nil,
                    doesNotExpire: false,
                    credentialID: nil,
                    credentialURL: nil,
                    originalFilename: nil,
                    contentType: nil,
                    byteSize: nil,
                    verificationStatus: .notVerified,
                    rawVerificationStatus: "draft"
                )
            ],
            projects: [
                CareerProjectRecord(
                    id: "project_1",
                    title: "Career Trust Onboarding Pilot",
                    role: "Program Lead",
                    description: "Career onboarding pilot",
                    startDate: makeUTCTimestamp(year: 2025, month: 1, day: 1),
                    endDate: makeUTCTimestamp(year: 2025, month: 6, day: 1),
                    isOngoing: false,
                    projectURL: URL(string: "https://portfolio.example.com/projects/1"),
                    repositoryURL: nil,
                    organizationName: "Kairo",
                    verificationStatus: .verified,
                    rawVerificationStatus: "approved"
                )
            ],
            skills: [
                CareerSkillRecord(
                    id: "skill_1",
                    name: "Trust Operations",
                    verificationStatus: .verified,
                    rawVerificationStatus: "verified"
                ),
                CareerSkillRecord(
                    id: "skill_2",
                    name: "Employment Verification",
                    verificationStatus: .pending,
                    rawVerificationStatus: "pending_verification"
                )
            ]
        )

        let state = CareerOverviewMapper.map(overview)

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated Career state")
        }

        XCTAssertEqual(state.dataSourceLabel, "Live data")
        XCTAssertEqual(state.summary.initials, "AM")
        XCTAssertEqual(state.summary.name, "Aarav Mehta")
        XCTAssertEqual(state.summary.currentCompany, "Northline Career Services")
        XCTAssertEqual(state.summary.trustPassportStatus, "Active")
        XCTAssertEqual(content.employment.first?.routeID, "employment_1")
        XCTAssertEqual(content.employment.first?.dateRange, "Jan 2024 – Present")
        XCTAssertFalse(content.employment.first?.allowsEdit ?? true)
        XCTAssertFalse(content.employment.first?.allowsDelete ?? true)
        XCTAssertEqual(content.education.first?.routeID, "education_1")
        XCTAssertEqual(content.education.first?.degree, "BBA in Human Resources & Operations")
        XCTAssertEqual(content.education.first?.dateRange, "2016 – 2019")
        XCTAssertEqual(content.education.first?.verificationStatus, .pendingVerification)
        XCTAssertEqual(content.certifications.first?.routeID, "certification_1")
        XCTAssertEqual(content.certifications.first?.issueDate, "Mar 2025")
        XCTAssertEqual(content.projects.first?.routeID, "project_1")
        XCTAssertEqual(content.projects.first?.portfolioLinkTitle, "portfolio.example.com")
        XCTAssertEqual(content.projects.first?.verificationStatus, .verified)
        XCTAssertEqual(content.skills.map(\.routeID), ["skill_1", "skill_2"])
        XCTAssertEqual(content.skills.map(\.name), ["Trust Operations", "Employment Verification"])
        XCTAssertEqual(content.skills.map(\.verificationStatus), [.verified, .pendingVerification])
        XCTAssertEqual(
            content.visibleSections,
            [.professionalSummary, .employment, .education, .certifications, .projects, .skills]
        )
    }

    func test_mapCreatesEmptyCareerStateWhenBackendCollectionsAreEmpty() {
        let overview = CareerOverview(
            user: makeUser(),
            employments: [],
            educations: [],
            certifications: [],
            projects: [],
            skills: []
        )

        let state = CareerOverviewMapper.map(overview)

        guard case .empty(let content) = state.phase else {
            return XCTFail("Expected empty Career state")
        }

        XCTAssertEqual(state.summary.name, "Aarav Mehta")
        XCTAssertTrue(content.employment.isEmpty)
        XCTAssertTrue(content.education.isEmpty)
        XCTAssertEqual(content.visibleSections, [.professionalSummary])
    }

    func test_mapSelectsMostRecentCurrentEmploymentIndependentlyOfArrayOrder() {
        let overview = CareerOverview(
            user: makeUser(),
            employments: [
                CareerEmploymentRecord(
                    id: "employment_older_current",
                    subjectFullName: nil,
                    subjectEmail: nil,
                    company: "Northline Career Services",
                    employerLegalName: "Northline Career Services",
                    employerTradeName: nil,
                    role: "Operations Associate",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2023, month: 1, day: 1),
                    endDate: nil,
                    currentlyWorking: true,
                    workLocationCountry: nil,
                    workLocationRegion: nil,
                    verificationMethod: nil,
                    verificationStatus: .pending,
                    rawVerificationStatus: "pending"
                ),
                CareerEmploymentRecord(
                    id: "employment_finished",
                    subjectFullName: nil,
                    subjectEmail: nil,
                    company: "BrightPath Technologies",
                    employerLegalName: "BrightPath Technologies",
                    employerTradeName: nil,
                    role: "Candidate Success Specialist",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2021, month: 8, day: 1),
                    endDate: makeUTCTimestamp(year: 2022, month: 12, day: 1),
                    currentlyWorking: false,
                    workLocationCountry: nil,
                    workLocationRegion: nil,
                    verificationMethod: nil,
                    verificationStatus: .verified,
                    rawVerificationStatus: "approved"
                ),
                CareerEmploymentRecord(
                    id: "employment_newer_current",
                    subjectFullName: nil,
                    subjectEmail: nil,
                    company: "Kairo Labs",
                    employerLegalName: "Kairo Labs",
                    employerTradeName: nil,
                    role: "Trust Program Lead",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2024, month: 6, day: 1),
                    endDate: nil,
                    currentlyWorking: true,
                    workLocationCountry: nil,
                    workLocationRegion: nil,
                    verificationMethod: nil,
                    verificationStatus: .verified,
                    rawVerificationStatus: "approved"
                )
            ],
            educations: [],
            certifications: [],
            projects: [],
            skills: []
        )

        let state = CareerOverviewMapper.map(overview)

        XCTAssertEqual(state.summary.currentCompany, "Kairo Labs")
    }

    func test_mapFallsBackToMostRecentEmploymentWhenNoCurrentEmploymentExists() {
        let overview = CareerOverview(
            user: makeUser(),
            employments: [
                CareerEmploymentRecord(
                    id: "employment_older",
                    subjectFullName: nil,
                    subjectEmail: nil,
                    company: "Northline Career Services",
                    employerLegalName: "Northline Career Services",
                    employerTradeName: nil,
                    role: "Operations Associate",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2020, month: 1, day: 1),
                    endDate: makeUTCTimestamp(year: 2022, month: 1, day: 1),
                    currentlyWorking: false,
                    workLocationCountry: nil,
                    workLocationRegion: nil,
                    verificationMethod: nil,
                    verificationStatus: .pending,
                    rawVerificationStatus: "pending"
                ),
                CareerEmploymentRecord(
                    id: "employment_newer",
                    subjectFullName: nil,
                    subjectEmail: nil,
                    company: "Kairo Labs",
                    employerLegalName: "Kairo Labs",
                    employerTradeName: nil,
                    role: "Trust Program Lead",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2023, month: 6, day: 1),
                    endDate: makeUTCTimestamp(year: 2024, month: 5, day: 1),
                    currentlyWorking: false,
                    workLocationCountry: nil,
                    workLocationRegion: nil,
                    verificationMethod: nil,
                    verificationStatus: .verified,
                    rawVerificationStatus: "approved"
                )
            ],
            educations: [],
            certifications: [],
            projects: [],
            skills: []
        )

        let state = CareerOverviewMapper.map(overview)

        XCTAssertEqual(state.summary.currentCompany, "Kairo Labs")
    }

    func test_errorStateMapsTransportErrorToOfflineExperience() {
        let state = CareerOverviewMapper.errorState(
            for: NetworkError.transport("offline"),
            summary: .placeholder
        )

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error Career state")
        }

        XCTAssertEqual(errorState.title, "You're offline")
        XCTAssertTrue(errorState.message.contains("couldn't reach"))
    }

    func test_errorStateMapsDecodingErrorToRecoverableUnavailableExperience() {
        let error = DecodingError.keyNotFound(
            AnyCodingKey("company"),
            DecodingError.Context(codingPath: [], debugDescription: "Missing employment company.")
        )
        let state = CareerOverviewMapper.errorState(
            for: error,
            summary: .placeholder
        )

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error Career state")
        }

        XCTAssertEqual(errorState.title, "Career overview unavailable")
        XCTAssertFalse(errorState.message.isEmpty)
    }

    func test_errorStateMapsBackendApiErrorsToRecoverableUnavailableExperience() {
        let apiError = APIError(
            statusCode: 422,
            code: .validationError,
            message: "Career payload is invalid.",
            fieldErrors: [:],
            globalErrors: [],
            validationDetails: []
        )
        let state = CareerOverviewMapper.errorState(
            for: NetworkError.api(apiError),
            summary: .placeholder
        )

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error Career state")
        }

        XCTAssertEqual(errorState.title, "Career overview unavailable")
        XCTAssertEqual(errorState.message, "Career payload is invalid.")
    }

    func test_requiresSessionRecoveryOnlyForExpiredSession() {
        XCTAssertTrue(CareerOverviewMapper.requiresSessionRecovery(for: SessionServiceError.sessionExpired))
        XCTAssertFalse(CareerOverviewMapper.requiresSessionRecovery(for: SessionServiceError.missingAccessToken))
        XCTAssertFalse(CareerOverviewMapper.requiresSessionRecovery(for: NetworkError.transport("offline")))
    }

    private func makeUser() -> AppUser {
        AppUser(
            id: "user_123",
            email: "aarav@example.com",
            fullName: "Aarav Mehta",
            profileSlug: "aarav-mehta",
            phone: "+919876543210",
            currentRole: "Trust & Operations Associate",
            industry: "Technology",
            yearsOfExperience: 6,
            location: "Bengaluru, India",
            locationCity: "Bengaluru",
            locationRegion: "Karnataka",
            locationCountry: "India",
            headline: "Trust & Operations Associate",
            bio: "Building verified professional trust.",
            dateOfBirth: nil,
            avatarURL: nil,
            role: "user",
            isActive: true,
            phoneVerifiedAt: nil,
            emailVerifiedAt: nil,
            employmentOnboardingCompletedAt: nil,
            languages: [],
            professionalLinks: [],
            profileCompletionPercentage: 75,
            createdAt: makeUTCTimestamp(year: 2026, month: 7, day: 30, hour: 8, minute: 0, second: 0)!
        )
    }

    private func makeUTCTimestamp(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
