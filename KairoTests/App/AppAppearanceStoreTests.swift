import SwiftUI
import XCTest
@testable import Kairo

@MainActor
final class AppAppearanceStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppAppearanceStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_systemIsTheDefaultAndFollowsTheDevice() {
        let store = AppAppearanceStore(defaults: defaults)

        XCTAssertEqual(store.selection, .system)
        XCTAssertNil(store.preferredColorScheme)
    }

    func test_lightAndDarkApplyImmediately() {
        let store = AppAppearanceStore(defaults: defaults)

        store.select(.light)
        XCTAssertEqual(store.selection, .light)
        XCTAssertEqual(store.preferredColorScheme, .light)

        store.select(.dark)
        XCTAssertEqual(store.selection, .dark)
        XCTAssertEqual(store.preferredColorScheme, .dark)
    }

    func test_selectionPersistsAcrossStoreRecreation() {
        let firstStore = AppAppearanceStore(defaults: defaults)
        firstStore.select(.dark)

        let restoredStore = AppAppearanceStore(defaults: defaults)

        XCTAssertEqual(restoredStore.selection, .dark)
        XCTAssertEqual(restoredStore.preferredColorScheme, .dark)
    }
}
