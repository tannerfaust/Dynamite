import XCTest
@testable import CodeEdit

final class MarkdownSlashMenuTests: XCTestCase {

    func testSlashMenuContainsComprehensiveMarkdownBlocks() {
        let titles = Set(MarkdownBlock.essentials.map(\.title))

        XCTAssertTrue(titles.isSuperset(of: [
            "Paragraph",
            "Heading 1",
            "Heading 6",
            "Bullet List",
            "Numbered List",
            "Checklist",
            "Bold",
            "Italic",
            "Strikethrough",
            "Highlight",
            "Quote",
            "Callout: Note",
            "Table",
            "Decision Table",
            "Code Block",
            "Swift Code Block",
            "Link",
            "Image",
            "Footnote",
            "Details"
        ]))
    }

    func testSlashMenuUsesExplicitCaretTokenSoTablesCanContainPipes() throws {
        let table = try XCTUnwrap(MarkdownBlock.essentials.first { $0.title == "Table" })
        let storedSnippet = table.snippet.replacingOccurrences(of: MarkdownBlock.caretToken, with: "")

        XCTAssertTrue(table.snippet.contains("| Column | Column |"))
        XCTAssertTrue(table.snippet.contains(MarkdownBlock.caretToken))
        XCTAssertTrue(storedSnippet.contains("|  | |"))
    }

    func testSlashMenuSnippetsStorePlainMarkdown() {
        for block in MarkdownBlock.essentials {
            XCTAssertTrue(block.snippet.contains(MarkdownBlock.caretToken), "\(block.title) is missing caret token")
            XCTAssertFalse(block.snippet.contains("\u{200B}"), "\(block.title) contains hidden storage characters")
        }
    }
}
