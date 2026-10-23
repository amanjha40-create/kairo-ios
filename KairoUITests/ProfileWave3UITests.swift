import XCTest

@MainActor
final class ProfileWave3UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testHomeProfileTasksOpenExactFieldsAndSaveHeadlineBackToProfile() {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", "light"]
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_PROFILE_TASKS": "1"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Home", "Career", "Passport", "More"])
        for key in ["headline", "current_role", "industry"] {
            let task = key == "headline" ? app.buttons["candidate.home.continueProfile"] : app.buttons["candidate.home.profile.\(key)"]
            app.revealContent(task)
            XCTAssertTrue(task.waitForExistence(timeout: 5)); task.tap()
            let field = app.textFields["candidate.profile.edit.\(key)"]
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            XCTAssertTrue(field.isHittable, "Target field must be revealed, not merely exist offscreen")
            if key == "headline" {
                field.tap(); field.typeText(" Updated")
                let saved = field.value as? String
                app.buttons["candidate.profile.edit.save"].tap()
                XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
                XCTAssertEqual(app.staticTexts["candidate.profile.headline"].label, saved)
                app.buttons["candidate.profile.edit"].tap()
                app.revealContent(field)
                XCTAssertEqual(field.value as? String, saved)
            }
            app.buttons["candidate.profile.edit.cancel"].tap()
            app.navigationBars["Profile"].buttons["Done"].tap()
            XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
        }
        keepScreenshot("Profile task routing returns Home", app)
    }

    func testProfileInformationIsDistinctFromActionAndBioIsMultiline() {
        let app = launchProfile()
        let choose = app.buttons["candidate.profile.avatar.choose"]
        XCTAssertEqual(choose.label, "Add photo")
        XCTAssertGreaterThanOrEqual(choose.frame.height, 44)
        XCTAssertLessThan(choose.frame.width, app.frame.width * 0.8)
        let info = app.descendants(matching: .any)["candidate.profile.identity.info"].firstMatch
        app.revealContent(info)
        XCTAssertTrue(info.exists)
        XCTAssertFalse(app.buttons["disclosure.About identity"].exists)
        let edit = app.buttons["candidate.profile.information.edit"]
        app.revealContent(edit); XCTAssertTrue(edit.isHittable); edit.tap()
        let bio = app.textViews["candidate.profile.edit.bio"]
        app.revealContent(bio)
        XCTAssertTrue(bio.exists)
        bio.tap(); bio.typeText("Synthetic first paragraph.\nSynthetic second paragraph.\n")
        let saved = bio.value as? String
        app.buttons["candidate.profile.edit.save"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
        app.buttons["candidate.profile.edit"].tap()
        app.revealContent(bio)
        XCTAssertEqual(bio.value as? String, saved)
        app.buttons["candidate.profile.edit.cancel"].tap()
        keepScreenshot("Profile information and edit hierarchy - Light", app)
    }

    func testDOBDigitsAutoFormatAndFixtureSaveReopensFormatted() {
        let app = launchProfile()
        app.buttons["candidate.profile.edit"].tap()
        let field = app.textFields["candidate.profile.edit.date_of_birth"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        app.revealContent(field)
        field.tap(); field.typeText("14091994")
        XCTAssertEqual(field.value as? String, "14-09-1994")
        app.buttons["candidate.profile.edit.save"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
        app.buttons["candidate.profile.edit"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "14-09-1994")
        app.buttons["candidate.profile.edit.cancel"].tap()
    }

    func testMoreProfileShowsCertifiedHierarchyAndSafeIdentityContext() {
        let app = launchProfile()

        XCTAssertTrue(app.descendants(matching: .any)["candidate.profile.hero"].firstMatch.exists)
        let information = app.buttons["candidate.profile.information.edit"]
        app.revealContent(information)
        XCTAssertTrue(information.exists)
        reveal(app.buttons["candidate.profile.skills.manage"], in: app)
        XCTAssertTrue(app.staticTexts["Skills"].exists)
        expand("Languages", in: app)
        reveal(app.buttons["candidate.profile.languages.manage"], in: app)
        XCTAssertTrue(app.staticTexts["Languages"].exists)
        expand("Professional links", in: app)
        reveal(app.buttons["candidate.profile.links.manage"], in: app)
        XCTAssertTrue(app.staticTexts["Professional links"].exists)

        let identity = app.descendants(matching: .any)["candidate.identity.provenance"].firstMatch
        app.revealContent(identity, fullyVisible: true, missingTargetIsAbove: true)
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

        replaceText(in: url, with: "example.com/professional", app: app)
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

    private func replaceText(in field: XCUIElement, with text: String, app: XCUIApplication) {
        field.tap()
        // Command-A synthesizes a hardware keyboard on iOS and can open the
        // Keyboard Detected system setup sheet. Use the native touch edit menu.
        field.press(forDuration: 1)
        let selectAll = app.buttons["Select All"].exists
            ? app.buttons["Select All"] : app.menuItems["Select All"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
        selectAll.tap()
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
        app.revealContent(element, fullyVisible: true)
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
