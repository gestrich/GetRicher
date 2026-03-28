//
//  GetRicherUITests.swift
//  GetRicherUITests
//
//  Created by Bill Gestrich on 2/15/26.
//

import XCTest

final class GetRicherUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func launchApp(tab: String = "Dashboard") -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        // Wait for the app to load
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should appear")
        // Navigate to the requested tab
        let tabButton = app.tabBars.buttons[tab]
        if tabButton.waitForExistence(timeout: 5) {
            tabButton.tap()
        }
        // Give data time to sync
        sleep(3)
        return app
    }

    @MainActor
    private func captureScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func navigateToSettings(_ app: XCUIApplication) {
        // The settings button may be identified by "gear" or "Settings"
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
        settingsButton.tap()
        sleep(1)
    }

    @MainActor
    private func navigateToWeeklyPaydown(_ app: XCUIApplication) {
        let paydownTab = app.tabBars.buttons["Weekly Paydown"]
        XCTAssertTrue(paydownTab.waitForExistence(timeout: 10), "Weekly Paydown tab should exist")
        paydownTab.tap()
        sleep(2)
    }

    // MARK: - Dashboard Tab

    @MainActor
    func testDashboardScreenshot() throws {
        let app = launchApp()

        // Verify Dashboard tab is selected and basic elements exist
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.exists, "Dashboard tab should exist")

        // The dashboard shows either data or empty state — both are valid
        sleep(2)
        captureScreenshot(app, name: "Dashboard")
    }

    @MainActor
    func testDashboardHasNavigationBar() throws {
        let app = launchApp()

        // Verify settings button exists (always visible on Dashboard)
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
    }

    @MainActor
    func testDashboardTabBar() throws {
        let app = launchApp()

        // Verify both tabs exist
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.exists, "Dashboard tab should exist")

        let paydownTab = app.tabBars.buttons["Weekly Paydown"]
        XCTAssertTrue(paydownTab.exists, "Weekly Paydown tab should exist")
    }

    @MainActor
    func testDemoModeBanner() throws {
        let app = launchApp()

        // Demo mode banner should be visible
        let demoBanner = app.staticTexts["Demo Mode"]
        // May or may not exist depending on app state — capture either way
        _ = demoBanner.waitForExistence(timeout: 3)

        captureScreenshot(app, name: "DemoModeBanner")
    }

    // MARK: - Weekly Paydown Tab

    @MainActor
    func testWeeklyPaydownScreenshot() throws {
        let app = launchApp()
        navigateToWeeklyPaydown(app)

        // Select the Amex Gold account
        let accountPicker = app.buttons["Account, Select Account"]
        if accountPicker.waitForExistence(timeout: 5) {
            accountPicker.tap()
            let amexOption = app.buttons["Amex Gold"]
            if amexOption.waitForExistence(timeout: 5) {
                amexOption.tap()
            }
        }

        sleep(2)
        captureScreenshot(app, name: "WeeklyPaydown")
    }

    @MainActor
    func testWeeklyPaydownScrollDown() throws {
        let app = launchApp()
        navigateToWeeklyPaydown(app)

        // Select account and scroll to see more content
        let accountPicker = app.buttons["Account, Select Account"]
        if accountPicker.waitForExistence(timeout: 5) {
            accountPicker.tap()
            let amexOption = app.buttons["Amex Gold"]
            if amexOption.waitForExistence(timeout: 5) {
                amexOption.tap()
            }
        }

        sleep(1)
        app.swipeUp()
        sleep(1)

        captureScreenshot(app, name: "WeeklyPaydownScrolled")
    }

    @MainActor
    func testTransferRulesScreenshot() throws {
        let app = launchApp()
        navigateToWeeklyPaydown(app)

        // Select Amex Gold account
        let accountPicker = app.buttons["Account, Select Account"]
        if accountPicker.waitForExistence(timeout: 5) {
            accountPicker.tap()
            let amexOption = app.buttons["Amex Gold"]
            if amexOption.waitForExistence(timeout: 5) {
                amexOption.tap()
            }
        }

        sleep(1)

        // Tap the transfer rules button
        let transferRulesButton = app.buttons["arrow.left.arrow.right"]
        if transferRulesButton.waitForExistence(timeout: 5) {
            transferRulesButton.tap()
            sleep(1)
            captureScreenshot(app, name: "TransferRulesList")
        } else {
            // Scroll down to show transfer breakdown
            app.swipeUp()
            sleep(1)
            captureScreenshot(app, name: "WeeklyPaydownTransferBreakdown")
        }
    }

    // MARK: - Settings

    @MainActor
    func testSettingsScreenshot() throws {
        let app = launchApp()
        navigateToSettings(app)
        captureScreenshot(app, name: "Settings")
    }

    @MainActor
    func testSettingsHasManagementSection() throws {
        let app = launchApp()
        navigateToSettings(app)

        // Verify Management section links exist
        let categoriesLink = app.staticTexts["Categories"]
        XCTAssertTrue(categoriesLink.waitForExistence(timeout: 5), "Categories link should exist")

        let vendorsLink = app.staticTexts["Vendors"]
        XCTAssertTrue(vendorsLink.waitForExistence(timeout: 5), "Vendors link should exist")
    }

    @MainActor
    func testSettingsHasModeSelector() throws {
        let app = launchApp()
        navigateToSettings(app)

        // Verify Demo Data / API Token mode picker
        let demoDataButton = app.buttons["Demo Data"]
        XCTAssertTrue(demoDataButton.waitForExistence(timeout: 5), "Demo Data mode option should exist")

        let apiTokenButton = app.buttons["API Token"]
        XCTAssertTrue(apiTokenButton.waitForExistence(timeout: 5), "API Token mode option should exist")
    }

    // MARK: - Category List

    @MainActor
    func testCategoryListScreenshot() throws {
        let app = launchApp()
        navigateToSettings(app)

        let categoriesLink = app.staticTexts["Categories"]
        XCTAssertTrue(categoriesLink.waitForExistence(timeout: 5), "Categories link should exist")
        categoriesLink.tap()

        sleep(1)
        captureScreenshot(app, name: "CategoryList")
    }

    // MARK: - Vendor List

    @MainActor
    func testVendorListScreenshot() throws {
        let app = launchApp()
        navigateToSettings(app)

        let vendorsLink = app.staticTexts["Vendors"]
        XCTAssertTrue(vendorsLink.waitForExistence(timeout: 5), "Vendors link should exist")
        vendorsLink.tap()

        sleep(1)
        captureScreenshot(app, name: "VendorList")
    }
}
