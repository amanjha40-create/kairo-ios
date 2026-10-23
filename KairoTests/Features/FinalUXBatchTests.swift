import Foundation
import XCTest
@testable import Kairo

final class FinalUXBatchTests: XCTestCase {
    func testSelectAllRespectsVerifiedOnlyPolicyAndDoesNotOptIntoPrivateProfile() {
        var draft = PassportShareDraft()
        draft.selectAll(capabilities: .demoV2)
        XCTAssertEqual(Set(draft.permissions.enabledOptions), Set([.employments, .educations, .employerNames, .documents, .trustScore]))
        XCTAssertEqual(draft.sharingMode, .verifiedOnly)
        XCTAssertFalse(draft.permissions.includeProfile)
        XCTAssertFalse(draft.permissions.showPhoto)
        XCTAssertFalse(draft.permissions.includeUserDocuments)
    }

    func testSelectAllMixedIncludesOnlySupportedOptionsAndBothDependencies() throws {
        var draft = PassportShareDraft()
        draft.selectMode(.mixed, capabilities: .demoV2)
        draft.selectAll(capabilities: .demoV2)
        XCTAssertEqual(Set(draft.permissions.enabledOptions), Set(PassportShareCapabilities.demoV2.options(for: .mixed)))
        XCTAssertTrue(draft.permissions.includeProfile && draft.permissions.showPhoto)
        XCTAssertTrue(draft.permissions.showDocuments && draft.permissions.includeUserDocuments)
        XCTAssertFalse(draft.permissions.includeInternships || draft.permissions.includeFreelance || draft.permissions.includeGigPlatforms)
        draft.label = "Synthetic review"
        try PassportShareCapabilities.demoV2.validate(XCTUnwrap(draft.mutationInput()))
        draft.deselectAll()
        XCTAssertEqual(draft.permissions, .privacyPreserving)
        XCTAssertEqual(draft.sharingMode, .mixed)
        XCTAssertEqual(draft.label, "Synthetic review")
    }

    func testPhotoCannotBeEnabledWithoutProfileAndClearsWithProfile() {
        var draft = PassportShareDraft()
        draft.selectMode(.mixed, capabilities: .demoV2)
        draft.setPermission(true, for: .photo, capabilities: .demoV2)
        XCTAssertFalse(draft.permissions.showPhoto)
        draft.setPermission(true, for: .profile, capabilities: .demoV2)
        draft.setPermission(true, for: .photo, capabilities: .demoV2)
        XCTAssertTrue(draft.permissions.showPhoto)
        draft.setPermission(false, for: .profile, capabilities: .demoV2)
        XCTAssertFalse(draft.permissions.showPhoto)
        draft.setPermission(true, for: .userDocuments, capabilities: .demoV2)
        XCTAssertFalse(draft.permissions.includeUserDocuments)
    }

    func testUnavailableOptionsAndMissingDependenciesRemainOff() {
        let policy = PassportShareCapabilities(policyVersion: 2, defaultMode: "verified_only",
            modes: ["verified_only", "verified_and_candidate_provided"], verifiedOnlySections: [],
            mixedSections: ["show_photo", "include_skills"], derivedTrustScore: false, narrowOnlyUpdates: true)
        var draft = PassportShareDraft()
        draft.selectMode(.mixed, capabilities: policy)
        draft.selectAll(capabilities: policy)
        XCTAssertTrue(draft.permissions.includeSkills)
        XCTAssertFalse(draft.permissions.showPhoto || draft.permissions.includeProfile || draft.permissions.showTrustScore)
        XCTAssertFalse(draft.permissions.includeEmployments || draft.permissions.includeEducations)
        draft.setPermission(true, for: .employments, capabilities: policy)
        XCTAssertFalse(draft.permissions.includeEmployments)
        draft.selectAll(capabilities: nil)
        XCTAssertEqual(draft.permissions, .privacyPreserving)
    }

    func testSelectAllCannotExpandExistingLinkEvenWithBroaderCurrentCapabilities() {
        var original = PassportSharePermissions.privacyPreserving
        original.includeEducations = true
        let share = PassportShare(id: "synthetic", label: "Narrow only", permissions: original,
            trackViews: false, expiresAt: nil, revokedAt: nil, lastViewedAt: nil,
            createdAt: .distantPast, updatedAt: .distantPast, state: .active,
            policyVersion: 2, sharingMode: .verifiedOnly)
        var draft = PassportShareDraft(share: share)
        draft.deselectAll()
        draft.selectAll(capabilities: .demoV2)
        XCTAssertEqual(draft.permissions, original)
        draft.setPermission(true, for: .employments, capabilities: .demoV2)
        XCTAssertEqual(draft.permissions, original)
    }

    func testBackendResumeClassificationSelectionAndConfidenceAreNotInventedByIOS() throws {
        // Synthetic transport evidence: preserves the backend's classifications,
        // confidence and selection rather than hiding a parser defect in the UI.
        let names = ["ticket size", "market updates every Friday", "and local team inputs", "Swift", "swift!"]
        for (index, name) in names.enumerated() {
            let wire: [String: Any] = [
                "id": "synthetic-\(index)", "claim_type": "skill", "source_claim_id": "source-\(index)",
                "original_payload": ["name": name], "edited_payload": ["name": name],
                "selected": index != 2, "review_status": "selected", "duplicate_status": "no_match",
                "duplicate_candidates": [], "conflict_warnings": [], "import_action": "create_new",
                "confidence": 0.05, "version": 1
            ]
            let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
            let dto = try decoder.decode(ResumeReviewItemDTO.self, from: JSONSerialization.data(withJSONObject: wire))
            let mapped = ResumeImportMapper.map(dto)
            XCTAssertEqual(mapped.claimType, "skill")
            XCTAssertEqual(mapped.selected, index != 2)
            XCTAssertEqual(mapped.confidence, 0.05)
            XCTAssertEqual(ResumeImportMapper.displayTitle(for: mapped), name)
        }
    }
}
