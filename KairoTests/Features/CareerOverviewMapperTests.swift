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
                    company: "Northline Career Services",
                    role: "Trust & Operations Associate",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2024, month: 1, day: 1),
                    endDate: nil,
                    currentlyWorking: true,
                    verificationStatus: .verified
                )
            ],
            educations: [
                CareerEducationRecord(
                    id: "education_1",
                    institution: "Christ University",
                    degree: "BBA",
                    fieldOfStudy: "Human Resources & Operations",
                    startYear: 2016,
                    endYear: 2019,
                    verificationStatus: .pending
                )
            ],
            certifications: [
                CareerCertificationRecord(
                    id: "certification_1",
                    title: "People Operations Foundations",
                    issuer: "Northline Academy",
                    issueDate: makeUTCTimestamp(year: 2025, month: 3, day: 1),
                    verificationStatus: .notVerified
                )
            ],
            projects: [
                CareerProjectRecord(
                    id: "project_1",
                    title: "Career Trust Onboarding Pilot",
                    role: "Program Lead",
                    startDate: makeUTCTimestamp(year: 2025, month: 1, day: 1),
                    endDate: makeUTCTimestamp(year: 2025, month: 6, day: 1),
                    portfolioURL: URL(string: "https://portfolio.example.com/projects/1"),
                    verificationStatus: .verified
                )
            ],
            skills: [
                CareerSkillRecord(id: "skill_1", name: "Trust Operations"),
                CareerSkillRecord(id: "skill_2", name: "Employment Verification")
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
        XCTAssertEqual(content.employment.first?.dateRange, "Jan 2024 – Present")
        XCTAssertEqual(content.education.first?.degree, "BBA in Human Resources & Operations")
        XCTAssertEqual(content.education.first?.verificationStatus, .pendingVerification)
        XCTAssertEqual(content.certifications.first?.issueDate, "Mar 2025")
        XCTAssertEqual(content.projects.first?.portfolioLinkTitle, "portfolio.example.com")
        XCTAssertEqual(content.projects.first?.verificationStatus, .verified)
        XCTAssertEqual(content.skills, ["Trust Operations", "Employment Verification"])
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
                    company: "Northline Career Services",
                    role: "Operations Associate",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2023, month: 1, day: 1),
                    endDate: nil,
                    currentlyWorking: true,
                    verificationStatus: .pending
                ),
                CareerEmploymentRecord(
                    id: "employment_finished",
                    company: "BrightPath Technologies",
                    role: "Candidate Success Specialist",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2021, month: 8, day: 1),
                    endDate: makeUTCTimestamp(year: 2022, month: 12, day: 1),
                    currentlyWorking: false,
                    verificationStatus: .verified
                ),
                CareerEmploymentRecord(
                    id: "employment_newer_current",
                    company: "Kairo Labs",
                    role: "Trust Program Lead",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2024, month: 6, day: 1),
                    endDate: nil,
                    currentlyWorking: true,
                    verificationStatus: .verified
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
                    company: "Northline Career Services",
                    role: "Operations Associate",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2020, month: 1, day: 1),
                    endDate: makeUTCTimestamp(year: 2022, month: 1, day: 1),
                    currentlyWorking: false,
                    verificationStatus: .pending
                ),
                CareerEmploymentRecord(
                    id: "employment_newer",
                    company: "Kairo Labs",
                    role: "Trust Program Lead",
                    employmentType: "full_time",
                    startDate: makeUTCTimestamp(year: 2023, month: 6, day: 1),
                    endDate: makeUTCTimestamp(year: 2024, month: 5, day: 1),
                    currentlyWorking: false,
                    verificationStatus: .verified
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
