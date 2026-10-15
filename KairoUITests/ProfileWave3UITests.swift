import XCTest

@MainActor
final class ProfileWave3UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testMoreProfileShowsCertifiedHierarchyAndSafeIdentityContext() {
        let app = launchProfile()

        XCTAssertTrue(app.descendants(matching: .any)["candidate.profile.hero"].firstMatch.exists)
        expand("Personal & professional information", in: app)
        XCTAssertTrue(app.staticTexts["Professional information"].exists)
        reveal(app.buttons["candidate.profile.skills.manage"], in: app)
        XCTAssertTrue(app.staticTexts["Skills"].exists)
        expand("Languages", in: app)
        reveal(app.buttons["candidate.profile.languages.manage"], in: app)
        XCTAssertTrue(app.staticTexts["Languages"].exists)
        expand("Professional links", in: app)
        reveal(app.buttons["candidate.profile.links.manage"], in: app)
        XCTAssertTrue(app.staticTexts["Professional links"].exists)

        let identity = app.descendants(matching: .any)["candidate.identity.provenance"].firstMatch
        reveal(identity, in: app)
        XCTAssertTrue(identity.staticTexts["Identity"].exists)
        XCTAssertTrue(
            identity.staticTexts["Verified"].exists ||
            identity.staticTexts["Needs review"].exists ||
            identity.staticTexts["Not currently verified"].exists
        )
        XCTAssertFalse(identity.label.localizedCaseInsensitiveContains("provider-private-uri"))
        XCTAssertFalse(identity.label.range(of: "[A-Z]{5}[0-9]{4}[A-Z]", options: .regularExpression) != nil)
        keepScreenshot("Wave 3 - Profile and identity - Light", app)
    }

    func testProfileEditRequiresExplicitDiscardForDirtyChanges() {
        let app = launchProfile()
        app.buttons["candidate.profile.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 10))

        let name = app.textFields["candidate.profile.edit.full_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText(" Updated")
        app.buttons["candidate.profile.edit.cancel"].tap()

        let discard = app.buttons["Discard changes"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10))
        keepScreenshot("Wave 3 - Profile edit - Light", app)
        discard.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
    }

    func testStructuredSkillsSearchAliasCancelAndFixtureSave() {
        let app = launchProfile()
        openManager("candidate.profile.skills.manage", title: "Skills", in: app)
        app.buttons["candidate.profile.skills.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Skills"].waitForExistence(timeout: 10))

        let search = app.searchFields["Search Skills"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap(); search.typeText("ms excel")
        let existing = app.buttons["Microsoft Excel"]
        XCTAssertTrue(existing.waitForExistence(timeout: 10))
        XCTAssertEqual(existing.value as? String, "Already added")
        keepScreenshot("Wave 3 - Skill alias search - Light", app)
        closeSearch(in: app)
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()

        app.buttons["candidate.profile.skills.add"].tap()
        let secondSearch = app.searchFields["Search Skills"]
        secondSearch.tap(); secondSearch.typeText("aws")
        let result = app.buttons["Amazon Web Services"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.tap()
        XCTAssertEqual(result.value as? String, "Selected")
        closeSearch(in: app)
        app.buttons["candidate.profile.skills.save"].tap()
        XCTAssertTrue(app.staticTexts["Amazon Web Services"].waitForExistence(timeout: 10))
    }

    func testStructuredLanguagesSupportProficiencyCancelAndFixtureSave() {
        let app = launchProfile()
        openManager("candidate.profile.languages.manage", title: "Languages", in: app)
        app.buttons["candidate.profile.languages.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Language"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()

        app.buttons["candidate.profile.languages.add"].tap()
        let search = app.searchFields["Search Languages"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap(); search.typeText("Marathi")
        let language = app.buttons["Marathi"]
        XCTAssertTrue(language.waitForExistence(timeout: 10))
        let keyboardSearch = app.keyboards.buttons["Search"]
        if keyboardSearch.exists { keyboardSearch.tap() }
        language.tap()
        let proficiency = app.buttons["candidate.profile.languages.proficiency"]
        reveal(proficiency, in: app)
        proficiency.tap()
        XCTAssertTrue(app.buttons["Native / Bilingual"].waitForExistence(timeout: 10))
        app.buttons["Native / Bilingual"].tap()
        keepScreenshot("Wave 3 - Language and proficiency - Light", app)
        let save = app.buttons["candidate.profile.languages.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["Edit Marathi"].waitForExistence(timeout: 10))
    }

    func testProfessionalLinkValidatesAndSavesOnlySafeFixtureURL() {
        let app = launchProfile()
        openManager("candidate.profile.links.manage", title: "Professional links", in: app)
        app.buttons["candidate.profile.links.add"].tap()
        XCTAssertTrue(app.navigationBars["Add link"].waitForExistence(timeout: 10))

        let url = app.textFields["candidate.profile.links.url"]
        XCTAssertTrue(url.waitForExistence(timeout: 10))
        url.tap(); url.typeText("javascript:alert(1)")
        app.buttons["candidate.profile.links.save"].tap()
        XCTAssertTrue(app.staticTexts["Enter a valid HTTP or HTTPS professional link."].exists)
        XCTAssertTrue(app.navigationBars["Add link"].exists)
        XCTAssertEqual(url.value as? String, "javascript:alert(1)")

        replaceText(in: url, with: "example.com/professional")
        keepScreenshot("Wave 3 - Professional link editor - Light", app)
        app.buttons["candidate.profile.links.save"].tap()
        XCTAssertTrue(app.staticTexts["example.com"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["javascript:alert(1)"].exists)

        app.buttons["Edit linkedin link"].tap()
        XCTAssertTrue(app.navigationBars["Edit link"].waitForExistence(timeout: 10))
        XCTAssertEqual(url.value as? String, "https://example.com/professional")
        app.buttons["Cancel"].tap()
    }

    func testDarkAccessibilityTypeKeepsAvatarAndManagersReachable() {
        let app = launchProfile(appearance: "dark", accessibilityType: true)
        let avatar = app.buttons["candidate.profile.avatar.choose"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(avatar.frame.height, 44)
        keepScreenshot("Wave 3 - Profile - Dark AXXXL", app)

        openManager("candidate.profile.skills.manage", title: "Skills", in: app)
        XCTAssertGreaterThanOrEqual(app.buttons["candidate.profile.skills.add"].frame.height, 44)
        keepScreenshot("Wave 3 - Skills - Dark AXXXL", app)
        app.navigationBars["Skills"].buttons["Done"].tap()

        openManager("candidate.profile.languages.manage", title: "Languages", in: app)
        XCTAssertGreaterThanOrEqual(app.buttons["candidate.profile.languages.add"].frame.height, 44)
        keepScreenshot("Wave 3 - Languages - Dark AXXXL", app)
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        // Public keyboard selection replaces the whole value without assuming
        // which localized items are visible in the native edit menu.
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text)
    }

    private func launchProfile(appearance: String = "light", accessibilityType: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES",
            "-kairo.appearance.preference", appearance,
            "-UIAccessibilityReduceMotionEnabled", "YES"
        ]
        if accessibilityType {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false",
            "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated"
        ]
        app.launch()
        app.tabBars.buttons["More"].tap()
        let entry = app.buttons["candidate.more.viewProfile"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
        return app
    }

    private func openManager(_ identifier: String, title: String, in app: XCUIApplication) {
        if identifier.contains("languages") { expand("Languages", in: app) }
        if identifier.contains("links") { expand("Professional links", in: app) }
        let button = app.buttons[identifier]
        reveal(button, in: app)
        button.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
    }

    private func expand(_ title: String, in app: XCUIApplication) {
        let disclosure = app.buttons["disclosure.\(title)"]
        reveal(disclosure, in: app)
        if disclosure.value as? String == "Collapsed" { disclosure.tap() }
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<40 {
            if element.exists, element.isHittable,
               element.frame.minY > 75, element.frame.maxY < app.frame.height - 65 { return }
            let isAbove = element.exists && element.frame.minY <= 75
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.28 : 0.72))
                .press(forDuration: 0.04, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.68 : 0.35)))
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    private func closeSearch(in app: XCUIApplication) {
        let search = app.keyboards.buttons["Search"]
        if search.exists { search.tap() }
        let fallback = app.keyboards.buttons["return"]
        if fallback.exists { fallback.tap() }
        let close = app.buttons["close"]
        if close.exists { close.tap() }
    }

    private func keepScreenshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
