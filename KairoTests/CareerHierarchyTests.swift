import XCTest
import SwiftUI
@testable import Kairo

@MainActor
final class CareerHierarchyTests: XCTestCase {
    func testHierarchyFixtureCannotActivateOutsideExplicitUITestRoute() {
        let environment = ["KAIRO_UI_TEST_CAREER_HIERARCHY": "1", "KAIRO_UI_TEST_CAREER_STATE": "populated", "KAIRO_UI_TEST_ROUTE": "demoHome"]
        XCTAssertFalse(UITestCareerConfiguration.current(arguments: [], environment: environment).showsHierarchyFixture)
        XCTAssertTrue(UITestCareerConfiguration.current(arguments: ["-KAIRO_UI_TESTING"], environment: environment).showsHierarchyFixture)
        var wrongRoute = environment
        wrongRoute["KAIRO_UI_TEST_ROUTE"] = "welcome"
        XCTAssertFalse(UITestCareerConfiguration.current(arguments: ["-KAIRO_UI_TESTING"], environment: wrongRoute).showsHierarchyFixture)
    }

    func testEmploymentPreservesEligibilityAndCanonicalDocumentIdentity() {
        let item = employment(status: .verified, editable: false)
        let detail = CareerRecordDetailPresentation.employment(item, edit: {}, delete: {}, verify: {})
        XCTAssertEqual(detail.id, item.routeID)
        XCTAssertEqual(detail.metadata.map(\.title), ["Employment dates", "Employment type", "Location"])
        XCTAssertEqual(detail.status, .verified)
        XCTAssertNil(detail.edit); XCTAssertNil(detail.delete); XCTAssertNil(detail.verify)
        XCTAssertTrue(detail.showsVerification)
        XCTAssertEqual(detail.documents, .employment(id: "employment", title: "Engineer at Employer", canUpload: false, canDelete: false))
    }

    func testEligibleEmploymentCallbacksKeepTheirSingleCanonicalAction() {
        var edits = 0, deletes = 0, verifications = 0
        let detail = CareerRecordDetailPresentation.employment(employment(status: .notVerified, editable: true),
            edit: { edits += 1 }, delete: { deletes += 1 }, verify: { verifications += 1 })
        detail.edit?(); detail.delete?(); detail.verify?()
        XCTAssertEqual(edits, 1); XCTAssertEqual(deletes, 1); XCTAssertEqual(verifications, 1)
    }

    func testEducationSplitsDatesAndFieldFromSupportingMetadataWithoutNewEvidenceContract() {
        let item = CareerEducationItem(routeID: "education", institution: "University", degree: "BSc", dateRange: "2018 – 2022", verificationStatus: .notVerified,
            detailMetadata: [.init(title: "Field of study", value: "Computing"), .init(title: "Grade", value: "A")])
        let detail = CareerRecordDetailPresentation.education(item, edit: {}, delete: {}, verify: {})
        XCTAssertEqual(detail.metadata.map(\.title), ["Dates", "Field of study"])
        XCTAssertEqual(detail.metadata.first?.value, "2018 – 2022")
        XCTAssertEqual(detail.supportingMetadata.map(\.title), ["Grade"])
        XCTAssertEqual(detail.documents, .education(id: "education", title: "University"))
        XCTAssertTrue(detail.links.isEmpty)
        XCTAssertNotNil(detail.verify)
    }

    func testCertificationDocumentEntrySurvivesRemovalAndNeverImpliesVerification() {
        for attached in [true, false] {
            let item = CareerCertificationItem(routeID: "certification", title: "Certificate", issuer: "Issuer", issueDate: "2025", verificationStatus: .notVerified, hasDocument: attached,
                detailMetadata: [.init(title: "Expiry", value: "Does not expire"), .init(title: "Credential ID", value: "QA-1")])
            let detail = CareerRecordDetailPresentation.certification(item, edit: {}, delete: {})
            XCTAssertEqual(detail.attachmentPresent, attached)
            XCTAssertEqual(detail.documents, .certification(id: "certification", title: "Certificate"))
            XCTAssertEqual(detail.status?.badgeStyle.title, "Candidate-provided")
            XCTAssertEqual(detail.metadata.map(\.title), ["Issue date", "Expiry", "Credential ID"])
            XCTAssertFalse(detail.showsVerification); XCTAssertNil(detail.verify)
            XCTAssertNotNil(detail.edit); XCTAssertNotNil(detail.delete)
        }
    }

