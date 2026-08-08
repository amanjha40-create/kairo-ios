import Foundation
import XCTest
@testable import Kairo

final class APIDecodingTests: XCTestCase {
    func test_apiErrorDecodesValidationDetailsArrayIntoFieldErrors() throws {
        let data = Data(
            """
            {
              "error": {
                "code": "validation_error",
                "message": "Request validation failed",
                "details": [
                  {
                    "location": ["body", "email"],
                    "message": "value is not a valid email address",
                    "error_type": "value_error"
                  },
                  {
                    "location": ["body", "phone"],
                    "message": "Field required",
                    "error_type": "missing"
                  }
                ]
              }
            }
            """.utf8
        )

        let error = try XCTUnwrap(APIError.decode(from: data, statusCode: 422))

        XCTAssertEqual(error.statusCode, 422)
        XCTAssertEqual(error.code, .validationError)
        XCTAssertEqual(error.message, "Request validation failed")
        XCTAssertEqual(error.fieldErrors["email"], ["value is not a valid email address"])
        XCTAssertEqual(error.fieldErrors["phone"], ["Field required"])
        XCTAssertEqual(error.globalErrors, [])
        XCTAssertEqual(error.validationDetails.count, 2)
    }

    func test_apiErrorCollectsMultipleErrorsForTheSameField() throws {
        let data = Data(
            """
            {
              "error": {
                "code": "validation_error",
                "message": "Request validation failed",
                "details": [
                  {
                    "location": ["body", "password"],
                    "message": "String should have at least 12 characters",
                    "error_type": "string_too_short"
                  },
                  {
                    "location": ["body", "password"],
                    "message": "String should have at most 128 characters",
                    "error_type": "string_too_long"
                  }
                ]
              }
            }
            """.utf8
        )

        let error = try XCTUnwrap(APIError.decode(from: data, statusCode: 422))

        XCTAssertEqual(
            error.fieldErrors["password"],
            [
                "String should have at least 12 characters",
                "String should have at most 128 characters"
            ]
        )
    }

    func test_apiErrorRetainsGlobalValidationErrors() throws {
        let data = Data(
            """
            {
              "error": {
                "code": "validation_error",
                "message": "Request validation failed",
                "details": [
                  {
                    "location": ["body"],
                    "message": "Request body is invalid",
                    "error_type": "value_error"
                  }
                ]
              }
            }
            """.utf8
        )

        let error = try XCTUnwrap(APIError.decode(from: data, statusCode: 422))

        XCTAssertEqual(error.fieldErrors, [:])
        XCTAssertEqual(error.globalErrors, ["Request body is invalid"])
    }

    func test_apiErrorFallsBackToStatusCodeMappingWhenBodyIsEmpty() {
        let error = APIError.decode(from: Data(), statusCode: 503)

        XCTAssertEqual(error?.statusCode, 503)
        XCTAssertEqual(error?.code, .serviceUnavailable)
        XCTAssertEqual(error?.message, "Kairo is temporarily unavailable. Please try again.")
        XCTAssertEqual(error?.fieldErrors, [:])
    }

    func test_tokenResponseDTODecodesStagingShape() throws {
        let data = Data(
            """
            {
              "access_token": "access-token",
              "refresh_token": "refresh-token",
              "token_type": "bearer",
              "expires_in": 3600
            }
            """.utf8
        )

        let response = try APIJSONCoder.makeDecoder().decode(TokenResponseDTO.self, from: data)

        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertEqual(response.refreshToken, "refresh-token")
        XCTAssertEqual(response.tokenType, "bearer")
        XCTAssertEqual(response.expiresIn, 3600)
    }

    func test_signupStartResponseDefaultsVerificationFlagsWhenOmitted() throws {
        let data = Data(
            """
            {
              "signup_session_id": "signup-session-123",
              "email_masked": "am**@example.com",
              "phone_masked": "+91******3210",
              "email_resend_after_seconds": 30,
              "phone_resend_after_seconds": 30,
              "expires_in_seconds": 900
            }
            """.utf8
        )

        let response = try APIJSONCoder.makeDecoder().decode(SignupStartResponseDTO.self, from: data)

        XCTAssertFalse(response.emailVerified)
        XCTAssertFalse(response.phoneVerified)
        XCTAssertNil(response.message)
    }

