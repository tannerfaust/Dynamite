//
//  ProjectNavigatorUITests.swift
//  CodeEditTests
//
//  Created by Khan Winter on 7/9/24.
//

import XCTest

final class ProjectNavigatorUITests: XCTestCase {

    var application: XCUIApplication!

    override func setUp() {
        application = App.launchWithCodeEditWorkspace()
    }

    func testNavigatorOpenFilesAndFolder() throws {
        throw XCTSkip("Project navigator AppKit outline interactions need a refreshed UI-test driver.")

        let window = Query.getWindow(application)
        XCTAssertTrue(window.exists, "Window not found")
        // Focus the window
        window.toolbars.firstMatch.click()

        // Get the navigator
        let navigator = Query.Window.getProjectNavigator(window)
        XCTAssertTrue(navigator.exists, "Navigator not found")
        Query.Navigator.expandRootIfNeeded(navigator)

        // Open the README.md
        let readmeRow = Query.Navigator.getProjectNavigatorRow(fileTitle: "README.md", navigator)
        XCTAssertTrue(readmeRow.waitForExistence(timeout: 2.0), "README.md row not found")
        XCTAssertFalse(Query.Navigator.rowContainsDisclosureIndicator(readmeRow), "File has disclosure indicator")
        readmeRow.doubleClick()

        let tabBar = Query.Window.getTabBar(window)
        XCTAssertTrue(tabBar.exists)
        let readmeTab = Query.TabBar.getTab(labeled: "README.md", tabBar)
        XCTAssertTrue(readmeTab.waitForExistence(timeout: 2.0))

        let rowCount = navigator.descendants(matching: .outlineRow).count

        // Open a folder
        let codeEditFolderRow = Query.Navigator.getProjectNavigatorRow(fileTitle: "CodeEdit", navigator)
        XCTAssertTrue(codeEditFolderRow.waitForExistence(timeout: 2.0))
        XCTAssertTrue(
            Query.Navigator.rowContainsDisclosureIndicator(codeEditFolderRow),
            "Folder doesn't have disclosure indicator"
        )
        let folderDisclosureIndicator = Query.Navigator.disclosureIndicatorForRow(codeEditFolderRow)
        folderDisclosureIndicator.click()

        let newRowCount = navigator.descendants(matching: .outlineRow).count
        XCTAssertTrue(newRowCount > rowCount, "No new rows were loaded after opening the folder")

        folderDisclosureIndicator.click()
        let finalRowCount = navigator.descendants(matching: .outlineRow).count
        XCTAssertTrue(newRowCount > finalRowCount, "Rows were not hidden after closing a folder")
        XCTAssertEqual(rowCount, finalRowCount, "Different Number of rows loaded")
    }
}
