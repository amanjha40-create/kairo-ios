import Foundation
import XCTest
@testable import Kairo

final class ResumeImportMapperTests: XCTestCase {
    func test_groupedItemsPreservesCandidateReviewOrderAndHidesNonMVPSegments() {
        let session = ResumeReviewSession(
            id: "review_123",
            resumeID: "resume_123",
            parsedResultID: "parsed_123",
            status: .reviewing,
            schemaVersion: "resume_review_v1",
            version: 3,
            items: [
                makeItem(id: "internship_1", claimType: "internship", title: "Hidden internship"),
                makeItem(id: "employment_1", claimType: "employment", title: "Northstar Labs"),
                makeItem(id: "profile_1", claimType: "profile", title: "Aman Jha"),
                makeItem(id: "education_1", claimType: "education", title: "Delhi Institute of Technology"),
                makeItem(id: "skill_1", claimType: "skill", title: "Trust Operations")
            ],
            createdAt: Date(timeIntervalSince1970: 1_722_499_200),
            updatedAt: Date(timeIntervalSince1970: 1_722_499_260)
        )

        let sections = ResumeImportMapper.groupedItems(from: session)

        XCTAssertEqual(sections.map(\.id), ["profile", "employment", "education", "skill"])
        XCTAssertEqual(sections.first?.title, "Basic details")
        XCTAssertEqual(sections[1].items.first?.id, "employment_1")
        XCTAssertFalse(sections.flatMap(\.items).contains { $0.id == "internship_1" })
    }

    func test_editedPayloadTrimsValuesAndNullsClearedFields() {
        let item = makeItem(
            id: "employment_1",
            claimType: "employment",
            title: "Northstar Labs",
            subtitle: "Operations Analyst"
        )

        let payload = ResumeImportMapper.editedPayload(
            for: item,
            using: [
                "company_name": "  Updated Labs  ",
                "role_title": "",
                "start_date": " 2022-01 "
            ]
        )

        XCTAssertEqual(payload["company_name"], .string("Updated Labs"))
        XCTAssertEqual(payload["role_title"], .null)
        XCTAssertEqual(payload["start_date"], .string("2022-01"))
    }

    func test_displayHelpersUseEditedPayloadBeforeFallbacks() {
        let item = ResumeReviewItem(
            id: "profile_1",
            claimType: "profile",
            sourceClaimID: "claim_1",
            originalPayload: [:],
            editedPayload: [
                "full_name": .string("Aman Jha"),
                "email": .string("aman@example.com"),
                "location": .string("Bengaluru, India"),
                "headline": .string("Trust Operations Lead")
            ],
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.98,
            version: 2
        )

        XCTAssertEqual(ResumeImportMapper.displayTitle(for: item), "Aman Jha")
        XCTAssertEqual(ResumeImportMapper.displaySubtitle(for: item), "Trust Operations Lead")
        XCTAssertEqual(
            ResumeImportMapper.detailLines(for: item),
            ["aman@example.com", "Bengaluru, India"]
        )
    }

    func test_liveProfilePayloadUsesProfessionalHeadlineAndNestedLocationDisplay() {
        let item = ResumeReviewItem(
            id: "profile_1",
            claimType: "profile",
            sourceClaimID: "claim_1",
            originalPayload: [:],
            editedPayload: [
                "full_name": .string("Arjun Mehra"),
                "professional_headline": .string("Product Operations Manager"),
                "location": .object([
                    "city": .string("Bengaluru"),
                    "country": .string("India"),
                    "display": .string("Bengaluru, Karnataka, India")
                ])
            ],
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.98,
            version: 2
        )

        XCTAssertEqual(ResumeImportMapper.displayTitle(for: item), "Arjun Mehra")
        XCTAssertEqual(ResumeImportMapper.displaySubtitle(for: item), "Product Operations Manager")
        XCTAssertEqual(
            ResumeImportMapper.detailLines(for: item),
            ["Bengaluru, Karnataka, India"]
        )
    }

    func test_profileHeadlineFallsBackToLegacyHeadlineWhenProfessionalHeadlineIsAbsent() {
        let item = ResumeReviewItem(
            id: "profile_legacy",
            claimType: "profile",
            sourceClaimID: "claim_legacy",
            originalPayload: [:],
            editedPayload: [
                "full_name": .string("Aman Jha"),
                "headline": .string("Trust Operations Lead")
            ],
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.9,
            version: 1
        )

        XCTAssertEqual(ResumeImportMapper.displaySubtitle(for: item), "Trust Operations Lead")
    }

    func test_profileLocationFallsBackToFlatFieldsWhenNestedDisplayIsAbsent() {
        let item = ResumeReviewItem(
            id: "profile_flat_location",
            claimType: "profile",
            sourceClaimID: "claim_flat_location",
            originalPayload: [:],
            editedPayload: [
                "full_name": .string("Aman Jha"),
                "current_city": .string("Bengaluru"),
                "current_country": .string("India")
            ],
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.9,
            version: 1
        )

        XCTAssertEqual(
            ResumeImportMapper.detailLines(for: item),
            ["Bengaluru, India"]
        )
    }

