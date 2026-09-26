import Foundation
import XCTest
@testable import Kairo

final class ResumeEmploymentDuplicateReviewTests: XCTestCase {
    func test_exactDuplicateKeepsExistingRecordAsResolvedState() {
        let state = ResumeImportMapper.employmentDuplicateReviewState(
            for: makeItem(duplicateStatus: .exactMatch, importAction: .linkExisting)
        )

        guard case .alreadyInCareer(let existing) = state else {
            return XCTFail("Expected an Already in Career state")
        }
        XCTAssertEqual(existing?.employer, "Northstar Labs")
        XCTAssertEqual(existing?.role, "Senior Engineer")
    }

    func test_exactDuplicateDoesNotAllowAddAsNewOrGenerateDecisionMutation() {
        let item = makeItem(duplicateStatus: .exactMatch, importAction: .linkExisting)
        let state = ResumeImportMapper.employmentDuplicateReviewState(for: item)

        XCTAssertFalse(state.allowsAddAsNewRole)
        XCTAssertNil(ResumeImportMapper.employmentDecisionUpdateRequest(
            for: item,
            decision: .addAsNewRole,
            distinctRoleConfirmed: true
        ))
    }

    func test_possibleMatchDefaultsToKeepExisting() {
        let state = ResumeImportMapper.employmentDuplicateReviewState(
            for: makeItem(duplicateStatus: .possibleMatch, importAction: .skip)
        )

        XCTAssertEqual(state.selectedDecision, .keepExisting)
        XCTAssertTrue(state.allowsAddAsNewRole)
    }

    func test_possibleMatchRepresentsBackendPersistedAddAsNewSelection() {
        let state = ResumeImportMapper.employmentDuplicateReviewState(
            for: makeItem(duplicateStatus: .possibleMatch, importAction: .createNew)
        )

        XCTAssertEqual(state.selectedDecision, .addAsNewRole)
    }

    func test_addAsNewCannotGenerateRequestWithoutExplicitConfirmation() {
        let request = ResumeImportMapper.employmentDecisionUpdateRequest(
            for: makeItem(duplicateStatus: .possibleMatch, importAction: .skip),
            decision: .addAsNewRole,
            distinctRoleConfirmed: false
        )

        XCTAssertNil(request)
    }

