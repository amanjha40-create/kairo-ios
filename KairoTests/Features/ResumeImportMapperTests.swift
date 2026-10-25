import Foundation
import XCTest
@testable import Kairo

final class ResumeImportMapperTests: XCTestCase {
    func testInstitutionFreeTextNeverAutoLinksAndExplicitSelectionSurvivesReviewEncoding() throws {
        let item = makeItem(id: "education", claimType: "education", title: "Synthetic Institute")
        let unchanged = ResumeImportMapper.editedPayload(for: item, using: ["institution_name": "Synthetic Institute", "degree": "Updated degree"])
        XCTAssertNil(unchanged["institution_catalogue_id"])
        XCTAssertNil(unchanged["institution_catalogue_version"])
        let selected = ResumeImportMapper.editedPayload(for: item, using: ["institution_name": "Synthetic Institute", "institution_catalogue_id": "synthetic-id", "institution_catalogue_version": "test-v1"])
        let encoded = try APIJSONCoder.makeEncoder().encode(selected)
        let decoded = try APIJSONCoder.makeDecoder().decode([String: JSONValue].self, from: encoded)
        XCTAssertEqual(decoded["institution_catalogue_id"], .string("synthetic-id"))
        XCTAssertEqual(decoded["institution_catalogue_version"], .string("test-v1"))
    }

    func testInstitutionManualEditClearsBothLinksAndUnrelatedEditPreservesThem() {
        let item = makeItem(id: "education", claimType: "education", title: "Synthetic Institute", additionalPayload: ["institution_catalogue_id": .string("synthetic-id"), "institution_catalogue_version": .string("test-v1")])
        let unrelated = ResumeImportMapper.editedPayload(for: item, using: ["degree": "Updated degree"])
        XCTAssertEqual(unrelated["institution_catalogue_id"], .string("synthetic-id"))
        for values in [["institution_name": "Historical name"], ["institution_name": "Synthetic Institute", "institution_catalogue_id": "", "institution_catalogue_version": ""]] {
            let manual = ResumeImportMapper.editedPayload(for: item, using: values)
            XCTAssertEqual(manual["institution_catalogue_id"], .null)
            XCTAssertEqual(manual["institution_catalogue_version"], .null)
        }
    }
    func test_certificationEditorUsesAPI42IssuedDateKey() {
        let item = makeItem(id: "certification_1", claimType: "certification", title: "Synthetic certificate")
        let keys = ResumeImportMapper.editableFields(for: item).map(\.key)
        XCTAssertTrue(keys.contains("issued_date"))
        XCTAssertFalse(keys.contains("issue_date"), "API42 forbids unknown claim fields")
    }

    func test_clearedReviewDatesCannotBeResurrectedByDisplayAliases() {
        let item = makeItem(id: "employment_1", claimType: "employment", title: "Synthetic", subtitle: "Engineer", additionalPayload: ["start_date": .null, "start_date_display": .string("2020"), "start_date_precision": .string("year")])
        let payload = ResumeImportMapper.editedPayload(for: item, using: ["start_date": "", "end_date": "2024-12-31"])
        XCTAssertEqual(payload["start_date"], .null)
        XCTAssertEqual(payload["start_date_display"], .null)
        XCTAssertEqual(payload["start_date_precision"], .null)
        XCTAssertEqual(payload["end_date"], .string("2024-12-31"))
        XCTAssertEqual(payload["end_date_display"], .null)
        XCTAssertEqual(payload["end_date_precision"], .null)
        XCTAssertNil(payload["is_current"], "Editing a date must not invent current-study or employment state")
    }

    func test_API43CurrentEducationNeverSilentlyChangesCurrentOrDiscardsConflictingDate() {
        let item = makeItem(id: "education_current", claimType: "education", title: "Synthetic",
            additionalPayload: ["is_current": .bool(true), "end_date": .null])
        let edited = ResumeImportMapper.editedPayload(for: item, using: ["end_date": "2026-06-01"])
        XCTAssertEqual(edited["is_current"], .bool(true))
        XCTAssertEqual(edited["end_date"], .string("2026-06-01"), "API43 must reject the conflict for explicit review")
        let valid = ResumeImportMapper.editedPayload(for: item, using: ["degree": "Updated degree"])
        XCTAssertEqual(valid["is_current"], .bool(true))
        XCTAssertEqual(valid["end_date"], .null)
    }

