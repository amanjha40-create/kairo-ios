import XCTest

/// The native password-save sheet is hosted outside KairoID. Register its
/// owner before submitting credentials; app idleness does not cover this host.
@MainActor
final class PasswordSavePromptSupport {
    enum Outcome: String {
        case absent
        case dismissed
        case failed
    }

    private let owner: XCUIApplication

    init() {
        owner = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")
        // Establish XCTest process tracking even before the service starts.
        // Do not launch or activate SafariViewService ourselves.
        _ = owner.state
    }

    @discardableResult
    func dismissIfPresent(in test: XCTestCase, file: StaticString = #filePath, line: UInt = #line) -> Outcome {
        let sheet = owner.sheets["Save Password?"]
        let appears = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            owner.state != .notRunning && sheet.exists
        }, object: nil)
        guard XCTWaiter.wait(for: [appears], timeout: 5) == .completed else {
            record("absent; bounded presence wait completed; taps=0", in: test)
            return .absent
        }

        let notNow = sheet.buttons["Not Now"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            owner.state == .runningForeground && sheet.exists &&
                sheet.staticTexts["Save Password?"].exists &&
                sheet.buttons["Save"].exists && notNow.exists && notNow.isHittable
        }, object: nil)
        guard XCTWaiter.wait(for: [ready], timeout: 5) == .completed else {
            record("present but not ready; taps=0\n" + owner.debugDescription, in: test)
            XCTFail("Known native password-save sheet did not become ready", file: file, line: line)
            return .failed
        }

        record("ready; owner=com.apple.SafariViewService\n" + sheet.debugDescription, in: test)
        // Exactly one element-based tap. No interruption monitor, coordinate
        // fallback, or retry that could dismiss a different system prompt.
        notNow.tap()
        guard sheet.waitForNonExistence(timeout: 5) else {
            record("dismissal failed; taps=1\n" + owner.debugDescription, in: test)
            XCTFail("Native password-save sheet remained after Not Now", file: file, line: line)
            return .failed
        }
        record("dismissed; exact sheet absent; taps=1", in: test)
        return .dismissed
    }

    private func record(_ message: String, in test: XCTestCase) {
        let evidence = XCTAttachment(string: message)
        evidence.name = "Native Save Password synchronization"
        evidence.lifetime = .keepAlways
        test.add(evidence)
    }
}
