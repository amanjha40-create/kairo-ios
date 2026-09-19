import XCTest
@testable import Kairo

@MainActor
final class MoreSettingsHierarchyTests: XCTestCase {
    func testHubContainsOnlyRoutingDestinations() {
        XCTAssertEqual(MoreHubDestination.allCases.map(\.rawValue), ["settings", "support", "legal"])
        XCTAssertEqual(Set(MoreHubDestination.allCases.map { $0.row.id }).count, 3)
    }

    func testAccountAndSecurityPartitionExistingDestinations() {
        let content = MoreOverviewContent.fixture()
        XCTAssertEqual(MoreSettingsHierarchy.accountRows(content).map(\.id), ["personalInformation"])
        XCTAssertEqual(MoreSettingsHierarchy.securityRows(content).map(\.id), ["loginSecurity", "sessionsDevices"])
        XCTAssertFalse(MoreSettingsHierarchy.securityRows(content).contains { $0.id == "documentVault" })
    }

    func testPrivacyNeverIncludesDestructiveOrUnsupportedControls() {
        let content = MoreOverviewContent.fixture()
        XCTAssertEqual(MoreSettingsHierarchy.privacyRows(content).map(\.id), ["manageConsent"])
        XCTAssertEqual(MoreSettingsHierarchy.destructiveRows(content).map(\.id), ["deleteAccount"])
    }

    func testPresentationPreservesSourceRowsAndPreferenceState() {
        let content = MoreOverviewContent.fixture()
        let original = content
        XCTAssertEqual(MoreSettingsHierarchy.accountRows(content).first, content.accountRows.first)
        _ = MoreSettingsHierarchy.securityRows(content)
        _ = MoreSettingsHierarchy.privacyRows(content)
        _ = MoreSettingsHierarchy.destructiveRows(content)
        XCTAssertEqual(content, original)
    }

    func testContactVerificationComesFromAuthoritativeFields() {
        let user = MoreOverviewContent.fixture().user
        XCTAssertEqual(MoreSettingsHierarchy.contactState(user), "Email verified • Phone verified")
        let absent = AppUser(id: "empty", email: "", fullName: nil, profileSlug: nil, phone: nil,
            currentRole: nil, industry: nil, yearsOfExperience: nil, location: nil, locationCity: nil,
            locationRegion: nil, locationCountry: nil, headline: nil, bio: nil, dateOfBirth: nil,
            avatarURL: nil, role: "candidate", isActive: true, phoneVerifiedAt: nil, emailVerifiedAt: nil,
            employmentOnboardingCompletedAt: nil, languages: [], professionalLinks: [],
            profileCompletionPercentage: 0, createdAt: .distantPast)
        XCTAssertEqual(MoreSettingsHierarchy.contactState(absent), "Email not verified • Phone not verified")
    }
}
