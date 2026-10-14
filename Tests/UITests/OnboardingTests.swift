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
    #if os(iOS)
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
