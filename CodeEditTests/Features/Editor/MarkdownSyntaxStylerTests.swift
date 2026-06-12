import AppKit
import XCTest
@testable import CodeEdit

final class MarkdownSyntaxStylerTests: XCTestCase {

    func testStylingEmphasisAfterConsumedInlineRangesDoesNotTripExclusivity() {
        let markdown = "Read `code` then [docs](https://example.com) and ***important*** text with **bold**."
        let storage = NSTextStorage(
            string: markdown
        )
        let styler = MarkdownSyntaxStyler(theme: Self.theme)

        XCTAssertNoThrow(styler.applyStyles(to: storage, revealedParagraph: nil))
        XCTAssertEqual(storage.string, markdown)
    }

    func testStylesTablesSetextHeadingsAndHighlights() {
        let storage = NSTextStorage(
            string: """
            Title
            =====

            | Name | Status |
            | --- | --- |
            | Markdown | ==Ready== |
            """
        )
        let styler = MarkdownSyntaxStyler(theme: Self.theme)

        styler.applyStyles(to: storage, revealedParagraph: nil)

        let titleFont = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertGreaterThan(titleFont?.pointSize ?? 0, Self.theme.baseFont.pointSize)

        let separatorLocation = (storage.string as NSString).range(of: "| --- | --- |").location
        let separatorColor = storage.attribute(.foregroundColor, at: separatorLocation, effectiveRange: nil) as? NSColor
        XCTAssertTrue(Self.isClear(separatorColor))

        let highlightedLocation = (storage.string as NSString).range(of: "Ready").location
        XCTAssertNotNil(storage.attribute(.backgroundColor, at: highlightedLocation, effectiveRange: nil))
    }