    func test_userPublicDTODecodesRealisticStagingFixture() throws {
        let data = Data(
            """
            {
              "id": "6f4f1f5a-a89d-4b4b-9d67-3f0e8a0d1492",
              "email": "aarav@example.com",
              "full_name": "Aarav Mehta",
              "profile_slug": "aarav-mehta",
              "phone": "+919876543210",
              "current_role": "People Operations Lead",
              "industry": "Technology",
              "years_of_experience": 6,
              "location": "Bengaluru, India",
              "location_city": "Bengaluru",
              "location_region": "Karnataka",
              "location_country": "India",
              "headline": "People Operations Lead",
              "bio": "Building verified professional trust.",
              "date_of_birth": "1994-09-14",
              "avatar_url": "https://cdn.example.com/avatar.png",
              "role": "user",
              "is_active": true,
              "phone_verified_at": "2026-07-31T10:15:30Z",
              "email_verified_at": "2026-07-31T10:14:10Z",
              "employment_onboarding_completed_at": null,
              "languages": [
                {
                  "id": "cc2cf4b4-5d75-4a4b-a3b6-89b25abef001",
                  "language": "English",
                  "proficiency": "native"
                }
              ],
              "professional_links": [
                {
                  "id": "b4033575-d634-4e3d-92b6-d8e8ebf21002",
                  "link_type": "linkedin",
                  "label": "LinkedIn",
                  "url": "https://linkedin.com/in/aarav"
                }
              ],
              "profile_completion_percentage": 75,
              "created_at": "2026-07-30T08:00:00Z"
            }
            """.utf8
        )

        let user = try APIJSONCoder.makeDecoder().decode(UserPublicDTO.self, from: data)

        XCTAssertEqual(user.id, "6f4f1f5a-a89d-4b4b-9d67-3f0e8a0d1492")
        XCTAssertEqual(user.fullName, "Aarav Mehta")
        XCTAssertEqual(user.phone, "+919876543210")
        XCTAssertEqual(user.role, "user")
        XCTAssertEqual(user.languages.first?.language, "English")
        XCTAssertEqual(user.professionalLinks.first?.linkType, "linkedin")
        XCTAssertEqual(user.profileCompletionPercentage, 75)
        XCTAssertEqual(user.dateOfBirth, makeUTCDate(year: 1994, month: 9, day: 14))
        XCTAssertEqual(user.createdAt, makeUTCTimestamp(year: 2026, month: 7, day: 30, hour: 8, minute: 0, second: 0))
    }

    func test_userPublicDTODefaultsOptionalCollectionsAndCompletionPercentage() throws {
        let data = Data(
            """
            {
              "id": "6f4f1f5a-a89d-4b4b-9d67-3f0e8a0d1492",
              "email": "aarav@example.com",
              "full_name": null,
              "role": "user",
              "is_active": true,
              "created_at": "2026-07-30T08:00:00Z"
            }
            """.utf8
        )

        let user = try APIJSONCoder.makeDecoder().decode(UserPublicDTO.self, from: data)

        XCTAssertEqual(user.languages, [])
        XCTAssertEqual(user.professionalLinks, [])
        XCTAssertEqual(user.profileCompletionPercentage, 0)
    }

    func test_onboardingStatusDTODecodesFrozenLiveShape() throws {
        let data = Data(
            """
            {
              "current_step": "complete_profile",
              "email_verified": true,
              "phone_verified": true,
              "passport_ready": false,
              "completed_steps": ["verify_email", "verify_phone"],
              "missing_requirements": ["headline"],
              "next_recommended_step": "complete_profile",
              "completion_percentage": 75,
              "is_onboarding_complete": false
            }
            """.utf8
        )

        let status = try APIJSONCoder.makeDecoder().decode(OnboardingStatusResponseDTO.self, from: data)

        XCTAssertEqual(status.currentStep, "complete_profile")
        XCTAssertEqual(status.resolvedCurrentStep, .completeProfile)
        XCTAssertEqual(status.completedSteps, ["verify_email", "verify_phone"])
        XCTAssertEqual(status.missingRequirements, ["headline"])
        XCTAssertEqual(status.completionPercentage, 75)
        XCTAssertFalse(status.isOnboardingComplete)
    }

