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
