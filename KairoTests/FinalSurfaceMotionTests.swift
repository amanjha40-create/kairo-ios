import XCTest
@testable import Kairo

@MainActor final class FinalSurfaceMotionTests: XCTestCase {
    func testScoreInterpolationIsBoundedFiniteAndEndsAtAuthoritativeValue() {
        XCTAssertEqual(PremiumMotion.score(from: 0, to: 73, elapsed: 0), 0)
        XCTAssertEqual(PremiumMotion.score(from: 0, to: 73, elapsed: 0.72), 73)
        XCTAssertEqual(PremiumMotion.score(from: 0, to: 73, elapsed: 10), 73)
        for tick in 0...72 {
            let value = PremiumMotion.score(from: 0, to: 73, elapsed: Double(tick) / 100)
            XCTAssertTrue((0...73).contains(value))
        }
        XCTAssertEqual(PremiumMotion.score(from: 73, to: 19, elapsed: 0.72), 19)
    }
    func testHistoricalAndRefetchedCompletionDoNotCelebrate() {
        XCTAssertFalse(PremiumMotion.shouldCelebrate(previous: nil, current: 2, target: 2))
        XCTAssertFalse(PremiumMotion.shouldCelebrate(previous: 2, current: 2, target: 2))
        XCTAssertFalse(PremiumMotion.shouldCelebrate(previous: 2, current: 1, target: 2))
        XCTAssertTrue(PremiumMotion.shouldCelebrate(previous: 1, current: 2, target: 2))
        XCTAssertTrue(PremiumMotion.shouldCelebrate(previous: 0, current: 2, target: 2))
    }
    func testScoreScreenMemorySurvivesSameEntryRefetchButReplaysMeaningfulTabEntry() {
        var memory = PremiumScoreMemory()
        XCTAssertEqual(memory.begin(entry: 0, value: 73, animate: true), 0)
        XCTAssertNil(memory.begin(entry: 0, value: 73, animate: true))
        XCTAssertEqual(memory.begin(entry: 1, value: 73, animate: true), 0)
        XCTAssertEqual(memory.begin(entry: 1, value: 80, animate: true), 73)
        XCTAssertNil(memory.begin(entry: 1, value: 80, animate: true))
    }
    func testReducedOrBackgroundScoreSettlesWithoutQueuedReplayAndAccountMemoryResets() {
        var memory = PremiumScoreMemory()
        XCTAssertNil(memory.begin(entry: 1, value: 73, animate: false))
        XCTAssertNil(memory.begin(entry: 1, value: 73, animate: true))
        memory = .init()
        XCTAssertEqual(memory.begin(entry: 1, value: 73, animate: true), 0)
    }
    func testSharedFieldAllowlistNeverReturnsUnknownWireKeys() {
        XCTAssertEqual(VerificationSharedLabels.labels(["role", "employment.start_date", "employment.end_date", "private_internal_key"]), ["Role", "Employment dates"])
        XCTAssertEqual(VerificationSharedLabels.labels(["unknown"]), [])
        XCTAssertEqual(VerificationSharedLabels.evidenceLabel("unknown_secret_scope"), "Verification evidence")
        XCTAssertEqual(VerificationSharedLabels.evidenceLabel("offer_letter"), "Offer letter")
    }
    func testCanonicalIndianStatesAndExistingCityAreNotNormalizedOnRead() {
        XCTAssertEqual(CandidateLocationCatalogue.indiaStates.count, 36)
        XCTAssertEqual(Set(CandidateLocationCatalogue.indiaStates).count, 36)
        XCTAssertTrue(CandidateLocationCatalogue.indiaStates.contains("Karnataka"))
        XCTAssertTrue(CandidateLocationCatalogue.isIndia("India"))
        XCTAssertTrue(CandidateLocationCatalogue.isIndia("IN"))
        XCTAssertFalse(CandidateLocationCatalogue.isIndia("US"))
        let address = ClaimedPermanentAddress(addressLine1: "10 Synthetic QA Road", city: "Bengaluru", state: "Karnataka", postalCode: "560001")
        XCTAssertTrue(address.isValid)
        XCTAssertEqual(address.city, "Bengaluru")
    }
    func testPreviewRequiresStagingAndExplicitSyntheticLaunch() {
        let env = ["KAIRO_UI_TEST_FINAL_MIRROR": "1"]
        let args = [UITestLaunchConfiguration.enabledArgument]
        let staging = AppConfiguration(buildConfiguration: .staging, environment: .staging, isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .staging), keychainService: "synthetic")
        XCTAssertTrue(FinalMirrorQA.isEnabled(configuration: staging, arguments: args, environment: env))
        XCTAssertFalse(FinalMirrorQA.isEnabled(configuration: staging, arguments: [], environment: env))
        XCTAssertFalse(FinalMirrorQA.isEnabled(configuration: staging, arguments: args, environment: [:]))
        let production = AppConfiguration(buildConfiguration: .production, environment: .production, isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .production), keychainService: "synthetic")
        XCTAssertFalse(FinalMirrorQA.isEnabled(configuration: production, arguments: args, environment: env))
    }
}
