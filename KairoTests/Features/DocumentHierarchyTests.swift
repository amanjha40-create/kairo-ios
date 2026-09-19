import XCTest
@testable import Kairo

@MainActor
final class DocumentHierarchyTests: XCTestCase {
    func testGroupsCountEverySuppliedRowExactlyOnceAndPreserveCanonicalOrder() async throws {
        let rows = try await DocumentHierarchyFixtures(scenario: "populated").load()
        let groups = DocumentHierarchy.groups(rows, category: .all)
        XCTAssertEqual(groups.map(\.title), ["Employment", "Education", "Certifications", "Projects", "Verification", "Identity & Personal"])
        XCTAssertEqual(groups.flatMap(\.rows).count, rows.count)
        XCTAssertEqual(Set(groups.flatMap(\.rows).map(\.id)), Set(rows.map(\.id)))
        XCTAssertEqual(groups.last?.rows.count, 4)
    }
    func testFiltersRetainExactCanonicalCategoriesAndDoNotReclassifyVault() async throws {
        let rows = try await DocumentHierarchyFixtures(scenario: "populated").load()
        XCTAssertEqual(DocumentsHubRow.categories(in: rows), [.all, .employment, .education, .certifications, .projects, .verification, .other])
        for category in DocumentsHubCategory.allCases where category != .all {
            XCTAssertEqual(DocumentHierarchy.groups(rows, category: category).flatMap(\.rows), rows.filter { $0.category == category })
        }
    }
    func testPreciseVaultLabelsAndLegacyValuesDoNotBecomeUploadChoices() async throws {
        let rows = try await DocumentHierarchyFixtures(scenario: "populated").load()
        let titles = rows.filter { $0.category == .other }.map(DocumentHierarchy.title)
        XCTAssertEqual(titles, ["Birth Certificate", "Government ID", "Other", "Aadhaar"])
        XCTAssertEqual(VaultDocumentType.newUploadTypes.map(\.title), ["Aadhaar", "PAN", "Passport", "Driving Licence", "Voter ID", "Birth Certificate", "Address Proof"])
        XCTAssertFalse(VaultDocumentType.governmentID.allowsNewUpload)
        XCTAssertFalse(VaultDocumentType.other.allowsNewUpload)
    }
    func testSourceContextsAndPortfolioCompatibilityAreNotInventedOrRewritten() async throws {
        let rows = try await DocumentHierarchyFixtures(scenario: "populated").load()
        let grouped = DocumentHierarchy.groups(rows, category: .all).flatMap(\.rows)
        for row in rows { XCTAssertEqual(grouped.first { $0.id == row.id }, row) }
        XCTAssertEqual(grouped.first { $0.category == .employment }?.context, "Synthetic Employer")
        XCTAssertEqual(grouped.first { $0.category == .education }?.context, "Synthetic University")
        XCTAssertTrue(grouped.first { $0.category == .projects }?.context.contains("Legacy Portfolio origin") == true)
    }
    func testHistoricalEvidenceRemainsImmutableAndUnavailableInsteadOfInventingView() async throws {
        let rows = try await DocumentHierarchyFixtures(scenario: "populated").load()
        let historical = try XCTUnwrap(DocumentHierarchy.groups(rows, category: .verification).first?.rows.first)
        XCTAssertTrue(historical.historical); XCTAssertTrue(historical.immutable)
        XCTAssertFalse(historical.canView); XCTAssertFalse(historical.canReplace); XCTAssertFalse(historical.canRemove)
    }
    func testVaultLegacyGroupingDoesNotChangeCurrentOrHistoricalEligibility() {
        let documents = DocumentHierarchyFixtures.vaultDocuments
        XCTAssertEqual(documents.filter(DocumentHierarchy.vaultIsLegacy).map(\.id), ["government", "other"])
        XCTAssertTrue(documents[0].isCurrent)
        XCTAssertFalse(documents[3].isCurrent)
        XCTAssertTrue(documents.allSatisfy { $0.verificationStatus == "draft" && $0.verifiedAt == nil })
    }
    func testEmptyGroupsAreNotFabricated() {
        XCTAssertTrue(DocumentHierarchy.groups([], category: .all).isEmpty)
        XCTAssertTrue(DocumentHierarchy.groups([], category: .other).isEmpty)
    }
    func testOtherNonVaultRowsAreNotMislabelledIdentityDocuments() {
        let row = DocumentsHubRow(id: "unknown", category: .other, filename: "unknown.pdf", context: "Supplied context",
            contentType: "application/pdf", byteSize: 10, status: "Unavailable", historical: true, immutable: true, source: .unavailable)
        XCTAssertEqual(DocumentHierarchy.groups([row], category: .all).map(\.title), ["Other"])
        XCTAssertEqual(DocumentHierarchy.title(row), "unknown.pdf")
    }
}
