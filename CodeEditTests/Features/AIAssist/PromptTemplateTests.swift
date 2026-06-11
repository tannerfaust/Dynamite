import XCTest
@testable import CodeEdit

final class PromptTemplateTests: XCTestCase {

    // MARK: - Helpers

    private func makeBundle(bodyChars: Int = 200) -> ContextBundle {
        let focusRef  = NodeRef(id: "prd-001", kind: "prd", title: "Test PRD")
        let focusItem = ContextBundleItem(
            id: "prd-001",
            ref: focusRef,
            edgeRel: nil,
            content: String(repeating: "a", count: bodyChars),
            isEvidence: false,
            priority: 100
        )
        return ContextBundle(focus: focusItem, linkedItems: [], droppedItems: [])
    }

    private func makeRequest(operation: AssistOperation, selection: String? = nil) -> AssistRequest {
        AssistRequest(
            operation: operation,
            prompt: "Test prompt",
            bundle: makeBundle(),
            budget: .default(for: operation),
            selection: selection
        )
    }

    // MARK: - Tests

    func testAllOperationsProduceNonEmptyPrompts() {
        for operation in AssistOperation.allCases {
            let prompt = PromptTemplate.build(for: makeRequest(operation: operation))
            XCTAssertFalse(prompt.system.isEmpty, "\(operation.rawValue): system prompt is empty")
            XCTAssertFalse(prompt.user.isEmpty,   "\(operation.rawValue): user message is empty")
        }
    }

    func testDraftPromptContainsFocusContent() {
        let request = makeRequest(operation: .draft)
        let prompt = PromptTemplate.build(for: request)
        XCTAssertTrue(prompt.user.contains("Test PRD"), "User message should reference the focus artifact")
    }

    func testRefinePromptIncludesSelection() {
        let request = makeRequest(operation: .refine, selection: "This is the selected text")
        let prompt = PromptTemplate.build(for: request)
        XCTAssertTrue(prompt.user.contains("This is the selected text"), "Refine prompt should include selection")
    }

    func testCrossCheckSystemPromptMentionsJSON() {
        let request = makeRequest(operation: .crossCheck)
        let prompt = PromptTemplate.build(for: request)
        XCTAssertTrue(prompt.system.lowercased().contains("json"), "Cross-check system prompt must instruct JSON output")
    }

    func testNoToolSchemaInAnyPrompt() {
        // This test documents the no-agent rule (ADR-0007 §5):
        // no prompt template should contain "tools", "function_call", or "tool_choice".
        let forbidden = ["\"tools\"", "function_call", "tool_choice", "tool_use"]
        for operation in AssistOperation.allCases {
            let prompt = PromptTemplate.build(for: makeRequest(operation: operation))
            let combined = prompt.system + prompt.user
            for keyword in forbidden {
                XCTAssertFalse(
                    combined.contains(keyword),
                    "\(operation.rawValue): prompt contains forbidden keyword '\(keyword)' (no-agent rule)"
                )
            }
        }
    }

    func testCrossCheckSystemPromptMentionsDiscrepancyKinds() {
        let prompt = PromptTemplate.build(for: makeRequest(operation: .crossCheck))
        XCTAssertTrue(prompt.system.contains("contradicts"))
        XCTAssertTrue(prompt.system.contains("unsupported"))
        XCTAssertTrue(prompt.system.contains("stale"))
    }

    func testBundleSummaryContainsFocusHeading() {
        let request = makeRequest(operation: .draft)
        let prompt = PromptTemplate.build(for: request)
        XCTAssertTrue(prompt.user.contains("## Focus artifact"))
    }

    func testDraftPromptIncludesUserInstruction() {
        let request = AssistRequest(
            operation: .draft,
            prompt: "My custom instruction",
            bundle: makeBundle(),
            budget: .default(for: .draft)
        )
        let prompt = PromptTemplate.build(for: request)
        XCTAssertTrue(prompt.user.contains("My custom instruction"))
    }
}