    func test_dashboardResponseDTODecodesFrozenBackendShapeAndDefaultsOptionalCollections() throws {
        let data = Data(
            """
            {
              "profile_completion": {
                "current_step": "complete_profile",
                "email_verified": true,
                "phone_verified": true,
                "passport_ready": false,
                "completed_steps": ["verify_email", "verify_phone"],
                "missing_requirements": ["employment", "education"],
                "next_recommended_step": "employment",
                "completion_percentage": 70,
                "is_onboarding_complete": false
              },
              "trust_score": {
                "overall": 78,
                "status": "calculated",
                "positive_contributors": [
                  {
                    "code": "verified_employment",
                    "label": "Verified employment",
                    "points": 22.5,
                    "detail": "Your current role has been verified."
                  }
                ],
                "negative_contributors": [],
                "critical_overrides": [],
                "verification_completeness_percentage": 72,
                "week_change": 4
              },
              "verification_summary": {
                "overall": {
                  "total": 4,
                  "statuses": {
                    "verified": 2,
                    "pending": 1,
                    "not_verified": 1
                  }
                },
                "employments": {
                  "total": 2,
                  "statuses": {
                    "verified": 1,
                    "pending": 1
                  }
                },
                "educations": {
                  "total": 1,
                  "statuses": {
                    "verified": 1
                  }
                }
              },
              "vault_summary": {
                "total_items": 6,
                "employments": 2,
                "educations": 1,
                "internships": 0,
                "freelance": 0,
                "gig_platforms": 0,
                "portfolio": 0,
                "certifications": 1,
                "user_documents": 2
              },
              "active_passport_shares": {
                "count": 1,
                "items": [
                  {
                    "share_id": "share_123",
                    "label": "Northstar Labs",
                    "state": "active",
                    "expires_at": "2026-08-10T10:00:00Z",
                    "last_viewed_at": "2026-08-01T11:45:00Z",
                    "created_at": "2026-07-30T08:00:00Z"
                  }
                ]
              },
              "recent_share_analytics": [
                {
                  "share_id": "share_123",
                  "label": "Northstar Labs",
                  "state": "active",
                  "total_views": 3,
                  "unique_views": 2,
                  "last_viewed_at": "2026-08-01T11:45:00Z"
                }
              ],
              "recent_activity": [
                {
                  "occurred_at": "2026-08-01T12:15:00Z",
                  "category": "verification",
                  "action": "awaiting_approval",
                  "title": "Employment verification",
                  "detail": "Northstar Labs",
                  "subject_id": "employment_123"
                }
              ]
            }
            """.utf8
        )

        let response = try APIJSONCoder.makeDecoder().decode(DashboardResponseDTO.self, from: data)

        XCTAssertEqual(response.profileCompletion.currentStep, "complete_profile")
        XCTAssertEqual(response.profileCompletionPercentage, 70)
        XCTAssertEqual(response.trustScore.overall, 78)
        XCTAssertEqual(response.trustScore.status, .calculated)
        XCTAssertEqual(response.trustScore.positiveContributors.first?.code, "verified_employment")
        XCTAssertEqual(response.verificationSummary.overall.total, 4)
        XCTAssertEqual(response.verificationSummary.certifications, .empty)
        XCTAssertEqual(response.vaultSummary.skills, 0)
        XCTAssertEqual(response.vaultSummary.projects, 0)
        XCTAssertEqual(response.activePassportShares.count, 1)
        XCTAssertEqual(response.activePassportShares.items.first?.shareId, "share_123")
        XCTAssertEqual(response.recentShareAnalytics.first?.totalViews, 3)
        XCTAssertEqual(response.recentActivity.first?.category, .verification)
    }

    func test_careerEmploymentDTODecodesFrozenBackendShape() throws {
        let data = Data(
            """
            {
              "items": [
                {
                  "id": "employment_1",
                  "subject_full_name": "Aarav Mehta",
                  "subject_email": "aarav@example.com",
                  "employer_legal_name": "Northline Career Services",
                  "employer_trade_name": null,
                  "job_title": "Trust & Operations Associate",
                  "employment_type": "full_time",
                  "start_date": "2024-01-01",
                  "end_date": null,
                  "work_location_country": "India",
                  "work_location_region": "Karnataka",
                  "verification_method": "document",
                  "verification_status": "approved",
                  "submitted_at": "2026-07-31T09:00:00Z",
                  "reviewed_at": null,
                  "assigned_reviewer_user_id": null,
                  "assigned_at": null,
                  "created_at": "2026-07-31T08:00:00Z",
                  "updated_at": "2026-07-31T08:30:00Z"
                }
              ],
              "total": 1,
              "page": 1,
              "page_size": 20,
              "total_pages": 1,
              "offset": 0,
              "limit": 20
            }
            """.utf8
        )

        let page = try APIJSONCoder.makeDecoder().decode(
            CareerCollectionEnvelopeDTO<CareerEmploymentDTO>.self,
            from: data
        )
        let employment = try XCTUnwrap(page.items.first)

        XCTAssertEqual(employment.id, "employment_1")
        XCTAssertEqual(employment.employerLegalName, "Northline Career Services")
        XCTAssertNil(employment.employerTradeName)
        XCTAssertEqual(employment.companyDisplayName, "Northline Career Services")
        XCTAssertEqual(employment.jobTitle, "Trust & Operations Associate")
        XCTAssertEqual(employment.employmentType, "full_time")
        XCTAssertEqual(employment.startDate, makeUTCDate(year: 2024, month: 1, day: 1))
        XCTAssertNil(employment.endDate)
        XCTAssertTrue(employment.currentlyWorking)
        XCTAssertEqual(employment.verificationStatus, "approved")
    }

