import XCTest
@testable import Kairo

@MainActor
final class PassportHierarchyTests: XCTestCase {
    func testOwnerCountsDoNotPromotePendingOrCandidateProvidedRecordsOrChangeScore() throws {
        guard case .populated(let content) = PassportOverviewState.populatedFixture().phase else {
            return XCTFail("Missing fixture")
        }
        let counts = PassportHierarchyCounts(content: content)
        XCTAssertEqual(counts.verified, 2)
        XCTAssertEqual(counts.candidateProvided,
                       (content.employment.map(\.verificationStatus) + content.education.map(\.verificationStatus)
                        + content.portfolio.map(\.verificationStatus)).filter { $0 != .verified }.count)
        guard case .available(let score) = content.trustScore else { return XCTFail("Missing score") }
        XCTAssertEqual(score.value, 72)
        XCTAssertEqual(content.employment.last?.verificationStatus, .pendingVerification)
    }

    func testOwnerHierarchyKeepsTrustAndSingleShareAheadOfRecordsAndSecondaryMetadata() {
        guard case .populated(let content) = PassportOverviewState.populatedFixture().phase else { return XCTFail() }
        XCTAssertEqual(Array(content.visibleSections.prefix(4)), [.trustScore, .share, .verifiedSummary, .candidateProvidedSummary])
        XCTAssertEqual(content.visibleSections.filter { $0 == .share }.count, 1)
        XCTAssertEqual(Array(content.visibleSections.suffix(4)), [.passportStrength, .identity, .trustTimeline, .actions])
    }

    func testStagesAndModeLabelsPreserveExplicitOptInAndSeparateLegacy() {
        XCTAssertEqual(PassportShareHierarchy.stages, ["1. Sharing mode", "2. Choose what to share", "3. Purpose & expiry", "4. Review", "5. Share ready"])
        XCTAssertEqual(PassportShareHierarchy.modeTitle(.verifiedOnly), "Verified only")
        XCTAssertEqual(PassportShareHierarchy.modeTitle(.mixed), "Verified + Candidate-provided")
        XCTAssertEqual(PassportShareHierarchy.modeTitle(.legacyMixed), "Legacy sharing policy")
        XCTAssertEqual(PassportShareDraft().sharingMode, .verifiedOnly)
        XCTAssertEqual(PassportShareCapabilities.demoV2.options(for: .legacyMixed), [])
        XCTAssertFalse(PassportShareCapabilities.demoV2.modes.contains("legacy_mixed"))
    }

    func testPurposeReviewUsesExactlyCanonicalTrimAndValidationBoundaries() {
        var draft = PassportShareDraft()
        for value in ["", " \n\t", String(repeating: "x", count: 121)] {
            draft.label = value
            XCTAssertNotNil(draft.purposeValidationMessage)
            XCTAssertNil(draft.mutationInput())
        }
        draft.label = " \n "
        XCTAssertEqual(PassportShareHierarchy.purpose(draft), "Required")
        for value in ["x", String(repeating: "x", count: 120)] {
            draft.label = " \n" + value + "\t "
            XCTAssertNil(draft.purposeValidationMessage)
            XCTAssertEqual(PassportShareHierarchy.purpose(draft), value)
            XCTAssertEqual(draft.mutationInput()?.label, value)
        }
    }

    func testReviewListsEverySelectedSectionWithoutDisabledOrSeparateDisclosureLeakage() {
        var permissions = PassportSharePermissions.privacyPreserving
        for option: PassportSharePermissionOption in [.employments, .certifications, .skills, .projects, .profile, .photo, .trustScore] {
            permissions.set(true, for: option)
        }
        XCTAssertEqual(PassportShareHierarchy.selectedSections(permissions), permissions.enabledOptions.filter {
            ![.profile, .photo, .trustScore].contains($0)
        }.map(\.title))
        XCTAssertFalse(PassportShareHierarchy.selectedSections(permissions).contains(PassportSharePermissionOption.educations.title))
        XCTAssertEqual(PassportShareHierarchy.selectedSections(.privacyPreserving), [])
    }

    func testModeChangeClearsPriorDisclosuresAndOnlyAddsSupportedVerifiedDefaults() {
        var draft = PassportShareDraft()
        draft.selectMode(.mixed, capabilities: .demoV2)
        draft.permissions.includeProfile = true
        draft.permissions.showPhoto = true
        draft.permissions.showTrustScore = true
        draft.selectMode(.verifiedOnly, capabilities: .demoV2)
        XCTAssertEqual(Set(draft.permissions.enabledOptions), Set([.employments, .educations, .employerNames]))
        draft.selectMode(.mixed, capabilities: .demoV2)
        XCTAssertEqual(draft.permissions.enabledOptions, [])
    }

    func testProfilePhotoAndDocumentDependenciesStillFailClosed() {
        var draft = PassportShareDraft()
        draft.label = "Synthetic review"
        draft.selectMode(.mixed, capabilities: .demoV2)
        draft.permissions.showPhoto = true
        XCTAssertEqual(draft.validationMessage, "Profile photo requires profile details.")
        draft.permissions.includeProfile = true
        XCTAssertNil(draft.validationMessage)
        draft.permissions.includeUserDocuments = true
        XCTAssertEqual(draft.validationMessage, "User documents require supporting documents permission.")
        draft.permissions.showDocuments = true
        XCTAssertNil(draft.validationMessage)
    }

    func testServerUnsupportedSectionsAndTrustScoreNeverBecomeControls() {
        let restricted = PassportShareCapabilities(policyVersion: 2, defaultMode: "verified_only",
            modes: ["verified_only", "verified_and_candidate_provided"], verifiedOnlySections: ["include_educations"],
            mixedSections: ["include_skills"], derivedTrustScore: false, narrowOnlyUpdates: true)
        XCTAssertEqual(restricted.options(for: .verifiedOnly), [.educations, .employerNames, .documents])
        XCTAssertEqual(restricted.options(for: .mixed), [.skills, .employerNames, .documents])
    }

    func testExpiryReviewUsesUnchangedPresetsAndExactCustomDate() {
        var draft = PassportShareDraft()
        draft.label = "QA"
        for preset in PassportShareExpiryPreset.allCases where preset != .custom {
            draft.expiryPreset = preset
            XCTAssertEqual(PassportShareHierarchy.expiry(draft), preset.title)
            XCTAssertNotNil(draft.mutationInput())
        }
        draft.expiryPreset = .custom
        XCTAssertEqual(PassportShareHierarchy.expiry(draft), draft.customExpiry.formatted(date: .abbreviated, time: .shortened))
        XCTAssertEqual(draft.mutationInput()?.expiresAt, draft.customExpiry)
    }
}
