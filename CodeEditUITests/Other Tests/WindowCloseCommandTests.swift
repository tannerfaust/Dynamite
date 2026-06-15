//
//  WindowCloseCommandTests.swift
//  CodeEditUITests
//
//  Created by Khan Winter on 7/21/24.
//

import XCTest

/// Tests for window closing commands.
/// - Note: feel free to add on in the future and change this test name.
final class WindowCloseCommandTests: XCTestCase {
    // swiftier api (expectation(that: , on:, willEqual:) doesn't work :(
    let notExistsPredicate = NSPredicate(format: "exists == false")

    var application: XCUIApplication!

    func testWorkspaceWindowCloses() {
        application = App.launchWithCodeEditWorkspace()
        let window = Query.getWindow(application)
        XCTAssertTrue(window.waitForExistence(timeout: 5.0), "Workspace didn't open")
        window.toolbars.firstMatch.click()

        let expectation = expectation(for: notExistsPredicate, evaluatedWith: window)
        application.typeKey("w", modifierFlags: .command)
        wait(for: [expectation], timeout: 5.0)
    }

    func testWorkspaceTabCloses() throws {
        throw XCTSkip("Workspace tab close coverage needs the refreshed project navigator UI-test driver.")

        application = App.launchWithCodeEditWorkspace()
        let window = Query.getWindow(application)
        XCTAssertTrue(window.waitForExistence(timeout: 5.0), "Workspace didn't open")

        window.toolbars.firstMatch.click()

        let navigator = Query.Window.getProjectNavigator(window)
        Query.Navigator.expandRootIfNeeded(navigator)
        let readmeRow = Query.Navigator.getProjectNavigatorRow(fileTitle: "README.md", navigator)
        XCTAssertTrue(navigator.exists)
        XCTAssertTrue(readmeRow.waitForExistence(timeout: 2.0), "README.md row not found")
        readmeRow.doubleClick()

        let tabBar = Query.Window.getTabBar(window)
        XCTAssertTrue(tabBar.exists)
        let readmeTab = Query.TabBar.getTab(labeled: "README.md", tabBar)
        XCTAssertTrue(readmeTab.waitForExistence(timeout: 2.0))
        XCTAssertEqual(tabBar.staticTexts.count, 1)

        let tabCloseExpectation = expectation(for: notExistsPredicate, evaluatedWith: readmeTab)
        application.typeKey("w", modifierFlags: .command)
        wait(for: [tabCloseExpectation], timeout: 5.0)
        XCTAssertEqual(tabBar.staticTexts.count, 0)

        let windowCloseExpectation = expectation(for: notExistsPredicate, evaluatedWith: window)
        application.typeKey("w", modifierFlags: .command)
        wait(for: [windowCloseExpectation], timeout: 5.0)
    }

    func testWorkspaceClosesWithTabStillOpen() throws {
        throw XCTSkip("Workspace tab close coverage needs the refreshed project navigator UI-test driver.")

        application = App.launchWithCodeEditWorkspace()
        let window = Query.getWindow(application)
        XCTAssertTrue(window.waitForExistence(timeout: 5.0), "Workspace didn't open")

        window.toolbars.firstMatch.click()

        let navigator = Query.Window.getProjectNavigator(window)
        Query.Navigator.expandRootIfNeeded(navigator)
        let readmeRow = Query.Navigator.getProjectNavigatorRow(fileTitle: "README.md", navigator)
        XCTAssertTrue(navigator.exists)
        XCTAssertTrue(readmeRow.waitForExistence(timeout: 2.0), "README.md row not found")
        readmeRow.doubleClick()

        let tabBar = Query.Window.getTabBar(window)
        XCTAssertTrue(tabBar.exists)
        let readmeTab = Query.TabBar.getTab(labeled: "README.md", tabBar)
        XCTAssertTrue(readmeTab.waitForExistence(timeout: 2.0))
        XCTAssertEqual(tabBar.staticTexts.count, 1)

        let windowCloseExpectation = expectation(for: notExistsPredicate, evaluatedWith: window)
        application.typeKey("w", modifierFlags: [.shift, .command])
        wait(for: [windowCloseExpectation], timeout: 5.0)
    }

    func testSettingsWindowCloses() {
        application = App.launch()
        let window = Query.getSettingsWindow(application)
        application.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(window.waitForExistence(timeout: 5.0), "Settings didn't open")

        let expectation = expectation(for: notExistsPredicate, evaluatedWith: window)
        application.typeKey("w", modifierFlags: .command)
        wait(for: [expectation], timeout: 5.0)
    }

    func testWelcomeWindowCloses() {
        application = App.launch()
        let window = Query.getWelcomeWindow(application)
        application.typeKey("1", modifierFlags: [.shift, .command])
        XCTAssertTrue(window.waitForExistence(timeout: 5.0), "Welcome didn't open")

        let expectation = expectation(for: notExistsPredicate, evaluatedWith: window)
        application.typeKey("w", modifierFlags: .command)
        wait(for: [expectation], timeout: 5.0)
    }

    func testAboutWindowCloses() {
        application = App.launch()
        let window = Query.getAboutWindow(application)
        application.typeKey("2", modifierFlags: [.shift, .command])
        XCTAssertTrue(window.waitForExistence(timeout: 5.0), "About didn't open")

        let expectation = expectation(for: notExistsPredicate, evaluatedWith: window)
        application.typeKey("w", modifierFlags: .command)
        wait(for: [expectation], timeout: 5.0)
    }

}
