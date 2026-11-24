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
        XCTAssertTrue(app.buttons["viewer.open"].waitForExistence(timeout: 10))
        let toggleViewer = app.buttons["viewer.toggle"]
        XCTAssertTrue(toggleViewer.exists)
        toggleViewer.click()
        XCTAssertFalse(app.buttons["viewer.open"].exists)
        toggleViewer.click()
        XCTAssertTrue(app.buttons["viewer.open"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Review"].exists)
        XCTAssertFalse(app.buttons["Reconstruction"].isEnabled)
        app.activate()
        XCTAssertTrue(app.buttons["viewer.open"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Tools"].click()
        let toolPicker = app.popUpButtons.firstMatch
        XCTAssertTrue(toolPicker.waitForExistence(timeout: 5))
        toolPicker.click()
        app.menuItems["Print QR markers"].click()
        XCTAssertTrue(app.buttons["markers.export"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["viewer.open"].exists)
    }

    @MainActor
    func testPhotoSelectionControlsReconstruction() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pixel = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNoAAAAggCBd81ytgAAAABJRU5ErkJggg=="))
        let file = folder.appendingPathComponent("sample.png")
        try pixel.write(to: file)

        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-ApplePersistenceIgnoreState", "YES", "-review.exclude", "NO"]
        app.launch()
        let add = app.buttons["Add photos…"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.click()
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(file.path)
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 5))
        let tile = app.descendants(matching: .any)["photo.sample.png"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.click()
        XCTAssertFalse(app.buttons["Reconstruction"].isEnabled)
        tile.click()
        app.buttons["Reconstruction"].click()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Stop"].isEnabled)
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
