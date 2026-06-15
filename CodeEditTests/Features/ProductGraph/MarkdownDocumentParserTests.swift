//
//  MarkdownDocumentParserTests.swift
//  CodeEditTests
//

import XCTest
@testable import CodeEdit

final class MarkdownDocumentParserTests: XCTestCase {

    func testExtractsSections() {
        let markdown = """
        # Checkout PRD

        ## Problem
        Users abandon checkout.

        ### Evidence
        Interview notes.

        ## Risks
        Tax varies by region.
        """

        XCTAssertEqual(
            MarkdownDocumentParser.sections(in: markdown),
            [
                MarkdownSection(level: 1, title: "Checkout PRD"),
                MarkdownSection(level: 2, title: "Problem"),
                MarkdownSection(level: 3, title: "Evidence"),
                MarkdownSection(level: 2, title: "Risks")
            ]
        )
    }

    func testExtractsTaskItems() {
        let markdown = """
        ## Acceptance Criteria
        - [ ] Shipping cost is visible before payment
        - [x] Returning users see saved address options
        """

        XCTAssertEqual(
            MarkdownDocumentParser.taskItems(in: markdown),
            [
                MarkdownTaskItem(text: "Shipping cost is visible before payment", isCompleted: false),
                MarkdownTaskItem(text: "Returning users see saved address options", isCompleted: true)
            ]
        )
    }

    func testExtractsLinks() {
        let markdown = """
        See [Spec](../planning/spec.md) and
        [`CheckoutViewModel.swift`](../../CodeEdit/Features/Checkout/CheckoutViewModel.swift).
        """

        XCTAssertEqual(
            MarkdownDocumentParser.links(in: markdown),
            [
                MarkdownLink(title: "Spec", destination: "../planning/spec.md"),
                MarkdownLink(
                    title: "CheckoutViewModel.swift",
                    destination: "../../CodeEdit/Features/Checkout/CheckoutViewModel.swift"
                )
            ]
        )
    }
}
