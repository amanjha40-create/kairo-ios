import XCTest

@MainActor
extension XCTestCase {
    /// hasSucceeded is not final during teardown. Inspect recorded failures,
    /// and never relaunch a deliberately terminated app just to collect evidence.
    func captureFailureEvidenceIfRunning(_ app: XCUIApplication, name: String) {
        guard let testRun, testRun.totalFailureCount > 0 else { return }
        guard app.state == .runningForeground, app.exists else {
            let state = XCTAttachment(string: "Failure evidence: app is not screenshot-capable (state: \(app.state.rawValue)).")
            state.name = "\(name) app state"
            state.lifetime = .keepAlways
            add(state)
            return
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(name) screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name) hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
