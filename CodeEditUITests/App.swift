//
//  App.swift
//  CodeEditUITests
//
//  Created by Khan Winter on 7/21/24.
//

import XCTest

enum App {
    static func launchWithCodeEditWorkspace() -> XCUIApplication {
        let application = XCUIApplication()
        configureForUITesting(application)
        application.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "--open", projectPath()]
        application.launch()
        switchToGroundControl(application)
        return application
    }

    // Launches CodeEdit in a new directory and returns the directory path.
    static func launchWithTempDir() throws -> (XCUIApplication, String) {
        let tempDirURL = try tempProjectPath()
        let application = XCUIApplication()
        configureForUITesting(application)
        application.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "--open", tempDirURL]
        application.launch()
        switchToGroundControl(application)
        return (application, tempDirURL)
    }

    static func launch() -> XCUIApplication {
        let application = XCUIApplication()
        configureForUITesting(application)
        application.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        application.launch()
        return application
    }

    private static func configureForUITesting(_ application: XCUIApplication) {
        let settingsURL = FileManager.default.temporaryDirectory
            .appending(path: "CodeEditUITests")
            .appending(path: "Settings")
            .appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: settingsURL, withIntermediateDirectories: true)
        application.launchEnvironment["CODEEDIT_SETTINGS_DIR"] = settingsURL.path(percentEncoded: false)
    }

    private static func switchToGroundControl(_ application: XCUIApplication) {
        let window = Query.getWindow(application)
        _ = window.waitForExistence(timeout: 5.0)
        application.typeKey("2", modifierFlags: .command)
        _ = Query.Window.getProjectNavigator(window).waitForExistence(timeout: 5.0)
    }
}
