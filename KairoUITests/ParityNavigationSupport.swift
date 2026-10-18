import XCTest

extension XCUIApplication {
    @MainActor func openCareerVerification(file: StaticString = #filePath, line: UInt = #line) {
        if otherElements["candidate.verify.screen"].exists { return }
        let career = tabBars.buttons["Career"]
        XCTAssertTrue(career.waitForExistence(timeout: 10), file: file, line: line)
        career.tap()
        let activity = buttons["career.verification.activity"]
        XCTAssertTrue(activity.waitForExistence(timeout: 10), file: file, line: line)
        for _ in 0..<4 where !activity.isHittable { swipeDown() }
        XCTAssertTrue(activity.isHittable, file: file, line: line)
        activity.tap()
    }
}