    func test_careerCollectionEnvelopeDecodesArrayAndEmptyPageShapes() throws {
        let skillsData = Data(
            """
            [
              {
                "id": "skill_1",
                "user_id": "user_123",
                "name": "Trust Operations",
                "verification_status": "verified"
              },
              {
                "id": "skill_2",
                "user_id": "user_123",
                "name": "Employment Verification",
                "verification_status": "pending_verification"
              }
            ]
            """.utf8
        )
        let data = Data(
            """
            {
              "items": [],
              "total": 0,
              "page": 1,
              "page_size": 20,
              "total_pages": 0,
              "offset": 0,
              "limit": 20
            }
            """.utf8
        )

        let skills = try APIJSONCoder.makeDecoder()
            .decode([CareerSkillDTO].self, from: skillsData)
        let emptyCertifications = try APIJSONCoder.makeDecoder()
            .decode(CareerCollectionEnvelopeDTO<CareerCertificationDTO>.self, from: data)

        XCTAssertEqual(skills.count, 2)
        XCTAssertEqual(skills.first?.id, "skill_1")
        XCTAssertEqual(skills.first?.name, "Trust Operations")
        XCTAssertEqual(skills.first?.verificationStatus, "verified")
        XCTAssertEqual(skills.last?.id, "skill_2")
        XCTAssertEqual(skills.last?.name, "Employment Verification")
        XCTAssertEqual(skills.last?.verificationStatus, "pending_verification")
        XCTAssertEqual(emptyCertifications.items, [])
    }

    func test_careerEducationDTODecodesFrozenBackendShape() throws {
        let data = Data(
            """
            {
              "items": [
                {
                  "id": "education_1",
                  "user_id": "user_123",
                  "institution_name": "Christ University",
                  "degree": "BBA",
                  "field_of_study": "Human Resources & Operations",
                  "education_level": "bachelors",
                  "grade": null,
                  "start_date": "2016-06-01",
                  "start_date_precision": "month",
                  "end_date": "2019-05-01",
                  "end_date_precision": "month",
                  "is_currently_studying": false,
                  "verification_status": "verified",
                  "submitted_at": null,
                  "reviewed_at": null,
                  "reviewed_by_user_id": null,
                  "reviewer_note": null,
                  "created_at": "2026-07-31T08:00:00Z",
                  "updated_at": "2026-07-31T08:30:00Z"
                }
              ],
              "total": 1,
              "page": 1,
              "page_size": 20,
              "total_pages": 1,
              "offset": 0,
              "limit": 20
            }
            """.utf8
        )

        let page = try APIJSONCoder.makeDecoder().decode(
            CareerCollectionEnvelopeDTO<CareerEducationDTO>.self,
            from: data
        )
        let education = try XCTUnwrap(page.items.first)

        XCTAssertEqual(education.id, "education_1")
        XCTAssertEqual(education.institutionName, "Christ University")
        XCTAssertEqual(education.degree, "BBA")
        XCTAssertEqual(education.fieldOfStudy, "Human Resources & Operations")
        XCTAssertEqual(education.educationLevel, "bachelors")
        XCTAssertEqual(education.startDate, makeUTCDate(year: 2016, month: 6, day: 1))
        XCTAssertEqual(education.startDatePrecision, "month")
        XCTAssertEqual(education.endDate, makeUTCDate(year: 2019, month: 5, day: 1))
        XCTAssertEqual(education.endDatePrecision, "month")
        XCTAssertFalse(education.isCurrentlyStudying)
        XCTAssertEqual(education.verificationStatus, "verified")
    }

    func test_emptyProjectsArrayDecodesSuccessfully() throws {
        let data = Data("[]".utf8)

        let projects = try APIJSONCoder.makeDecoder().decode([CareerProjectDTO].self, from: data)

        XCTAssertEqual(projects, [])
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
