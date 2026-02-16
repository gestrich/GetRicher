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
