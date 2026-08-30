import Foundation
import XCTest
@testable import Kairo

@MainActor
final class PublicPassportRoutingTests: XCTestCase {
    private let host = "d3kpvsn9kfajzc.cloudfront.net"
    private let token = String(repeating: "A", count: 43)

    func test_validPublicPassportURLParsesWithoutChangingCapability() throws {
        let url = try XCTUnwrap(URL(string: "https://\(host)/passport/\(token)"))

        let destination = try PublicPassportLinkParser.parse(
            url,
            allowedHosts: [host]
        ).get()

        XCTAssertEqual(destination.url, url)
    }

    func test_invalidHostIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/passport/\(token)"))

        XCTAssertEqual(
            PublicPassportLinkParser.parse(url, allowedHosts: [host]),
            .failure(.unsupportedHost)
        )
    }

    func test_malformedPathAndTokenAreRejectedSeparately() throws {
        let malformedPath = try XCTUnwrap(URL(string: "https://\(host)/public/passport/\(token)"))
        let malformedToken = try XCTUnwrap(URL(string: "https://\(host)/passport/too-short"))

        XCTAssertEqual(
            PublicPassportLinkParser.parse(malformedPath, allowedHosts: [host]),
            .failure(.malformedPath)
        )
        XCTAssertEqual(
            PublicPassportLinkParser.parse(malformedToken, allowedHosts: [host]),
            .failure(.invalidToken)
        )
    }

    func test_queryFragmentCredentialsAndPercentEncodingAreRejected() throws {
        let values = [
            "https://\(host)/passport/\(token)?source=email",
            "https://\(host)/passport/\(token)#fragment",
            "https://user@\(host)/passport/\(token)",
            "https://\(host)/passport/%41\(String(repeating: "A", count: 42))"
        ]

        for value in values {
            let url = try XCTUnwrap(URL(string: value))
            if case .success = PublicPassportLinkParser.parse(url, allowedHosts: [host]) {
                XCTFail("Expected malformed capability URL to be rejected")
            }
        }
    }

    func test_destinationAndPresentationDescriptionsRedactToken() throws {
        let url = try XCTUnwrap(URL(string: "https://\(host)/passport/\(token)"))
        let destination = try PublicPassportLinkParser.parse(url, allowedHosts: [host]).get()
        let presentation = PublicPassportPresentation(content: .handoff(destination))

        XCTAssertFalse(destination.description.contains(token))
        XCTAssertFalse(presentation.description.contains(token))
        XCTAssertTrue(destination.description.contains("<redacted>"))
        XCTAssertTrue(presentation.description.contains("<redacted>"))
    }

    func test_coldLaunchSignedOutRoutingIsSessionNeutral() throws {
        let router = AppRouter(rootDestination: .onboarding, selectedTab: .home)
        let url = try XCTUnwrap(URL(string: "https://\(host)/passport/\(token)"))

        XCTAssertTrue(router.handleIncomingURL(
            url,
            allowedPublicPassportHosts: [host],
            isDemoModeEnabled: false
        ))
        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertNotNil(router.publicPassportPresentation)
    }

    func test_warmLaunchAuthenticatedRoutingDoesNotChangeOwnerNavigation() throws {
        let router = AppRouter(rootDestination: .mainTabs, selectedTab: .career)
        let url = try XCTUnwrap(URL(string: "https://\(host)/passport/\(token)"))

        XCTAssertTrue(router.handleIncomingURL(
            url,
            allowedPublicPassportHosts: [host],
            isDemoModeEnabled: false
        ))
        XCTAssertEqual(router.rootDestination, .mainTabs)
        XCTAssertEqual(router.selectedTab, .career)
        XCTAssertNotNil(router.publicPassportPresentation)
    }

    func test_expectedHostMalformedLinkShowsPrivacyPreservingUnavailableState() throws {
        let router = AppRouter()
        let url = try XCTUnwrap(URL(string: "https://\(host)/passport/not-a-token"))

        XCTAssertTrue(router.handleIncomingURL(
            url,
            allowedPublicPassportHosts: [host],
            isDemoModeEnabled: false
        ))
        XCTAssertEqual(router.publicPassportPresentation?.content, .unavailable)
    }

    func test_unsupportedExternalURLIsNotClaimed() throws {
        let router = AppRouter()
        let url = try XCTUnwrap(URL(string: "https://example.com/passport/\(token)"))

        XCTAssertFalse(router.handleIncomingURL(
            url,
            allowedPublicPassportHosts: [host],
            isDemoModeEnabled: false
        ))
        XCTAssertNil(router.publicPassportPresentation)
    }

    func test_demoModeNeverRoutesToLivePublicPassport() throws {
        let router = AppRouter()
        let url = try XCTUnwrap(URL(string: "https://\(host)/passport/\(token)"))

        XCTAssertFalse(router.handleIncomingURL(
            url,
            allowedPublicPassportHosts: [host],
            isDemoModeEnabled: true
        ))
        XCTAssertNil(router.publicPassportPresentation)
    }

    func test_homeActivityRequestUsesCanonicalPassportDestination() {
        let router = AppRouter(rootDestination: .mainTabs, selectedTab: .home)

        router.showPassportActivity()

        XCTAssertEqual(router.rootDestination, .mainTabs)
        XCTAssertEqual(router.selectedTab, .passport)
        XCTAssertNotNil(router.passportActivityRequestID)
    }

    func test_stagingHostIsNotShippedAsProductionAssociatedDomainPolicy() {
        let production = AppConfiguration(
            buildConfiguration: .production,
            environment: .production,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .production),
            keychainService: "com.kairoid.Kairo.tests.public-passport"
        )
        let staging = AppConfiguration(
            buildConfiguration: .staging,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.public-passport-staging"
        )

        XCTAssertTrue(production.publicPassportHosts.isEmpty)
        XCTAssertEqual(staging.publicPassportHosts, [host])
    }
}
