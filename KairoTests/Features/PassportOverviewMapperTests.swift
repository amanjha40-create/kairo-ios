import Foundation
import XCTest
@testable import Kairo

final class PassportOverviewMapperTests: XCTestCase {
    func test_mapCreatesPopulatedPassportStateFromLiveOverview() {
        let overview = makeOverview()

        let state = PassportOverviewMapper.map(overview)

        XCTAssertEqual(state.header.name, "Aarav Mehta")
        XCTAssertEqual(state.header.professionalHeadline, "Trust Operations Lead")
        XCTAssertEqual(state.header.location, "Bengaluru, India")

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated Passport state")
        }

        guard case .available(let trustScore) = content.trustScore else {
            return XCTFail("Expected available Trust Score")
        }

        guard case .unavailable(let timeline) = content.timeline else {
            return XCTFail("Expected unavailable timeline treatment")
        }

        XCTAssertEqual(content.dataSourceLabel, "Live data")
        XCTAssertEqual(trustScore.value, 81)
        XCTAssertFalse(trustScore.isFixture)
        XCTAssertEqual(content.identity.emailAddress, "aarav@example.com")
        XCTAssertEqual(content.identity.mobileNumber, "+919876543210")
        XCTAssertEqual(content.employment.first?.company, "Northline Career Services")
        XCTAssertEqual(content.education.first?.dateRange, "Jun 2016 – May 2019")
        XCTAssertEqual(content.certifications, [])
        XCTAssertEqual(content.projects, [])
        XCTAssertEqual(content.skills.map(\.name), ["Trust Operations"])
        XCTAssertEqual(content.skills.first?.verificationStatus, .verified)
        XCTAssertEqual(content.strengthSummary.first?.title, "Identity")
        XCTAssertEqual(content.strengthSummary[3].value, "1 verified")
        XCTAssertEqual(content.strengthSummary[7].title, "Skills")
        XCTAssertEqual(content.strengthSummary[7].value, "4 verified")
        XCTAssertTrue(timeline.message.contains("does not currently provide"))
    }

    func test_mapCreatesHonestUnavailableTrustScoreWhenBackendDoesNotProvideValue() {
        var overview = makeOverview()
        overview = PassportOverview(
            user: overview.user,
            trustScore: PassportOverview.TrustScore(
                overall: nil,
                status: .consentRequired,
                breakdown: nil,
                domainDetails: [:],
                positiveContributors: [],
                negativeContributors: [],
                criticalOverrides: [],
                manualReviewReason: nil,
                scoreVersion: "v1",
                lastCalculatedAt: nil,
                verificationCompletenessPercentage: 0,
                weekChange: 0
            ),
            metadata: overview.metadata,
            sharingSummary: overview.sharingSummary,
            verificationSummary: overview.verificationSummary,
            vault: overview.vault
        )

        let state = PassportOverviewMapper.map(overview)

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated Passport state")
        }

        guard case .unavailable(let trustScore) = content.trustScore else {
            return XCTFail("Expected unavailable Trust Score state")
        }

        XCTAssertEqual(trustScore.title, "Consent required")
        XCTAssertTrue(trustScore.message.contains("consent"))
    }

    func test_mapCreatesEmptyPassportStateWhenVaultIsLegitimatelyEmpty() {
        let overview = PassportOverview(
            user: makeOverview().user,
            trustScore: makeOverview().trustScore,
            metadata: makeOverview().metadata,
            sharingSummary: makeOverview().sharingSummary,
            verificationSummary: PassportOverview.VerificationSummary(
                overall: .init(total: 0, statuses: [:]),
                employments: .init(total: 0, statuses: [:]),
                educations: .init(total: 0, statuses: [:]),
                certifications: .init(total: 0, statuses: [:]),
                skills: .init(total: 0, statuses: [:]),
                projects: .init(total: 0, statuses: [:])
            ),
            vault: PassportOverview.Vault(
                employments: [],
                educations: [],
                certifications: [],
                projects: [],
                skills: [],
                userDocuments: []
            )
        )

        let state = PassportOverviewMapper.map(overview)

        guard case .empty(let content) = state.phase else {
            return XCTFail("Expected empty Passport state")
        }

        XCTAssertEqual(content.dataSourceLabel, "Live data")
        XCTAssertTrue(content.message.contains("reuse throughout your career"))
    }

    func test_errorStateMapsTransportErrorToOfflineExperience() {
        let state = PassportOverviewMapper.errorState(
            for: NetworkError.transport("offline"),
            header: .fixture
        )

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error Passport state")
        }

        XCTAssertEqual(errorState.title, "You're offline")
        XCTAssertTrue(errorState.message.contains("couldn't reach"))
    }

    func test_errorStateMapsDecodingErrorToGenericPassportUnavailableExperience() {
        let state = PassportOverviewMapper.errorState(
            for: DecodingError.keyNotFound(
                DynamicCodingKey("ownerUserId"),
                .init(codingPath: [], debugDescription: "Missing ownerUserId")
            ),
            header: .fixture
        )

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error Passport state")
        }

        XCTAssertEqual(errorState.title, "Trust Passport unavailable")
        XCTAssertEqual(
            errorState.message,
            "Kairo received an unexpected Passport response. Please try again."
        )
    }

    func test_requiresSessionRecoveryOnlyForExpiredSession() {
        XCTAssertTrue(PassportOverviewMapper.requiresSessionRecovery(for: SessionServiceError.sessionExpired))
        XCTAssertFalse(PassportOverviewMapper.requiresSessionRecovery(for: SessionServiceError.missingAccessToken))
        XCTAssertFalse(PassportOverviewMapper.requiresSessionRecovery(for: NetworkError.transport("offline")))
    }

    private func makeOverview() -> PassportOverview {
        PassportOverview(
            user: AppUser(
                id: "user_123",
                email: "aarav@example.com",
                fullName: "Aarav Mehta",
                profileSlug: "aarav-mehta",
                phone: "+919876543210",
                currentRole: "Trust Operations Lead",
                industry: "Technology",
                yearsOfExperience: 6,
                location: "Bengaluru, India",
                locationCity: "Bengaluru",
                locationRegion: "Karnataka",
                locationCountry: "India",
                headline: "Trust Operations Lead",
                bio: nil,
                dateOfBirth: nil,
                avatarURL: "https://cdn.example.com/avatar.png",
                role: "user",
                isActive: true,
                phoneVerifiedAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 10, minute: 15, second: 30),
                emailVerifiedAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 10, minute: 14, second: 10),
                employmentOnboardingCompletedAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 10, minute: 20, second: 0),
                languages: [],
                professionalLinks: [],
                profileCompletionPercentage: 100,
                createdAt: makeUTCTimestamp(year: 2026, month: 7, day: 30, hour: 8, minute: 0, second: 0)!
            ),
            trustScore: PassportOverview.TrustScore(
                overall: 81,
                status: .calculated,
                breakdown: TrustScoreComponentBreakdownDTO(identity: 1.0, employment: 0.75, education: 0.5),
                domainDetails: [:],
                positiveContributors: [],
                negativeContributors: [],
                criticalOverrides: [],
                manualReviewReason: nil,
                scoreVersion: "v1",
                lastCalculatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 2, hour: 7, minute: 0, second: 0),
                verificationCompletenessPercentage: 68,
                weekChange: 4
            ),
            metadata: PassportOverview.Metadata(
                ownerUserId: "user_123",
                profileSlug: "aarav-mehta",
                isEmailVerified: true,
                isOnboardingComplete: true,
                createdAt: makeUTCTimestamp(year: 2026, month: 7, day: 30, hour: 8, minute: 0, second: 0)!,
                updatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 2, hour: 7, minute: 0, second: 0)!,
                employmentOnboardingCompletedAt: makeUTCTimestamp(year: 2026, month: 8, day: 1, hour: 10, minute: 20, second: 0)
            ),
            sharingSummary: PassportOverview.SharingSummary(
                totalLinks: 0,
                activeLinks: 0,
                revokedLinks: 0,
                expiredLinks: 0,
                totalViews: 0,
                uniqueViews: 0,
                latestShareCreatedAt: nil,
                lastViewedAt: nil
            ),
            verificationSummary: PassportOverview.VerificationSummary(
                overall: .init(total: 2, statuses: ["verified": 2]),
                employments: .init(total: 1, statuses: ["verified": 1]),
                educations: .init(total: 1, statuses: ["verified": 1]),
                certifications: .init(total: 0, statuses: [:]),
                skills: .init(total: 4, statuses: ["verified": 4]),
                projects: .init(total: 0, statuses: [:])
            ),
            vault: PassportOverview.Vault(
                employments: [
                    PassportEmploymentRecordDomain(
                        id: "employment_1",
                        company: "Northline Career Services",
                        role: "Trust Operations Associate",
                        startDate: makeUTCDate(year: 2024, month: 1, day: 1),
                        endDate: nil,
                        verificationStatus: .verified,
                        verificationMethod: "document_review",
                        documents: [
                            PassportDocumentRecordDomain(
                                id: "document_1",
                                documentType: "employment_letter",
                                originalFilename: "employment-letter.pdf",
                                byteSize: 152000,
                                verificationStatus: .verified
                            )
                        ]
                    )
                ],
                educations: [
                    PassportEducationRecordDomain(
                        id: "education_1",
                        institution: "Christ University",
                        degree: "BBA",
                        fieldOfStudy: "Human Resources & Operations",
                        educationLevel: "bachelors",
                        grade: nil,
                        startDate: makeUTCDate(year: 2016, month: 6, day: 1),
                        endDate: makeUTCDate(year: 2019, month: 5, day: 1),
                        startDatePrecision: "month",
                        endDatePrecision: "month",
                        isCurrentlyStudying: false,
                        verificationStatus: .verified
                    )
                ],
                certifications: [],
                projects: [],
                skills: [
                    PassportSkillRecordDomain(id: "skill_1", name: "Trust Operations", verificationStatus: .verified)
                ],
                userDocuments: []
            )
        )
    }

    private func makeUTCDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date
    }

    private func makeUTCTimestamp(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int
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

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