    func test_confirmedDistinctRoleUsesExactBackendPayload() throws {
        let request = try XCTUnwrap(ResumeImportMapper.employmentDecisionUpdateRequest(
            for: makeItem(duplicateStatus: .possibleMatch, importAction: .skip),
            decision: .addAsNewRole,
            distinctRoleConfirmed: true
        ))

        XCTAssertEqual(request.selected, true)
        XCTAssertEqual(request.importAction, "create_new")
        XCTAssertEqual(request.confirmDistinctRole, true)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(request)) as? [String: Any])
        XCTAssertEqual(json["confirm_distinct_role"] as? Bool, true)
    }

    func test_sameEmployerDifferentRoleRemainsBackendDirectedPossibleMatch() {
        let item = makeItem(
            duplicateStatus: .possibleMatch,
            importAction: .skip,
            importedRole: "Engineering Manager",
            importedStart: "2025-01"
        )

        guard case .possibleMatch(let existing, let imported, let decision) =
            ResumeImportMapper.employmentDuplicateReviewState(for: item) else {
            return XCTFail("Expected possible match")
        }
        XCTAssertEqual(existing?.employer, imported.employer)
        XCTAssertNotEqual(existing?.role, imported.role)
        XCTAssertEqual(decision, .keepExisting)
    }

    func test_sameEmployerDifferentPeriodDisplaysBothBackendDates() {
        let item = makeItem(
            duplicateStatus: .possibleMatch,
            importAction: .skip,
            importedRole: "Senior Engineer",
            importedStart: "2025-01"
        )

        guard case .possibleMatch(let existing, let imported, _) =
            ResumeImportMapper.employmentDuplicateReviewState(for: item) else {
            return XCTFail("Expected possible match")
        }
        XCTAssertEqual(existing?.dates, "2021-01 – 2023-12")
        XCTAssertEqual(imported.dates, "2025-01 – Present")
    }

    func test_decisionPersistsWhenReviewIsRecreatedFromBackendSession() {
        let firstVisit = ResumeImportMapper.employmentDuplicateReviewState(
            for: makeItem(duplicateStatus: .possibleMatch, importAction: .createNew, version: 4)
        )
        let returnedVisit = ResumeImportMapper.employmentDuplicateReviewState(
            for: makeItem(duplicateStatus: .possibleMatch, importAction: .createNew, version: 5)
        )

        XCTAssertEqual(firstVisit.selectedDecision, .addAsNewRole)
        XCTAssertEqual(returnedVisit.selectedDecision, .addAsNewRole)
    }

    func test_closingReviewDoesNotGenerateOrBeginDuplicateMutation() {
        let item = makeItem(duplicateStatus: .possibleMatch, importAction: .skip)
        let gate = ResumeEmploymentDecisionSubmissionGate()

        _ = ResumeImportMapper.employmentDuplicateReviewState(for: item)

        XCTAssertNil(gate.inFlightItemID)
        XCTAssertEqual(item.importAction, .skip)
    }

    func test_finalSummaryCountsExistingRecordSeparatelyFromAdded() {
        let summary = ResumeImportResultSummary(batch: makeBatch(
            imported: 2,
            linked: 1,
            skipped: 3
        ))

        XCTAssertEqual(summary.added, 2)
        XCTAssertEqual(summary.alreadyInCareer, 1)
        XCTAssertEqual(summary.skipped, 3)
    }

    func test_postImportCareerRefreshReturnsOnlyAuthoritativeLoaderValue() async throws {
        let probe = AuthoritativeLoaderProbe()

        let result = try await ResumePostImportCareerRefresh.loadAuthoritativeOverview {
            await probe.load()
        }
        let callCount = await probe.callCount()

        XCTAssertEqual(result, "backend-career-v2")
        XCTAssertEqual(callCount, 1)
    }

    func test_decisionDTOCannotOverwriteEvidenceHistoryOrExistingFacts() throws {
        let item = makeItem(duplicateStatus: .possibleMatch, importAction: .skip)
        let request = try XCTUnwrap(ResumeImportMapper.employmentDecisionUpdateRequest(
            for: item,
            decision: .keepExisting,
            distinctRoleConfirmed: false
        ))

        XCTAssertNil(request.targetRecordID)
        XCTAssertNil(request.editedPayload)
        XCTAssertNil(request.confirmDistinctRole)
        XCTAssertEqual(request.importAction, "skip")
    }

    func test_failedMutationCannotCreateALocalAddAsNewAssumption() {
        let item = makeItem(duplicateStatus: .possibleMatch, importAction: .skip)
        let before = ResumeImportMapper.employmentDuplicateReviewState(for: item)
        _ = ResumeImportMapper.employmentDecisionUpdateRequest(
            for: item,
            decision: .addAsNewRole,
            distinctRoleConfirmed: true
        )
        let after = ResumeImportMapper.employmentDuplicateReviewState(for: item)

        XCTAssertEqual(before, after)
        XCTAssertEqual(after.selectedDecision, .keepExisting)
    }

    func test_submissionGateRejectsDoubleTapAndAllowsDeliberateRetryAfterCompletion() {
        var gate = ResumeEmploymentDecisionSubmissionGate()

        XCTAssertTrue(gate.begin(itemID: "employment-possible"))
        XCTAssertFalse(gate.begin(itemID: "employment-possible"))
        XCTAssertFalse(gate.begin(itemID: "another-item"))
        gate.finish(itemID: "employment-possible")
        XCTAssertTrue(gate.begin(itemID: "employment-possible"))
    }

    func test_reviewedOutcomesUseTruthfulProductLanguage() {
        XCTAssertEqual(
            ResumeImportMapper.reviewedOutcome(
                for: makeItem(duplicateStatus: .exactMatch, importAction: .linkExisting)
            ),
            .alreadyInCareer
        )
        XCTAssertEqual(
            ResumeImportMapper.reviewedOutcome(
                for: makeItem(duplicateStatus: .possibleMatch, importAction: .skip)
            ),
            .keepExisting
        )
        XCTAssertEqual(
            ResumeImportMapper.reviewedOutcome(
                for: makeItem(duplicateStatus: .possibleMatch, importAction: .createNew)
            ),
            .addAsNewRole
        )
    }

    func test_comparisonSummaryIgnoresInternalMatchingDiagnostics() {
        let item = makeItem(duplicateStatus: .possibleMatch, importAction: .skip)

        guard case .possibleMatch(let existing, _, _) =
            ResumeImportMapper.employmentDuplicateReviewState(for: item) else {
            return XCTFail("Expected possible match")
        }
        XCTAssertEqual(existing?.accessibilitySummary, "Northstar Labs, Senior Engineer, 2021-01 – 2023-12, Bengaluru")
        XCTAssertFalse(existing?.accessibilitySummary.contains("0.87") ?? true)
        XCTAssertFalse(existing?.accessibilitySummary.contains("fingerprint") ?? true)
    }

    private func makeItem(
        duplicateStatus: ResumeDuplicateStatus,
        importAction: ResumeImportAction,
        importedRole: String = "Senior Engineer",
        importedStart: String = "2021-01",
        version: Int = 3
    ) -> ResumeReviewItem {
        let imported: [String: JSONValue] = [
            "employer_legal_name": .string("Northstar Labs"),
            "job_title": .string(importedRole),
            "start_date": .string(importedStart),
            "end_date": importedStart == "2025-01" ? .null : .string("2023-12"),
            "work_location_city": .string("Bengaluru")
        ]
        let candidate: [String: JSONValue] = [
            "record_id": .string("employment-existing"),
            "employer": .string("Northstar Labs"),
            "title": .string("Senior Engineer"),
            "start_date": .string("2021-01"),
            "end_date": .string("2023-12"),
            "location": .string("Bengaluru"),
            "similarity_score": .number(0.87),
            "match_fingerprint": .string("private-fingerprint")
        ]

        return ResumeReviewItem(
            id: "employment-possible",
            claimType: "employment",
            sourceClaimID: "claim-employment",
            originalPayload: imported,
            editedPayload: imported,
            selected: true,
            reviewStatus: "selected",
            duplicateStatus: duplicateStatus,
            duplicateCandidates: [candidate],
            conflictWarnings: [],
            importAction: importAction,
            targetRecordID: importAction == .linkExisting ? "employment-existing" : nil,
            importedRecordType: nil,
            importedRecordID: nil,
            sourceReference: "page_1",
            confidence: 0.99,
            version: version
        )
    }

    private func makeBatch(imported: Int, linked: Int, skipped: Int) -> ResumeImportBatch {
        ResumeImportBatch(
            id: "batch",
            reviewSessionID: "review",
            status: "completed",
            totalCount: imported + linked + skipped,
            importedCount: imported,
            linkedCount: linked,
            skippedCount: skipped,
            failedCount: 0,
            blockedCount: 0,
            incompleteCount: 0,
            entityCounts: [:],
            results: [],
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
    }
}

private actor AuthoritativeLoaderProbe {
    private var calls = 0

    func load() -> String {
        calls += 1
        return "backend-career-v2"
    }

    func callCount() -> Int {
        calls
    }
}
