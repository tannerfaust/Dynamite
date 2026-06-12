import XCTest
@testable import CodeEdit

final class RenderedMarkdownParserTests: XCTestCase {

    func testParsesGFMTableWithoutRenderingSeparatorSyntax() {
        let document = parser.parse(
            """
            | Name | Status | Count |
            | :--- | :---: | ---: |
            | Markdown | **Ready** | 3 |
            | Escaped \\| pipe |  | 10 |
            """
        )

        guard case .table(let table) = document.blocks.first else {
            return XCTFail("Expected a table block.")
        }

        XCTAssertEqual(table.alignments, [.leading, .center, .trailing])
        XCTAssertEqual(table.header.cells.map(\.renderedPlainText), ["Name", "Status", "Count"])
        XCTAssertEqual(table.rows[0].cells.map(\.renderedPlainText), ["Markdown", "Ready", "3"])
        XCTAssertEqual(table.rows[1].cells.map(\.renderedPlainText), ["Escaped | pipe", "", "10"])
        XCTAssertFalse(document.renderedPlainText.contains("---"))
        XCTAssertFalse(document.renderedPlainText.contains("| Name |"))
    }

    func testParsesHeadingsAndInlineFormattingWithoutRawMarkers() {
        let document = parser.parse(
            """
            # Heading

            This has **bold**, *italic*, ***both***, ~~gone~~, `code`, and [docs](https://example.com).
            """
        )

        XCTAssertEqual(document.renderedPlainText, "Heading\nThis has bold, italic, both, gone, code, and docs.")
        XCTAssertFalse(document.renderedPlainText.contains("#"))
        XCTAssertFalse(document.renderedPlainText.contains("**"))
        XCTAssertFalse(document.renderedPlainText.contains("***"))
        XCTAssertFalse(document.renderedPlainText.contains("https://example.com"))
    }

    func testParsesQuotesListsTasksCodeAndDividers() {
        let document = parser.parse(
            """
            > Quote with **formatting**

            - Item
            - [x] Done
            - [ ] Todo

            3. Third
            4. Fourth

            ---

            ```swift
            let value = 1
            ```
            """
        )

        XCTAssertEqual(document.blocks.count, 5)

        guard case .blockquote(let quoteBlocks) = document.blocks[0],
              case .paragraph(let quoteInlines) = quoteBlocks.first else {
            return XCTFail("Expected a rendered blockquote paragraph.")
        }
        XCTAssertEqual(quoteInlines.renderedPlainText, "Quote with formatting")

        guard case .unorderedList(let unorderedItems) = document.blocks[1] else {
            return XCTFail("Expected unordered list.")
        }
        XCTAssertEqual(unorderedItems.map { $0.taskState }, [nil, .checked, .unchecked])

        guard case .orderedList(let start, let orderedItems) = document.blocks[2] else {
            return XCTFail("Expected ordered list.")
        }
        XCTAssertEqual(start, 3)
        XCTAssertEqual(orderedItems.map { $0.inlines.renderedPlainText }, ["Third", "Fourth"])

        guard case .horizontalRule = document.blocks[3] else {
            return XCTFail("Expected horizontal rule.")
        }

        guard case .codeBlock(let language, let code) = document.blocks[4] else {
            return XCTFail("Expected code block.")
        }
        XCTAssertEqual(language, "swift")
        XCTAssertEqual(code, "let value = 1")
    }

    func testParsesSetextHeadingsAutolinksAndImages() {
        let document = parser.parse(
            """
            Title
            =====

            Visit <https://example.com> and ![Alt text](image.png)
            """
        )

        guard case .heading(let level, let headingInlines) = document.blocks[0] else {
            return XCTFail("Expected setext heading.")
        }
        XCTAssertEqual(level, 1)
        XCTAssertEqual(headingInlines.renderedPlainText, "Title")

        guard case .paragraph(let paragraphInlines) = document.blocks[1] else {
            return XCTFail("Expected paragraph.")
        }
        XCTAssertEqual(paragraphInlines.renderedPlainText, "Visit https://example.com and Alt text")
    }

    func testMalformedTableLikeTextBeforeRuleFallsBackToParagraph() {
        let document = parser.parse(
            """
            | malformed
            ---
            after
            """
        )

        XCTAssertEqual(document.renderedPlainText, "| malformed\nafter")
    }

    private let parser = RenderedMarkdownParser()
}