    func testProjectOrderingUsesRealSuppliedLinksAndDoesNotCreateVerification() {
        let detail = CareerRecordDetailPresentation.project(project(), edit: {}, delete: {})
        XCTAssertEqual(detail.metadata.map(\.title), ["Organization", "Description", "Dates"])
        XCTAssertEqual(detail.links.map(\.title), ["Project URL", "Repository URL"])
        XCTAssertEqual(detail.links.map(\.url), [URL(string: "https://example.invalid/project")!, URL(string: "https://example.invalid/repository")!])
        XCTAssertEqual(detail.status, .notVerified)
        XCTAssertFalse(detail.showsVerification); XCTAssertNil(detail.verify); XCTAssertNil(detail.documents)
        XCTAssertNotNil(detail.edit); XCTAssertNotNil(detail.delete)
    }

    func testLegacyPortfolioRemainsReadOnlyCompatibilityWithOrigin() {
        var item = project()
        item.legacyPortfolioID = "legacy-id"
        item.detailMetadata.append(.init(title: "Origin", value: "Legacy Portfolio; Project migration pending"))
        let detail = CareerRecordDetailPresentation.project(item, edit: {}, delete: {})
        XCTAssertEqual(detail.documents, .legacyPortfolio(id: "legacy-id", title: "Project"))
        XCTAssertEqual(detail.supportingMetadata.first?.title, "Origin")
        XCTAssertNil(detail.edit); XCTAssertNil(detail.delete); XCTAssertNil(detail.verify)
        XCTAssertFalse(detail.showsVerification)
    }

    func testMissingProjectLinksAreNotFabricatedFromDisplayLabel() {
        let item = CareerProjectItem(routeID: "project", title: "Project", role: "Contributor", duration: "", portfolioLinkTitle: "Portfolio link", verificationStatus: nil)
        let detail = CareerRecordDetailPresentation.project(item, edit: nil, delete: nil)
        XCTAssertTrue(detail.links.isEmpty); XCTAssertTrue(detail.metadata.isEmpty)
    }

    func testExternalLinksRejectNonWebSchemesAndEmbeddedCredentials() {
        for raw in ["file:///private/document.pdf", "javascript:alert(1)", "https://user:secret@example.invalid", "/relative", "mailto:test@example.invalid"] {
            XCTAssertNil(CareerRecordLink(title: "Link", url: URL(string: raw)))
        }
        XCTAssertNotNil(CareerRecordLink(title: "Link", url: URL(string: "https://example.invalid/project")))
    }

    func testStatusMappingRemainsCanonicalIncludingApprovedAndUnknown() {
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "approved"), .verified)
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "self_declared").badgeStyle.title, "Candidate-provided")
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "future_backend_state"), .precise("future_backend_state"))
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "rejected").badgeStyle.title, "Rejected")
    }

    func testCompactRecordWrapsLongContentAtAccessibilitySizesInBothAppearances() {
        for scheme in [ColorScheme.light, .dark] {
            let row = CareerCompactRecordRow(title: "Senior interdisciplinary infrastructure and operations programme specialist",
                subtitle: "International Institute for Applied Engineering and Research in Distributed Systems",
                metadata: ["January 2020 – Present", "A long location with regional and country metadata"], status: .pendingVerification, attachment: "Attachment added", open: {})
                .environment(\.colorScheme, scheme)
            let normal = size(row)
            let large = size(row.environment(\.dynamicTypeSize, .accessibility5))
            XCTAssertGreaterThanOrEqual(normal.height, 44)
            XCTAssertGreaterThan(large.height, normal.height)
            XCTAssertLessThanOrEqual(large.width, 321)
        }
    }

    func testSectionHeadingKeepsCountAndAddWithinNarrowAccessibilityLayout() {
        let header = CareerSectionHeader(title: "Certifications", count: 12, identifier: "section", addTitle: "Add Certification", addIdentifier: "add", add: {})
        let measured = size(header.environment(\.dynamicTypeSize, .accessibility5))
        XCTAssertGreaterThanOrEqual(measured.height, 44)
        XCTAssertLessThanOrEqual(measured.width, 321)
    }

    private func size<V: View>(_ view: V) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 320, height: 20_000))
    }

    private func employment(status: CareerVerificationStatus, editable: Bool) -> CareerEmploymentItem {
        .init(routeID: "employment", company: "Employer", role: "Engineer", dateRange: "2020 – Present", verificationStatus: status, allowsEdit: editable, allowsDelete: editable,
              detailMetadata: [.init(title: "Employment type", value: "Full time"), .init(title: "Location", value: "India")])
    }

    private func project() -> CareerProjectItem {
        .init(routeID: "project", title: "Project", role: "Contributor", duration: "2024 – Present", portfolioLinkTitle: "example.invalid", verificationStatus: nil,
              detailMetadata: [.init(title: "Organization", value: "Synthetic client"), .init(title: "Description", value: "A supplied description")],
              projectURL: URL(string: "https://example.invalid/project"), repositoryURL: URL(string: "https://example.invalid/repository"))
    }
}
