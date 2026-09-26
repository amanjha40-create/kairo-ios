import Foundation
import XCTest
@testable import Kairo

@MainActor
final class PortfolioWave4Tests: XCTestCase {
    func test_portfolioRecordTreatsOnlyCompletedUploadAsVisibleAttachment() throws {
        let decoder = APIJSONCoder.makeDecoder()
        let pending = try decoder.decode(PortfolioRecord.self, from: Data(
            #"{"id":"portfolio","title":"Case study","original_filename":"pending.pdf","content_type":"application/pdf","byte_size":100,"verification_status":"draft"}"#.utf8
        ))
        let completed = try decoder.decode(PortfolioRecord.self, from: Data(
            #"{"id":"portfolio","title":"Case study","original_filename":"complete.pdf","content_type":"application/pdf","byte_size":100,"upload_completed_at":"2026-09-01T08:00:00Z","verification_status":"draft"}"#.utf8
        ))

        XCTAssertNil(pending.document)
        XCTAssertEqual(completed.document?.originalFilename, "complete.pdf")
        XCTAssertTrue(pending.tags.isEmpty)
    }

    func test_portfolioMappingPreservesFirstClassFieldsAndKeepsProjectsSeparate() {
        let overview = CareerOverview(
            user: user,
            employments: [],
            educations: [],
            certifications: [],
            projects: [],
            skills: [],
            portfolio: [
                PortfolioRecord(
                    id: "portfolio_1",
                    title: "Inclusive finance case study",
                    description: "Research and design",
                    url: URL(string: "https://example.com/work"),
                    tags: ["Accessibility", "iOS"],
                    originalFilename: "case-study.pdf",
                    contentType: "application/pdf",
                    byteSize: 2_048,
                    uploadCompletedAt: Date(),
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ]
        )

        guard case .populated(let content) = CareerOverviewMapper.map(overview).phase else {
            return XCTFail("Expected populated Portfolio state")
        }
        XCTAssertTrue(content.projects.isEmpty)
        XCTAssertEqual(content.portfolio.count, 1)
        XCTAssertEqual(content.portfolio.first?.tags, ["Accessibility", "iOS"])
        XCTAssertEqual(content.portfolio.first?.originalFilename, "case-study.pdf")
    }

    func test_portfolioListStatesRemainExplicit() {
        guard case .populated(let populated) = CareerOverviewState.populatedFixture().phase else {
            return XCTFail("Expected populated fixture")
        }
        guard case .empty(let empty) = CareerOverviewState.emptyFixture().phase else {
            return XCTFail("Expected empty fixture")
        }
        guard case .loading = CareerOverviewState.loadingFixture().phase else {
            return XCTFail("Expected loading fixture")
        }
        guard case .error(let error) = CareerOverviewState.errorFixture().phase else {
            return XCTFail("Expected error fixture")
        }

        XCTAssertEqual(populated.portfolio.count, 1)
        XCTAssertTrue(empty.portfolio.isEmpty)
        XCTAssertFalse(error.message.isEmpty)
    }

    func test_portfolioDetailOffersEditLinkAndAttachmentWithoutExposingPrivateIdentifiers() {
        let item = CareerPortfolioItem(
            routeID: "internal-portfolio-id",
            title: "Case study",
            description: "A safe public summary",
            verificationStatus: .notVerified,
            hasDocument: true,
            url: URL(string: "https://example.com/work"),
            tags: ["Research"],
            originalFilename: "case-study.pdf",
            byteSize: 1_024
        )

        let detail = CareerRecordDetailPresentation.portfolio(item, edit: {})

        XCTAssertNotNil(detail.edit)
        XCTAssertEqual(detail.documents, .portfolio(id: "internal-portfolio-id", title: "Case study"))
        XCTAssertEqual(detail.links.first?.url.scheme, "https")
        let visibleValues = (detail.metadata + detail.supportingMetadata).map(\.value).joined(separator: " ")
        XCTAssertFalse(visibleValues.contains("internal-portfolio-id"))
        XCTAssertFalse(visibleValues.contains("s3"))
        XCTAssertFalse(visibleValues.contains("token"))
    }

    func test_portfolioLinkAllowsWebSchemesAndRejectsUnsafeSchemes() {
        XCTAssertNotNil(CareerRecordLink(title: "Work", url: URL(string: "https://example.com/work")))
        XCTAssertNotNil(CareerRecordLink(title: "Work", url: URL(string: "http://example.com/work")))
        for raw in ["javascript:alert(1)", "data:text/plain,private", "file:///private/work.pdf", "https://user:secret@example.com/work"] {
            XCTAssertNil(CareerRecordLink(title: "Work", url: URL(string: raw)))
        }
    }

    func test_portfolioBackendFailureMapsToCanonicalCopyWithoutRawPayload() {
        let apiError = APIError(
            statusCode: 500,
            code: .internalError,
            message: "s3://private-bucket/raw-key Bearer private-token",
            fieldErrors: [:],
            globalErrors: [],
            validationDetails: []
        )

        let error = CareerMutationErrorMapper.map(NetworkError.api(apiError), fallbackTitle: "Portfolio unavailable")

        XCTAssertEqual(error.title, "Portfolio unavailable")
        XCTAssertEqual(error.message, "KairoID couldn't complete that Career change. Please try again.")
        XCTAssertFalse(error.message.contains("s3://"))
        XCTAssertFalse(error.message.contains("Bearer"))
    }

    private var user: AppUser {
        AppUser(
            id: "user",
            email: "candidate@example.com",
            fullName: "Candidate",
            profileSlug: "candidate",
            phone: nil,
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
            phoneVerifiedAt: nil,
            emailVerifiedAt: nil,
            employmentOnboardingCompletedAt: nil,
            languages: [],
            professionalLinks: [],
            profileCompletionPercentage: 0,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