    func test_missingProfileHeadlineAndLocationRemainHonestlyUnavailable() {
        let item = ResumeReviewItem(
            id: "profile_missing",
            claimType: "profile",
            sourceClaimID: "claim_missing",
            originalPayload: [:],
            editedPayload: [
                "full_name": .string("Aman Jha")
            ],
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.9,
            version: 1
        )

        XCTAssertNil(ResumeImportMapper.displaySubtitle(for: item))
        XCTAssertEqual(ResumeImportMapper.detailLines(for: item), [])
    }

    func test_parserNullEducationDatesRemainAbsent() {
        let item = ResumeReviewItem(
            id: "education_1",
            claimType: "education",
            sourceClaimID: "claim_education",
            originalPayload: [
                "institution_name": .string("Riverdale Institute of Technology"),
                "degree": .string("Bachelor of Technology (B.Tech)"),
                "field_of_study": .string("Information Technology"),
                "start_date": .null,
                "end_date": .null,
                "start_date_display": .null,
                "end_date_display": .null
            ],
            editedPayload: [
                "institution_name": .string("Riverdale Institute of Technology"),
                "degree": .string("Bachelor of Technology (B.Tech)"),
                "field_of_study": .string("Information Technology"),
                "start_date": .null,
                "end_date": .null,
                "start_date_display": .null,
                "end_date_display": .null
            ],
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.9,
            version: 1
        )

        XCTAssertEqual(
            ResumeImportMapper.detailLines(for: item),
            ["Bachelor of Technology (B.Tech)", "Information Technology"]
        )
    }

    func test_parserNullCertificationIssuedDateRemainsAbsent() {
        let item = ResumeReviewItem(
            id: "certification_1",
            claimType: "certification",
            sourceClaimID: "claim_certification",
            originalPayload: [
                "title": .string("Certified Scrum Product Owner"),
                "issuing_organization": .string("Scrum Alliance"),
                "issued_date": .null
            ],
            editedPayload: [
                "title": .string("Certified Scrum Product Owner"),
                "issuing_organization": .string("Scrum Alliance"),
                "issued_date": .null
            ],
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.9,
            version: 1
        )

        XCTAssertEqual(
            ResumeImportMapper.detailLines(for: item),
            ["Scrum Alliance"]
        )
    }

    func test_selectionUpdateRequestUsesItemVersionNotSessionVersion() {
        let item = makeItem(id: "employment_1", claimType: "employment", title: "Northstar Labs")

        let request = ResumeImportMapper.selectionUpdateRequest(for: item, selected: false)

        XCTAssertEqual(request.expectedVersion, item.version)
        XCTAssertEqual(request.selected, false)
        XCTAssertNil(request.editedPayload)
    }

    func test_reconciledUpdateRequestUsesLatestItemVersion() {
        let latestItem = ResumeReviewItem(
            id: "employment_1",
            claimType: "employment",
            sourceClaimID: "claim_1",
            originalPayload: ["company_name": .string("Northstar Labs")],
            editedPayload: ["company_name": .string("Northstar Labs")],
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.9,
            version: 7
        )

        let request = ResumeImportMapper.reconciledUpdateRequest(
            for: latestItem,
            desiredEditedPayload: ["company_name": .string("Updated Labs")]
        )

        XCTAssertEqual(request?.expectedVersion, 7)
        XCTAssertEqual(request?.editedPayload?["company_name"], .string("Updated Labs"))
    }

    func test_reconciledUpdateRequestReturnsNilWhenLatestAlreadyMatchesDesiredState() {
        let latestItem = makeItem(id: "skill_1", claimType: "skill", title: "Trust Operations")

        let request = ResumeImportMapper.reconciledUpdateRequest(
            for: latestItem,
            desiredSelected: true
        )

        XCTAssertNil(request)
    }

    private func makeItem(
        id: String,
        claimType: String,
        title: String,
        subtitle: String? = nil
    ) -> ResumeReviewItem {
        var payload: [String: JSONValue] = [:]
        switch claimType {
        case "employment":
            payload["company_name"] = .string(title)
            payload["role_title"] = .string(subtitle ?? "Operations Analyst")
        case "education":
            payload["institution_name"] = .string(title)
            payload["degree"] = .string(subtitle ?? "B.Tech")
        case "skill":
            payload["name"] = .string(title)
        default:
            payload["full_name"] = .string(title)
        }

        return ResumeReviewItem(
            id: id,
            claimType: claimType,
            sourceClaimID: "claim_\(id)",
            originalPayload: payload,
            editedPayload: payload,
            selected: true,
            reviewStatus: "draft",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.9,
            version: 1
        )
    }
}
