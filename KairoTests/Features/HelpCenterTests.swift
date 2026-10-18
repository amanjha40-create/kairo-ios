import Foundation
import XCTest
@testable import Kairo

final class HelpCenterTests: XCTestCase {
    func testContentHasExactCertifiedCountsAndSectionShape() {
        XCTAssertEqual(HelpCenterContent.guides.count, 4)
        XCTAssertEqual(HelpCenterContent.guides.map(\.sections.count), [6, 7, 6, 5])
        XCTAssertEqual(HelpCenterContent.faqs.count, 16)
    }

    func testContentIdentifiersAreStableAndUniqueAcrossKinds() {
        let guideIDs = HelpCenterContent.guides.map(\.id)
        let faqIDs = HelpCenterContent.faqs.map(\.id)
        XCTAssertEqual(Set(guideIDs).count, guideIDs.count)
        XCTAssertEqual(Set(faqIDs).count, faqIDs.count)
        XCTAssertTrue(Set(guideIDs).isDisjoint(with: Set(faqIDs)))
        XCTAssertEqual(guideIDs, ["getting-started", "verifying-roles", "trust-score", "sharing-passport"])
    }

    func testEmptyAndWhitespaceSearchReturnAllContentInSourceOrder() {
        for query in ["", "   ", "\n\t"] {
            let results = HelpCenterSearch.search(query)
            XCTAssertEqual(results.count, 20)
            XCTAssertEqual(results.prefix(4).map(\.kind), Array(repeating: .guide, count: 4))
            XCTAssertEqual(results.dropFirst(4).map(\.kind), Array(repeating: .faq, count: 16))
        }
    }

    func testExactGuideTitleSearchRanksGuideFirst() throws {
        let first = try XCTUnwrap(HelpCenterSearch.search("Getting started").first)
        XCTAssertEqual(first.id, "guide.getting-started")
        XCTAssertEqual(first.rank, 0)
    }

    func testExactFAQQuestionSearchRanksFAQFirst() throws {
        let first = try XCTUnwrap(HelpCenterSearch.search("What is the Trust Score?").first)
        XCTAssertEqual(first.id, "faq.score")
        XCTAssertEqual(first.rank, 0)
    }

    func testGuideBodyAndSectionHeadingAreSearchable() {
        XCTAssertEqual(HelpCenterSearch.search("parsing").map(\.id), ["guide.getting-started"])
        XCTAssertTrue(HelpCenterSearch.search("Review imported information").map(\.id).contains("guide.getting-started"))
    }

    func testFAQAnswerIsSearchable() {
        XCTAssertTrue(HelpCenterSearch.search("screenshots someone saved").map(\.id).contains("faq.stop-sharing"))
        XCTAssertTrue(HelpCenterSearch.search("privacy controls").map(\.id).contains("faq.privacy"))
    }

    func testSearchNormalizesCaseWhitespaceAndPunctuation() {
        let expected = HelpCenterSearch.search("trust score").map(\.id)
        XCTAssertEqual(HelpCenterSearch.search("  TRUST   SCORE  ").map(\.id), expected)
        XCTAssertEqual(HelpCenterSearch.search("trust\nscore").map(\.id), expected)
        XCTAssertEqual(HelpCenterSearch.search("trust—score").map(\.id), expected)
    }

    func testPrefixSearchMatchesLongerWords() {
        XCTAssertTrue(HelpCenterSearch.search("verific").map(\.id).contains("guide.verifying-roles"))
        XCTAssertTrue(HelpCenterSearch.search("trus scor").map(\.id).contains("guide.trust-score"))
    }

    func testBoundedTypoSearchHandlesSubstitutionDeletionInsertionAndTransposition() {
        for query in ["trust socre", "trust scorx", "trust scoore", "verifiction"] {
            XCTAssertTrue(
                HelpCenterSearch.search(query).map(\.id).contains("guide.trust-score"),
                "Expected a relevant Trust Score result for \(query)"
            )
        }
    }

    func testTypoToleranceStaysBoundedForShortAndUnrelatedQueries() {
        XCTAssertTrue(HelpCenterSearch.search("scx").isEmpty)
        XCTAssertTrue(HelpCenterSearch.search("zzzzzzzz").isEmpty)
        XCTAssertTrue(HelpCenterSearch.search("verification banana").isEmpty)
    }

    func testSearchDoesNotReturnDuplicateContent() {
        for query in ["score", "verification", "share", "document", "support"] {
            let ids = HelpCenterSearch.search(query).map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count)
        }
    }

    func testRankingIsDeterministicAndPrioritizesTitleOverBody() {
        let first = HelpCenterSearch.search("privacy")
        let second = HelpCenterSearch.search("privacy")
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.sourceOrder), first.map(\.sourceOrder).sorted())
        XCTAssertLessThanOrEqual(first.first?.rank ?? .max, first.last?.rank ?? .max)
    }

    func testPublishedContentContainsNoDeprecatedFixedClaims() {
        let text = allPublishedText
        for forbiddenPattern in [#"\d+%"#, #"24\s*hours"#, #"48\s*hours"#, #"AES-256"#, #"10\s*MB"#] {
            XCTAssertNil(
                text.range(of: forbiddenPattern, options: [.regularExpression, .caseInsensitive]),
                "Found stale Help claim matching \(forbiddenPattern)"
            )
        }
        XCTAssertTrue(text.contains("there is no guaranteed completion time"))
        XCTAssertTrue(text.contains("no action guarantees a fixed number of points"))
        XCTAssertTrue(text.contains("not a government identity document"))
    }

    func testCanonicalProductTerminologyAndSupportDestinationArePreserved() {
        let text = allPublishedText
        for term in ["KairoID", "Trust Score", "Trust Passport", "Career", "Verify", "Document Packs", "Verified", "Needs your attention"] {
            XCTAssertTrue(text.contains(term), "Missing canonical term \(term)")
        }
        XCTAssertEqual(ProductBrand.supportEmailAddress, "contact@kairoid.com")
        XCTAssertTrue(text.contains("Email support"))
        XCTAssertTrue(text.contains("Do not include passwords, one-time codes or private share links"))
        XCTAssertTrue(text.contains("Verification activity"))
        XCTAssertFalse(text.contains("in Verify"))
    }

    private var allPublishedText: String {
        let guideText = HelpCenterContent.guides.flatMap { guide in
            [guide.title, guide.subtitle] + guide.sections.flatMap { [$0.title, $0.body] }
        }
        let faqText = HelpCenterContent.faqs.flatMap { [$0.question, $0.answer] }
        return (guideText + faqText).joined(separator: " ")
    }
}
