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

    func test_careerCollectionEnvelopeDecodesSparseLiveSkillAndStatusFallbacks() throws {
        let employmentData = Data(
            """
            {
              "items": [
                {
                  "id": "employment_sparse_1",
                  "employer_legal_name": "First Meridian",
                  "job_title": "Trust Operations Specialist",
                  "employment_type": "full_time",
                  "start_date": "2026-08-01",
                  "end_date": null,
                  "work_location_country": "India",
                  "work_location_region": "Karnataka"
                }
              ]
            }
            """.utf8
        )
        let educationData = Data(
            """
            {
              "items": [
                {
                  "id": "education_sparse_1",
                  "institution_name": "Delhi Institute of Technology",
                  "degree": "B.Tech",
                  "field_of_study": "Computer Science",
                  "education_level": "bachelors",
                  "start_date": "2017-06-01",
                  "end_date": "2021-05-01",
                  "is_currently_studying": false
                }
              ]
            }
            """.utf8
        )
        let skillsData = Data(
            """
            [
              {
                "name": "Trust Operations"
              }
            ]
            """.utf8
        )

        let employments = try APIJSONCoder.makeDecoder()
            .decode(CareerCollectionEnvelopeDTO<CareerEmploymentDTO>.self, from: employmentData)
        let educations = try APIJSONCoder.makeDecoder()
            .decode(CareerCollectionEnvelopeDTO<CareerEducationDTO>.self, from: educationData)
        let skills = try APIJSONCoder.makeDecoder()
            .decode([CareerSkillDTO].self, from: skillsData)

        XCTAssertEqual(employments.items.first?.verificationStatus, "draft")
        XCTAssertEqual(employments.items.first?.companyDisplayName, "First Meridian")
        XCTAssertEqual(educations.items.first?.verificationStatus, "draft")
        XCTAssertEqual(educations.items.first?.institutionName, "Delhi Institute of Technology")
        XCTAssertEqual(skills.first?.id, "Trust Operations")
        XCTAssertEqual(skills.first?.name, "Trust Operations")
        XCTAssertEqual(skills.first?.verificationStatus, "draft")
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

    func test_ownerPassportResponseDTODecodesFrozenBackendShapeWithLegitimateEmptySections() throws {
        let data = Data(
            """
            {
              "profile": {
                "id": "user_123",
                "email": "aarav@example.com",
                "full_name": "Aarav Mehta",
                "profile_slug": "aarav-mehta",
                "phone": "+919876543210",
                "current_role": "Trust Operations Lead",
                "location": "Bengaluru, India",
                "location_city": "Bengaluru",
                "location_country": "India",
                "headline": "Trust Operations Lead",
                "avatar_url": "https://cdn.example.com/avatar.png",
                "role": "user",
                "is_active": true,
                "phone_verified_at": "2026-08-01T10:15:30Z",
                "email_verified_at": "2026-08-01T10:14:10Z",
                "employment_onboarding_completed_at": "2026-08-01T10:20:00Z",
                "languages": [],
                "professional_links": [],
                "profile_completion_percentage": 100,
                "created_at": "2026-07-30T08:00:00Z"
              },
              "trust_score": {
                "overall": 81,
                "breakdown": {
                  "identity": 1.0,
                  "employment": 0.75,
                  "education": 0.5
                },
                "domain_details": {
                  "employment": {
                    "score": 61.0,
                    "verification_points": 70.0,
                    "fraud_deduction": 9.0,
                    "weight": 0.35,
                    "positive_contributors": [],
                    "negative_contributors": []
                  }
                },
                "status": "calculated",
                "positive_contributors": [],
                "negative_contributors": [],
                "critical_overrides": [],
                "manual_review_reason": null,
                "score_version": "v1",
                "last_calculated_at": "2026-08-02T07:00:00Z",
                "verification_completeness_percentage": 68,
                "week_change": 4
              },
              "vault": {
                "employments": [
                  {
                    "id": "employment_1",
                    "employer_legal_name": "Northline Career Services",
                    "job_title": "Trust Operations Associate",
                    "start_date": "2024-01-01",
                    "end_date": null,
                    "verification_status": "verified",
                    "verification_method": "document_review",
                    "documents": [
                      {
                        "id": "document_1",
                        "document_type": "employment_letter",
                        "original_filename": "employment-letter.pdf",
                        "byte_size": 152000,
                        "verification_status": "verified"
                      }
                    ]
                  }
                ],
                "educations": [
                  {
                    "id": "education_1",
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
                    "verification_status": "verified"
                  }
                ],
                "internships": [],
                "freelance": [],
                "gig_platforms": [],
                "portfolio": [],
                "certifications": [],
                "skills": [
                  {
                    "name": "Trust Operations",
                    "verification_status": "verified"
                  }
                ],
                "projects": [],
                "user_documents": []
              },
              "passport_metadata": {
                "owner_user_id": "user_123",
                "profile_slug": "aarav-mehta",
                "is_email_verified": true,
                "is_onboarding_complete": true,
                "created_at": "2026-07-30T08:00:00Z",
                "updated_at": "2026-08-02T07:00:00Z",
                "employment_onboarding_completed_at": "2026-08-01T10:20:00Z"
              },
              "sharing_summary": {
                "total_links": 0,
                "active_links": 0,
                "revoked_links": 0,
                "expired_links": 0,
                "total_views": 0,
                "unique_views": 0,
                "latest_share_created_at": null,
                "last_viewed_at": null
              },
              "verification_summary": {
                "overall": { "total": 2, "statuses": { "verified": 2 } },
                "employments": { "total": 1, "statuses": { "verified": 1 } },
                "educations": { "total": 1, "statuses": { "verified": 1 } },
                "internships": { "total": 0, "statuses": {} },
                "freelance": { "total": 0, "statuses": {} },
                "gig_platforms": { "total": 0, "statuses": {} },
                "portfolio": { "total": 0, "statuses": {} },
                "certifications": { "total": 0, "statuses": {} },
                "skills": { "total": 1, "statuses": { "verified": 1 } },
                "projects": { "total": 0, "statuses": {} },
                "user_documents": { "total": 0, "statuses": {} }
              }
            }
            """.utf8
        )

        let response = try APIJSONCoder.makeDecoder().decode(OwnerPassportResponseDTO.self, from: data)

        XCTAssertEqual(response.profile.email, "aarav@example.com")
        XCTAssertEqual(response.trustScore.overall, 81)
        XCTAssertEqual(response.trustScore.status, .calculated)
        XCTAssertEqual(response.vault.employments.first?.employerLegalName, "Northline Career Services")
        XCTAssertEqual(response.vault.educations.first?.startDatePrecision, "month")
        XCTAssertEqual(response.vault.certifications, [])
        XCTAssertEqual(response.vault.projects, [])
        XCTAssertEqual(response.vault.skills.first?.name, "Trust Operations")
        XCTAssertTrue(response.passportMetadata.isOnboardingComplete)
        XCTAssertEqual(response.sharingSummary.totalLinks, 0)
        XCTAssertEqual(response.verificationSummary.certifications.total, 0)
        XCTAssertEqual(response.verificationSummary.projects.total, 0)
    }

    func test_ownerPassportResponseDTODecodesSparseLiveShapedPayload() throws {
        let data = Data(
            """
            {
              "profile": {
                "id": "user_sparse_123",
                "email": "candidate@example.com",
                "full_name": "Candidate Example",
                "profile_slug": "candidate-example",
                "phone": "+919876543210",
                "current_role": null,
                "industry": null,
                "years_of_experience": null,
                "location": "Mumbai, Maharashtra, India",
                "location_city": null,
                "location_region": null,
                "location_country": null,
                "headline": "Corporate development professional",
                "bio": null,
                "date_of_birth": null,
                "avatar_url": null,
                "role": "user",
                "is_active": true,
                "phone_verified_at": "2026-08-01T10:15:30Z",
                "email_verified_at": "2026-08-01T10:14:10Z",
                "employment_onboarding_completed_at": "2026-08-01T10:20:00Z",
                "languages": [],
                "professional_links": [],
                "profile_completion_percentage": 100,
                "created_at": "2026-07-30T08:00:00Z"
              },
              "trust_score": {
                "status": "incomplete_verification",
                "positive_contributors": [],
                "negative_contributors": [],
                "critical_overrides": [],
                "manual_review_reason": null,
                "score_version": "v1",
                "last_calculated_at": null,
                "verification_completeness_percentage": 30,
                "week_change": 0
              },
              "vault": {
                "employments": [
                  {
                    "id": "employment_sparse_1",
                    "employer_legal_name": "Example Capital",
                    "job_title": "Analyst",
                    "start_date": null,
                    "end_date": null,
                    "verification_status": "pending_verification",
                    "verification_method": "document_review",
                    "documents": []
                  }
                ],
                "educations": [
                  {
                    "id": "education_sparse_1",
                    "institution_name": "Example University",
                    "degree": "BBA",
                    "field_of_study": null,
                    "education_level": null,
                    "grade": null,
                    "start_date": null,
                    "start_date_precision": null,
                    "end_date": null,
                    "end_date_precision": null,
                    "is_currently_studying": false,
                    "verification_status": "verified"
                  }
                ],
                "internships": [],
                "freelance": [],
                "gig_platforms": [],
                "portfolio": [],
                "certifications": [],
                "skills": [
                  {
                    "name": "Financial Analysis",
                    "verification_status": "verified"
                  }
                ],
                "projects": [],
                "user_documents": []
              },
              "passport_metadata": {
                "owner_user_id": "user_sparse_123",
                "profile_slug": "candidate-example",
                "is_email_verified": true,
                "is_onboarding_complete": true,
                "created_at": "2026-07-30T08:00:00Z",
                "updated_at": "2026-08-02T07:00:00Z",
                "employment_onboarding_completed_at": "2026-08-01T10:20:00Z"
              },
              "sharing_summary": {
                "total_links": 0,
                "active_links": 0,
                "revoked_links": 0,
                "expired_links": 0,
                "total_views": 0,
                "unique_views": 0,
                "latest_share_created_at": null,
                "last_viewed_at": null
              },
              "verification_summary": {
                "overall": { "total": 2, "statuses": { "verified": 1, "pending_verification": 1 } },
                "employments": { "total": 1, "statuses": { "pending_verification": 1 } },
                "educations": { "total": 1, "statuses": { "verified": 1 } },
                "internships": { "total": 0, "statuses": {} },
                "freelance": { "total": 0, "statuses": {} },
                "gig_platforms": { "total": 0, "statuses": {} },
                "portfolio": { "total": 0, "statuses": {} },
                "certifications": { "total": 0, "statuses": {} },
                "skills": { "total": 1, "statuses": { "verified": 1 } },
                "projects": { "total": 0, "statuses": {} },
                "user_documents": { "total": 0, "statuses": {} }
              }
            }
            """.utf8
        )

        let response = try APIJSONCoder.makeDecoder().decode(OwnerPassportResponseDTO.self, from: data)

        XCTAssertEqual(response.profile.currentRole, nil)
        XCTAssertEqual(response.profile.avatarURL, nil)
        XCTAssertNil(response.trustScore.overall)
        XCTAssertEqual(response.trustScore.status, .incompleteVerification)
        XCTAssertEqual(response.vault.employments.first?.startDate, nil)
        XCTAssertEqual(response.vault.educations.first?.fieldOfStudy, nil)
        XCTAssertEqual(response.vault.certifications, [])
        XCTAssertEqual(response.vault.projects, [])
        XCTAssertEqual(response.vault.userDocuments, [])
        XCTAssertEqual(response.passportMetadata.ownerUserId, "user_sparse_123")
        XCTAssertNil(response.sharingSummary.latestShareCreatedAt)
        XCTAssertNil(response.sharingSummary.lastViewedAt)
        XCTAssertEqual(response.verificationSummary.projects.total, 0)
    }

    func test_verificationRequestDTODecodesCandidateListShape() throws {
        let data = Data(
            """
            {
              "public_id": "request_1",
              "employment_id": "employment_1",
              "subject_name": "Aman Jha",
              "subject_email": "aman@example.com",
              "target_organization_name": "BrightPath Technologies",
              "target_organization_email": "hr@brightpath.example.com",
              "request_type": "employment",
              "status": "pending_subject_acceptance",
              "priority": "high",
              "due_date": "2026-08-12",
              "created_at": "2026-08-08T08:00:00Z",
              "updated_at": "2026-08-08T09:00:00Z",
              "candidate_response": null,
              "candidate_response_submitted_at": null,
              "accepted_at": null,
              "consented_fields": ["employment_dates"],
              "consented_evidence_scope": ["employment_letter"],
              "organization_summary": {
                "public_id": "org_1",
                "name": "BrightPath Technologies"
              },
              "verification_target": {
                "organization_name": "BrightPath Technologies",
                "organization_email": "hr@brightpath.example.com"
              },
              "employment_claim": {
                "employer_name": "BrightPath Technologies",
                "role": "Product Operations Manager",
                "start_date": "2025-01-01",
                "end_date": null,
                "employment_type": "full_time",
                "work_location_country": "India",
                "work_location_region": "Karnataka"
              },
              "evidence_summary": {
                "total_items": 1,
                "document_items": 1,
                "field_keys": ["employment_letter"]
              }
            }
            """.utf8
        )

        let request = try APIJSONCoder.makeDecoder().decode(VerificationRequestResponseDTO.self, from: data)

        XCTAssertEqual(request.publicID, "request_1")
        XCTAssertEqual(request.requestType, "employment")
        XCTAssertEqual(request.status, "pending_subject_acceptance")
        XCTAssertEqual(request.priority, "high")
        XCTAssertEqual(request.organizationSummary?.name, "BrightPath Technologies")
        XCTAssertEqual(request.employmentClaim?.role, "Product Operations Manager")
        XCTAssertEqual(request.evidenceSummary.fieldKeys, ["employment_letter"])
    }

    func test_verificationRequestTimelineDTODecodesFrozenBackendShape() throws {
        let data = Data(
            """
            {
              "verification_request_public_id": "request_1",
              "items": [
                {
                  "public_id": "timeline_1",
                  "event_type": "verification_requested",
                  "event_source": "organization",
                  "previous_status": null,
                  "new_status": "pending_subject_acceptance",
                  "metadata": {},
                  "created_at": "2026-08-08T08:00:00Z"
                }
              ],
              "total": 1,
              "page": 1,
              "page_size": 50,
              "total_pages": 1,
              "offset": 0,
              "limit": 50
            }
            """.utf8
        )

        let timeline = try APIJSONCoder.makeDecoder().decode(VerificationRequestTimelineResponseDTO.self, from: data)

        XCTAssertEqual(timeline.verificationRequestPublicID, "request_1")
        XCTAssertEqual(timeline.items.count, 1)
        XCTAssertEqual(timeline.items.first?.eventType, "verification_requested")
        XCTAssertEqual(timeline.items.first?.newStatus, "pending_subject_acceptance")
        XCTAssertEqual(timeline.total, 1)
    }

    func test_verificationRequestResponseDTODecodesSparseLegacyRequestWithoutRoutingID() throws {
        let data = Data(
            """
            {
              "public_id": "   ",
              "trust_invitation_public_id": " ",
              "subject_name": "Legacy Candidate",
              "request_type": "education",
              "status": "pending_subject_submission",
              "priority": "normal",
              "created_at": "2026-08-08T08:00:00Z",
              "updated_at": "2026-08-08T09:00:00Z",
              "consented_fields": [],
              "consented_evidence_scope": [],
              "evidence_summary": {
                "total_items": 0,
                "document_items": 0,
                "field_keys": []
              }
            }
            """.utf8
        )

        let request = try APIJSONCoder.makeDecoder().decode(VerificationRequestResponseDTO.self, from: data)

        XCTAssertNil(request.publicID)
        XCTAssertNil(request.trustInvitationPublicID)
        XCTAssertNil(request.routingID)
        XCTAssertEqual(request.requestType, "education")
        XCTAssertEqual(request.status, "pending_subject_submission")
    }

    func test_verificationRequestResponseDTODecodesWhenPublicIDIsMissing() throws {
        let data = Data(
            """
            {
              "subject_name": "Legacy Candidate",
              "request_type": "education",
              "status": "pending_subject_submission",
              "priority": "normal",
              "created_at": "2026-08-08T08:00:00Z",
              "updated_at": "2026-08-08T09:00:00Z",
              "consented_fields": [],
              "consented_evidence_scope": [],
              "evidence_summary": {
                "total_items": 0,
                "document_items": 0,
                "field_keys": []
              }
            }
            """.utf8
        )

        let request = try APIJSONCoder.makeDecoder().decode(VerificationRequestResponseDTO.self, from: data)

        XCTAssertNil(request.publicID)
        XCTAssertNil(request.trustInvitationPublicID)
        XCTAssertNil(request.routingID)
        XCTAssertNil(request.organizationSummary)
        XCTAssertNil(request.verificationTarget)
    }

    func test_verificationRequestResponseDTODecodesWhenPublicIDIsNull() throws {
        let data = Data(
            """
            {
              "public_id": null,
              "trust_invitation_public_id": null,
              "subject_name": "Legacy Candidate",
              "request_type": "education",
              "status": "pending_subject_submission",
              "priority": "normal",
              "created_at": "2026-08-08T08:00:00Z",
              "updated_at": "2026-08-08T09:00:00Z",
              "consented_fields": [],
              "consented_evidence_scope": [],
              "evidence_summary": {
                "total_items": 0,
                "document_items": 0,
                "field_keys": []
              }
            }
            """.utf8
        )

        let request = try APIJSONCoder.makeDecoder().decode(VerificationRequestResponseDTO.self, from: data)

        XCTAssertNil(request.publicID)
        XCTAssertNil(request.trustInvitationPublicID)
        XCTAssertNil(request.routingID)
    }

    func test_verificationRequestResponseDTOFallsBackToTrustInvitationPublicID() throws {
        let data = Data(
            """
            {
              "public_id": "   ",
              "trust_invitation_public_id": "invite_123",
              "subject_name": "Legacy Candidate",
              "request_type": "education",
              "status": "pending_subject_submission",
              "priority": "normal",
              "created_at": "2026-08-08T08:00:00Z",
              "updated_at": "2026-08-08T09:00:00Z",
              "consented_fields": [],
              "consented_evidence_scope": [],
              "evidence_summary": {
                "total_items": 0,
                "document_items": 0,
                "field_keys": []
              }
            }
            """.utf8
        )

        let request = try APIJSONCoder.makeDecoder().decode(VerificationRequestResponseDTO.self, from: data)

        XCTAssertNil(request.publicID)
        XCTAssertEqual(request.trustInvitationPublicID, "invite_123")
        XCTAssertEqual(request.routingID, "invite_123")
        XCTAssertEqual(request.requestType, "education")
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
