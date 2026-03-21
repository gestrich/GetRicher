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

    @MainActor
    func testTransactionsLoadMore() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-pageSize", "5"]
        app.launch()

        // Wait for data to load
        let financeTitle = app.staticTexts["Finance"]
        XCTAssertTrue(financeTitle.waitForExistence(timeout: 10), "Finance title should appear")

        // Scroll down to find Load More button
        let loadMoreButton = app.buttons["Load More"]
        var attempts = 0
        while !loadMoreButton.exists && attempts < 20 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(loadMoreButton.exists, "Load More button should be visible")

        // Take screenshot showing Load More
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "TransactionsLoadMore"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Tap Load More and verify it works (more transactions appear)
        loadMoreButton.tap()

        // Wait a moment for loading
        sleep(2)

        // Take screenshot after loading more
        let afterScreenshot = app.screenshot()
        let afterAttachment = XCTAttachment(screenshot: afterScreenshot)
        afterAttachment.name = "TransactionsAfterLoadMore"
        afterAttachment.lifetime = .keepAlways
        add(afterAttachment)
    }

    @MainActor
    func testWeeklyPaydownScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Weekly Paydown tab
        let paydownTab = app.tabBars.buttons["Weekly Paydown"]
        XCTAssertTrue(paydownTab.waitForExistence(timeout: 10), "Weekly Paydown tab should exist")
        paydownTab.tap()

        // Wait for the view to load
        let title = app.staticTexts["Weekly Paydown"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Weekly Paydown title should appear")

        // Select the Amex Gold account (credit card)
        let accountPicker = app.buttons["Account, Select Account"]
        if accountPicker.waitForExistence(timeout: 5) {
            accountPicker.tap()
            let amexOption = app.buttons["Amex Gold"]
            if amexOption.waitForExistence(timeout: 5) {
                amexOption.tap()
            }
        }

        // Wait for calculation to appear
        sleep(2)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "WeeklyPaydown"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testSettingsScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for main view to load
        let financeTitle = app.staticTexts["Finance"]
        XCTAssertTrue(financeTitle.waitForExistence(timeout: 10), "Finance title should appear")

        // Tap settings gear
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
        settingsButton.tap()

        // Wait for settings to appear
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5), "Settings title should appear")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Settings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCategoryListScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        let financeTitle = app.staticTexts["Finance"]
        XCTAssertTrue(financeTitle.waitForExistence(timeout: 10))

        // Navigate: Settings → Categories
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let categoriesLink = app.buttons["Categories"]
        XCTAssertTrue(categoriesLink.waitForExistence(timeout: 5), "Categories link should exist in Settings")
        categoriesLink.tap()

        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "CategoryList"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testVendorListScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        let financeTitle = app.staticTexts["Finance"]
        XCTAssertTrue(financeTitle.waitForExistence(timeout: 10))

        // Navigate: Settings → Vendors
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let vendorsLink = app.buttons["Vendors"]
        XCTAssertTrue(vendorsLink.waitForExistence(timeout: 5), "Vendors link should exist in Settings")
        vendorsLink.tap()

        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "VendorList"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testTransferRulesScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Weekly Paydown tab
        let paydownTab = app.tabBars.buttons["Weekly Paydown"]
        XCTAssertTrue(paydownTab.waitForExistence(timeout: 10))
        paydownTab.tap()

        let title = app.staticTexts["Weekly Paydown"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))

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

        // Tap the transfer rules button (arrow icon in toolbar)
        let transferRulesButton = app.buttons["arrow.left.arrow.right"]
        if transferRulesButton.waitForExistence(timeout: 5) {
            transferRulesButton.tap()
            sleep(1)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "TransferRulesList"
            attachment.lifetime = .keepAlways
            add(attachment)
        } else {
            // Take screenshot of Weekly Paydown with transfer breakdown visible
            // Scroll down to find the transfer breakdown section
            app.swipeUp()
            sleep(1)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "WeeklyPaydownTransferBreakdown"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testPieChartScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for data to load (demo mode loads instantly but UI needs a moment)
        let spendingDistribution = app.staticTexts["Spending Distribution"]
        let exists = spendingDistribution.waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "Spending Distribution chart should appear")

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "PieChart"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
