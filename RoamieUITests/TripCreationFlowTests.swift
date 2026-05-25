import XCTest

final class TripCreationFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testCreateEmptyTrip() {
        app.navigationBars.buttons["plus.circle.fill"].tap()
        XCTAssertTrue(app.navigationBars["新建旅程"].exists)
    }

    func testTripListEmptyState() {
        XCTAssertTrue(app.staticTexts["还没有旅程"].exists ||
                      app.tables.cells.count > 0,
                      "Should show either empty state or existing trips")
    }
}
