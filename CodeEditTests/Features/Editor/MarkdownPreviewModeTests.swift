import XCTest
@testable import CodeEdit

final class MarkdownPreviewModeTests: XCTestCase {

    func testLegacyEnabledSettingMigratesToPreviewMode() throws {
        let json = Data(#"{"markdownPreviewEnabled":true}"#.utf8)

        let settings = try JSONDecoder().decode(SettingsData.TextEditingSettings.self, from: json)

        XCTAssertEqual(settings.markdownPreviewMode, .preview)
        XCTAssertTrue(settings.markdownPreviewEnabled)
    }

    func testExplicitCurrentMarkdownPreviewModeWinsOverLegacySetting() throws {
        let json = Data(#"{"markdownPreviewEnabled":false,"markdownPreviewMode":"preview"}"#.utf8)

        let settings = try JSONDecoder().decode(SettingsData.TextEditingSettings.self, from: json)

        XCTAssertEqual(settings.markdownPreviewMode, .preview)
    }

    func testExplicitTemporaryEngineModeMigratesToPreview() throws {
        let json = Data(#"{"markdownPreviewEnabled":true,"markdownPreviewMode":"swiftMarkdownEngine"}"#.utf8)

        let settings = try JSONDecoder().decode(SettingsData.TextEditingSettings.self, from: json)

        XCTAssertEqual(settings.markdownPreviewMode, .preview)
    }

    func testExplicitOldNativeModeMigratesToPreview() throws {
        let json = Data(#"{"markdownPreviewMode":"dynamiteNative"}"#.utf8)

        let settings = try JSONDecoder().decode(SettingsData.TextEditingSettings.self, from: json)

        XCTAssertEqual(settings.markdownPreviewMode, .preview)
    }

    func testMarkdownPreviewModeTogglesSourceAndPreview() {
        XCTAssertEqual(MarkdownPreviewMode.source.next, .preview)
        XCTAssertEqual(MarkdownPreviewMode.preview.next, .source)
    }
}