    func test_API43HistoricalContradictionSurvivesUnrelatedEditAndOnlyExplicitClearRemovesDate() {
        let item = makeItem(id: "education_conflict", claimType: "education", title: "Synthetic",
            additionalPayload: ["is_current": .bool(true), "end_date": .string("2026-06-01"),
                                "end_date_display": .string("2026-06-01"), "end_date_precision": .string("day")])
        let unrelated = ResumeImportMapper.editedPayload(for: item, using: ["degree": "Updated degree"])
        XCTAssertEqual(unrelated["is_current"], .bool(true))
        XCTAssertEqual(unrelated["end_date"], item.editedPayload["end_date"])
        XCTAssertEqual(unrelated["end_date_display"], item.editedPayload["end_date_display"])
        let cleared = ResumeImportMapper.editedPayload(for: item, using: ["end_date": ""])
        XCTAssertEqual(cleared["is_current"], .bool(true))
        for key in ["end_date", "end_date_display", "end_date_precision"] { XCTAssertEqual(cleared[key], .null) }
        XCTAssertEqual(item.editedPayload["end_date"], .string("2026-06-01"))
    }

    func test_partialImportGuidanceIdentifiesFailedItemWithoutExposingContent() {
        let review = ResumeReviewSession(id: "review", resumeID: "resume", parsedResultID: "parsed", status: .reviewing, schemaVersion: "resume_review_v1", version: 1, items: [makeItem(id: "one", claimType: "employment", title: "Private company"), makeItem(id: "two", claimType: "employment", title: "Another private company")], createdAt: .distantPast, updatedAt: .distantPast)
        let batch = ResumeImportBatch(id: "batch", reviewSessionID: "review", status: "partially_completed", totalCount: 2, importedCount: 1, linkedCount: 0, skippedCount: 0, failedCount: 1, blockedCount: 0, incompleteCount: 0, entityCounts: [:], results: [.init(reviewItemID: "one", outcome: "imported", recordType: "employment", recordID: "record", sanitizedErrorCode: nil, warnings: []), .init(reviewItemID: "two", outcome: "failed", recordType: nil, recordID: nil, sanitizedErrorCode: "validation_error", warnings: [])], createdAt: .distantPast, updatedAt: .distantPast)
        let guidance = ResumeImportMapper.failedItemGuidance(batch: batch, review: review)
        XCTAssertTrue(guidance.contains("item 2"))
        XCTAssertFalse(guidance.contains("item 1"))
        XCTAssertFalse(guidance.contains("private company"))
        XCTAssertTrue(guidance.contains("Already imported records are preserved"))
        XCTAssertTrue(ResumeImportMapper.failedItemGuidance(batch: batch, review: nil).contains("Refresh the review"))
    }

    func test_profileEditorDoesNotEmitForbiddenEmailOrStringLocation() {
        let item = makeItem(id: "profile_1", claimType: "profile", title: "Synthetic")
        XCTAssertEqual(ResumeImportMapper.editableFields(for: item).map(\.key), ["full_name", "professional_headline"])
    }
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

