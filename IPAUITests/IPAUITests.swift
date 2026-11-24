//
//  IPAUITests.swift
//  IPAUITests
//
//  Created by Brice Lebrun on 06/02/2025.
//

import XCTest

final class IPAUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testIndependentViewerAndMarkerTool() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        let viewer = app.buttons["Viewer"]
        XCTAssertTrue(viewer.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Review"].isEnabled)
        XCTAssertFalse(app.buttons["Reconstruction"].isEnabled)
        app.activate()
        viewer.click()
        XCTAssertTrue(app.buttons["viewer.open"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Tools"].click()
        let markers = app.staticTexts["Print QR markers"]
        XCTAssertTrue(markers.waitForExistence(timeout: 5))
        markers.click()
        XCTAssertTrue(app.buttons["markers.export"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
