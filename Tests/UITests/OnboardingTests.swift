import XCTest

final class OnboardingTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language == "da" ? "da_DK" : "en_US"]
        app.launch(); return app
    }
    func testEmptyOnboardingAndCredentialGuards() {
        let app = launch()
        XCTAssertTrue(app.textFields["server.url"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.textFields["auth.username"].exists)
        XCTAssertTrue(app.secureTextFields["auth.password"].exists)
        XCTAssertFalse(app.buttons["auth.signin"].isEnabled)
        XCTAssertFalse(app.buttons["auth.quick"].isEnabled)
    }
    func testDanishAuthenticationLabel() {
        let app = launch(language: "da")
        XCTAssertTrue(app.buttons["auth.signin"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["auth.signin"].label, "Log ind")
    }
    func testRealVLCMKVPlaybackSeekAndEmbeddedTracks() {
        let app = XCUIApplication()
        app.launchArguments = ["--vlc-fixture", "-AppleLanguages", "(en)"]
        app.launch()
        let status = app.staticTexts["fixture.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["fixture.start"].exists)
        #if os(iOS)
        app.buttons["fixture.start"].tap()
        #else
        XCUIRemote.shared.press(.select)
        #endif
        let playing = NSPredicate(format: "label == %@", "playing")
        expectation(for: playing, evaluatedWith: status)
        waitForExpectations(timeout: 20)
        let tracks = app.staticTexts["fixture.tracks"]
        let tracksReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "1 audio / 1 subtitles"), object: tracks)
        XCTAssertEqual(XCTWaiter.wait(for: [tracksReady], timeout: 5), .completed, "Actual fixture tracks: \(tracks.label)")
        #if os(iOS)
        app.buttons["fixture.hideSubtitle"].tap()
        expectation(for: NSPredicate(format: "label == %@", "-1"), evaluatedWith: app.staticTexts["fixture.subtitle"])
        waitForExpectations(timeout: 5)
        app.buttons["fixture.selectSubtitle"].tap()
        expectation(for: NSPredicate(format: "label == %@", "0"), evaluatedWith: app.staticTexts["fixture.subtitle"])
        waitForExpectations(timeout: 5)
        app.buttons["fixture.seek"].tap()
        expectation(for: NSPredicate(format: "label MATCHES %@", "^(1[6-9]|2[0-9])$"), evaluatedWith: app.staticTexts["fixture.position"])
        waitForExpectations(timeout: 5)
        #endif
        // Real libVLC callbacks drive EOF; no fake timer/metadata marks completion.
        expectation(for: NSPredicate(format: "label == %@", "ended"), evaluatedWith: status)
        waitForExpectations(timeout: 35)
    }
    #if os(iOS)
    func testVideoConversionRequiresExplicitAcceptAndCancelConstructsNothing() {
        let app = XCUIApplication()
        app.launchArguments = ["--consent-fixture", "-AppleLanguages", "(en)"]
        app.launch()
        let request = app.buttons["consent.request"]
        XCTAssertTrue(request.waitForExistence(timeout: 15))
        request.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.firstMatch.staticTexts.matching(NSPredicate(format: "label CONTAINS '1920' AND label CONTAINS '1080p' AND label CONTAINS '4K' AND label CONTAINS '8 Mb/s'")).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["consent.count"].label, "Encoding URLs: 0")
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["consent.result"].label, "declined")
        XCTAssertEqual(app.staticTexts["consent.count"].label, "Encoding URLs: 0")
        request.tap()
        app.alerts.buttons["Play with video conversion"].tap()
        XCTAssertEqual(app.staticTexts["consent.result"].label, "accepted")
        XCTAssertEqual(app.staticTexts["consent.count"].label, "Encoding URLs: 1")
        // Approval is not a persisted preference: the next attempt prompts again.
        request.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["consent.count"].label, "Encoding URLs: 1")
    }
    func testInsecureURLShowsErrorWithoutNetworkAuthentication() {
        let app = launch()
        let server = app.textFields["server.url"]
        XCTAssertTrue(server.waitForExistence(timeout: 15))
        server.tap(); server.typeText("http://example.invalid")
        let username = app.textFields["auth.username"]
        username.tap(); username.typeText("Invented")
        // Dismiss software keyboard to reach sign-in if needed.
        app.swipeUp()
        let signin = app.buttons["auth.signin"]
        XCTAssertTrue(signin.isEnabled); signin.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.firstMatch.staticTexts["Enter a valid HTTPS server URL without credentials or query parameters."].exists)
    }
    #endif
}