    func testPreviewConcealsBlockAndInlineMarkdownMarkers() {
        let markdown = """
        # Heading

        Paragraph with **bold**, *italic*, `code`, [docs](https://example.com), and ==highlight==.

        > [!NOTE]
        > Quote

        | Name | Status |
        | --- | --- |
        | Alpha | Ready |

        ---
        """
        let storage = NSTextStorage(string: markdown)
        let styler = MarkdownSyntaxStyler(theme: Self.theme)

        styler.applyStyles(to: storage, revealedParagraph: nil)

        let nsString = storage.string as NSString
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: nsString.range(of: "#").location, in: storage)))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: nsString.range(of: "**").location, in: storage)))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: nsString.range(of: "*italic*").location, in: storage)))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: nsString.range(of: "`").location, in: storage)))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(
            at: nsString.range(of: "](https://example.com)").location,
            in: storage
        )))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: nsString.range(of: "==").location, in: storage)))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: nsString.range(of: "> [!").location, in: storage)))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: nsString.range(of: "| --- | --- |").location, in: storage)))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(
            at: nsString.range(of: "---", options: .backwards).location,
            in: storage
        )))

        let boldLocation = nsString.range(of: "bold").location
        XCTAssertFalse(Self.isClear(Self.foregroundColor(at: boldLocation, in: storage)))
        XCTAssertNotEqual(
            storage.attribute(.font, at: boldLocation, effectiveRange: nil) as? NSFont,
            Self.theme.baseFont
        )
        XCTAssertEqual(storage.string, markdown)
    }

    func testPreviewStylesTablesWithoutShowingPipesOrSeparatorRows() {
        let markdown = """
        | Left | Center | Right |
        | :--- | :---: | ---: |
        | A |  | C |
        """
        let storage = NSTextStorage(string: markdown)
        let styler = MarkdownSyntaxStyler(theme: Self.theme)

        styler.applyStyles(to: storage, revealedParagraph: nil)

        let nsString = storage.string as NSString
        let firstPipe = nsString.range(of: "|").location
        let separator = nsString.range(of: "| :--- | :---: | ---: |").location
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: firstPipe, in: storage)))
        XCTAssertTrue(Self.isClear(Self.foregroundColor(at: separator, in: storage)))

        let headerLocation = nsString.range(of: "Left").location
        XCTAssertNotNil(storage.attribute(.backgroundColor, at: headerLocation, effectiveRange: nil))
        XCTAssertEqual(storage.string, markdown)
    }

    func testStylingKeepsBackingStringStableForSyntaxMarkers() {
        let storage = NSTextStorage(string: "# Heading with [link](https://example.com)")
        let styler = MarkdownSyntaxStyler(theme: Self.theme)

        styler.applyStyles(to: storage, revealedParagraph: nil)

        XCTAssertEqual(storage.string, "# Heading with [link](https://example.com)")
    }

    func testIncrementalStylingMatchesFullDocumentPass() {
        let markdown = """
        # Heading

        This has **bold**, *italic*, and `code`.

        > A blockquote

        - List item
        - [x] Done
        """

        // Full-document styling.
        let fullStorage = NSTextStorage(string: markdown)
        let fullStyler = MarkdownSyntaxStyler(theme: Self.theme)
        fullStyler.applyStyles(to: fullStorage, revealedParagraph: nil)

        // Incremental styling: style the whole range via the incremental method.
        let incrStorage = NSTextStorage(string: markdown)
        let incrStyler = MarkdownSyntaxStyler(theme: Self.theme)
        let fullRange = NSRange(location: 0, length: (markdown as NSString).length)
        incrStyler.applyStyles(to: incrStorage, in: fullRange, revealedParagraph: nil)

        // The backing strings must be identical (no corruption).
        XCTAssertEqual(fullStorage.string, incrStorage.string)

        // Compare attributes at sampled positions across the document.
        let nsString = fullStorage.string as NSString
        let samplePositions = stride(from: 0, to: nsString.length, by: max(1, nsString.length / 20))
        for pos in samplePositions {
            let fullFont = fullStorage.attribute(.font, at: pos, effectiveRange: nil) as? NSFont
            let incrFont = incrStorage.attribute(.font, at: pos, effectiveRange: nil) as? NSFont
            XCTAssertEqual(
                fullFont, incrFont,
                "Font mismatch at position \(pos)"
            )

            let fullColor = fullStorage.attribute(.foregroundColor, at: pos, effectiveRange: nil) as? NSColor
            let incrColor = incrStorage.attribute(.foregroundColor, at: pos, effectiveRange: nil) as? NSColor
            XCTAssertEqual(
                fullColor, incrColor,
                "Color mismatch at position \(pos)"
            )
        }
    }

    func testIncrementalStylingHandlesFencedCodeBlockContext() {
        let markdown = """
        Text before fence.

        ```swift
        let x = 1
        ```

        Text after fence.
        """

        // Full-document pass.
        let fullStorage = NSTextStorage(string: markdown)
        let fullStyler = MarkdownSyntaxStyler(theme: Self.theme)
        fullStyler.applyStyles(to: fullStorage, revealedParagraph: nil)

        // Incremental pass: style only the "let x = 1" line range.
        let incrStorage = NSTextStorage(string: markdown)
        let incrStyler = MarkdownSyntaxStyler(theme: Self.theme)
        // First do a full pass to establish base, then simulate an edit in the code block.
        incrStyler.applyStyles(to: incrStorage, revealedParagraph: nil)
        let codeLine = (markdown as NSString).range(of: "let x = 1")
        incrStyler.applyStyles(to: incrStorage, in: codeLine, revealedParagraph: nil)

        // The code line should have the code font in both cases.
        let fullFont = fullStorage.attribute(.font, at: codeLine.location, effectiveRange: nil) as? NSFont
        let incrFont = incrStorage.attribute(.font, at: codeLine.location, effectiveRange: nil) as? NSFont
        XCTAssertEqual(fullFont, incrFont, "Fenced code block font mismatch")

        let fullColor = fullStorage.attribute(.foregroundColor, at: codeLine.location, effectiveRange: nil) as? NSColor
        let incrColor = incrStorage.attribute(.foregroundColor, at: codeLine.location, effectiveRange: nil) as? NSColor
        XCTAssertEqual(fullColor, incrColor, "Fenced code block color mismatch")
    }

    func testIncrementalStylingPreservesSourceFidelity() {
        let markdown = "# Heading with **bold** and `code` and [link](https://example.com)"
        let storage = NSTextStorage(string: markdown)
        let styler = MarkdownSyntaxStyler(theme: Self.theme)

        // Style incrementally.
        let range = NSRange(location: 0, length: (markdown as NSString).length)
        styler.applyStyles(to: storage, in: range, revealedParagraph: nil)

        // The backing string must be unchanged — no corruption.
        XCTAssertEqual(storage.string, markdown)
    }

    private static let theme = MarkdownTheme(
        baseFont: .systemFont(ofSize: 13),
        textColor: .labelColor,
        secondaryColor: .secondaryLabelColor,
        accentColor: .systemBlue,
        codeForeground: .systemPink,
        codeBackground: .textBackgroundColor,
        quoteColor: .secondaryLabelColor,
        quoteBackground: .textBackgroundColor,
        dividerColor: .separatorColor,
        tableHeaderBackground: .textBackgroundColor,
        tableBorderColor: .separatorColor,
        highlightBackground: .systemYellow,
        syntaxColor: .tertiaryLabelColor
    )

    private static func foregroundColor(at location: Int, in storage: NSTextStorage) -> NSColor? {
        storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor
    }

    private static func isClear(_ color: NSColor?) -> Bool {
        guard let color else { return false }
        return color.usingColorSpace(.deviceRGB)?.alphaComponent == 0
    }
}