    func test_projectEditorEmitsOnlyCanonicalBackendFieldsAndPersistsEditedValues() {
        let item = ResumeReviewItem(
            id: "project_1",
            claimType: "project",
            sourceClaimID: "claim_project",
            originalPayload: [
                "claim_type": .string("project"),
                "title": .string("Synthetic Project"),
                "description": .string("Synthetic description"),
                "url": .string("https://example.test/project")
            ],
            editedPayload: [
                "claim_type": .string("project"),
                "title": .string("Synthetic Project"),
                "description": .string("Synthetic description"),
                "url": .string("https://example.test/project")
            ],
            selected: true,
            reviewStatus: "selected",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .createNew,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.98,
            version: 3
        )

        XCTAssertEqual(
            ResumeImportMapper.editableFields(for: item).map(\.key),
            ["title", "description", "url"]
        )

        let edited = ResumeImportMapper.editedPayload(
            for: item,
            using: [
                "title": "Synthetic Project Updated",
                "description": "Synthetic description",
                "url": "https://example.test/project/"
            ]
        )
        let request = ResumeImportMapper.editedPayloadUpdateRequest(
            for: item,
            editedPayload: edited
        )

        XCTAssertEqual(request.editedPayload?["title"], .string("Synthetic Project Updated"))
        XCTAssertEqual(request.editedPayload?["url"], .string("https://example.test/project/"))
        XCTAssertNil(request.editedPayload?["project_title"])
        XCTAssertNil(request.editedPayload?["portfolio_url"])
        XCTAssertNil(request.editedPayload?["role"])
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

    func test_profileHeadlineEditPreservesSuggestionOnlySelectionContract() throws {
        let item = ResumeReviewItem(
            id: "profile_1",
            claimType: "profile",
            sourceClaimID: "claim_profile",
            originalPayload: [
                "claim_type": .string("profile"),
                "full_name": .string("Synthetic Candidate"),
                "professional_headline": .string("Analyst")
            ],
            editedPayload: [
                "claim_type": .string("profile"),
                "full_name": .string("Synthetic Candidate"),
                "professional_headline": .string("Analyst")
            ],
            selected: false,
            reviewStatus: "deselected",
            duplicateStatus: .noMatch,
            duplicateCandidates: [],
            conflictWarnings: [],
            importAction: .skip,
            targetRecordID: nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: nil,
            confidence: 0.9,
            version: 4
        )
        let edited = ResumeImportMapper.editedPayload(
            for: item,
            using: ["professional_headline": "Product Operations Lead"]
        )
        let request = ResumeImportMapper.editedPayloadUpdateRequest(
            for: item,
            editedPayload: edited
        )

        XCTAssertEqual(request.expectedVersion, 4)
        XCTAssertNil(request.selected)
        XCTAssertNil(request.importAction)
        XCTAssertEqual(request.editedPayload?["professional_headline"], .string("Product Operations Lead"))
        XCTAssertFalse(ResumeImportMapper.isSelectionEditable(for: item))

        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(request)) as? [String: Any]
        )
        XCTAssertNil(body["selected"])
        XCTAssertNil(body["import_action"])
    }

    func test_bulkSelectionIncludesOnlyEligibleImportableClaims() {
        let eligibleSelected = makeItem(id: "project_1", claimType: "project", title: "One")
        let eligibleUnselected = item(eligibleSelected, id: "project_2", selected: false)
        let conflict = item(
            eligibleSelected,
            id: "project_conflict",
            selected: false,
            duplicateStatus: .conflict,
            warnings: ["structural_conflict"]
        )
        let suggestion = item(
            eligibleSelected,
            id: "profile",
            claimType: "profile",
            selected: false,
            importAction: .skip
        )
        let section = ResumeReviewSection(
            id: "project",
            title: "Projects",
            items: [eligibleSelected, eligibleUnselected, conflict, suggestion]
        )

        XCTAssertEqual(ResumeImportMapper.bulkSelectableItems(in: section).map(\.id), ["project_1", "project_2"])
        XCTAssertEqual(ResumeImportMapper.bulkSelectionTarget(in: section), true)
        XCTAssertEqual(
            ResumeImportMapper.bulkSelectionChanges(in: section, selected: true).map(\.id),
            ["project_2"]
        )

        let allSelected = ResumeReviewSection(
            id: section.id,
            title: section.title,
            items: [eligibleSelected, item(eligibleUnselected, id: "project_2", selected: true), conflict, suggestion]
        )
        XCTAssertEqual(ResumeImportMapper.bulkSelectionTarget(in: allSelected), false)
        XCTAssertEqual(
            ResumeImportMapper.bulkSelectionChanges(in: allSelected, selected: false).map(\.id),
            ["project_1", "project_2"]
        )
    }

    func test_bulkSelectionSupportsOnlyApprovedClaimTypes() {
        let approvedTypes = ["employment", "education", "certification", "project", "skill"]

        for claimType in approvedTypes {
            let item = makeItem(id: claimType, claimType: claimType, title: "Synthetic")
            XCTAssertTrue(ResumeImportMapper.isSelectionEditable(for: item), claimType)
        }

        let profile = makeItem(id: "profile", claimType: "profile", title: "Synthetic Candidate")
        XCTAssertFalse(ResumeImportMapper.isSelectionEditable(for: profile))
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
        subtitle: String? = nil,
        additionalPayload: [String: JSONValue] = [:]
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

        payload.merge(additionalPayload) { _, new in new }
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

    private func item(
        _ source: ResumeReviewItem,
        id: String,
        claimType: String? = nil,
        selected: Bool,
        duplicateStatus: ResumeDuplicateStatus? = nil,
        warnings: [String]? = nil,
        importAction: ResumeImportAction? = nil
    ) -> ResumeReviewItem {
        ResumeReviewItem(
            id: id,
            claimType: claimType ?? source.claimType,
            sourceClaimID: "claim_\(id)",
            originalPayload: source.originalPayload,
            editedPayload: source.editedPayload,
            selected: selected,
            reviewStatus: selected ? "selected" : "deselected",
            duplicateStatus: duplicateStatus ?? source.duplicateStatus,
            duplicateCandidates: source.duplicateCandidates,
            conflictWarnings: warnings ?? source.conflictWarnings,
            importAction: importAction ?? source.importAction,
            targetRecordID: source.targetRecordID,
            importedRecordType: source.importedRecordType,
            importedRecordID: source.importedRecordID,
            sourceReference: source.sourceReference,
            confidence: source.confidence,
            version: source.version
        )
    }
}
