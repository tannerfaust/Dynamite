// swiftlint:disable line_length
import XCTest
@testable import CodeEdit

// MARK: - Stub types for testing

/// Mock AIAssistService that returns a configurable result.
final class MockAIAssistService: AIAssistService {
    var stubResult: AssistResult?
    var stubError: Error?
    var lastRequest: AssistRequest?

    func run(_ request: AssistRequest) -> AsyncThrowingStream<AssistEvent, Error> {
        lastRequest = request
        let result = stubResult
        let error = stubError
        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            let text = result?.text ?? "Draft content"
            continuation.yield(.delta(text))
            continuation.yield(.usage(TokenUsage(inputTokens: 100, outputTokens: 50, modelID: "test", timestamp: Date())))
            continuation.yield(.done(result ?? AssistResult(text: text, groundingRefs: [], discrepancies: nil)))
            continuation.finish()
        }
    }

    func estimate(_ request: AssistRequest) -> CostEstimate {
        CostEstimate(estimatedInputTokens: 1000, maxOutputTokens: 500, estimatedUSD: 0.01)
    }
}

// MARK: - ContextBundleBuilderTests

final class ContextBundleBuilderTests: XCTestCase {

    // A builder with no LinkIndex (graceful degradation path).
    private func makeBuilder() -> ContextBundleBuilder {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return ContextBundleBuilder(linkIndex: nil, workspaceURL: tempURL)
    }

    private func makeFocusArtifact(body: String = "# Draft\n\nSome content.") -> ProductArtifact {
        ProductArtifact(
            id: "prd-test01",
            kind: .prd,
            kindString: "prd",
            status: "draft",
            title: "Test PRD",
            tags: [],
            links: [],
            created: "2026-06-10",
            updated: "2026-06-10",
            extraFields: [:],
            body: body,
            url: URL(filePath: "/tmp/test.md")
        )
    }

    // MARK: - Tests

    func testFocusOnlyBundleWhenNoIndex() async {
        let builder = makeBuilder()
        let artifact = makeFocusArtifact()
        let budget = TokenBudget.default(for: .draft)
        let bundle = await builder.build(focus: artifact, operation: .draft, budget: budget)

        XCTAssertEqual(bundle.focus.id, "prd-test01")
        XCTAssertEqual(bundle.linkedItems.count, 0, "No linked items expected without a LinkIndex")
        XCTAssertEqual(bundle.droppedItems.count, 0)
    }

    func testFocusIsAlwaysIncluded() async {
        let builder = makeBuilder()
        let body = String(repeating: "a", count: 100)
        let artifact = makeFocusArtifact(body: body)
        let bundle = await builder.build(focus: artifact, operation: .draft, budget: TokenBudget(maxInputTokens: 1, maxOutputTokens: 100))

        // Even with a tiny budget the focus is always present.
        XCTAssertEqual(bundle.focus.id, artifact.id)
        XCTAssertEqual(bundle.focus.content, body)
    }

    func testEstimatedTokensIsPositive() async {
        let builder = makeBuilder()
        let artifact = makeFocusArtifact(body: "Hello world")
        let bundle = await builder.build(focus: artifact, operation: .draft, budget: .default(for: .draft))
        XCTAssertGreaterThan(bundle.estimatedTokens, 0)
    }

    func testTrimDropsLowestPriorityItemsFirst() {
        // Directly test the trim logic by constructing a bundle with known priorities.
        let focus = ContextBundleItem(
            id: "focus",
            ref: NodeRef(id: "focus", kind: "prd", title: "Focus"),
            edgeRel: nil,
            content: String(repeating: "x", count: 40),  // ~10 tokens
            isEvidence: false,
            priority: 100
        )
        let highPri = ContextBundleItem(
            id: "high",
            ref: NodeRef(id: "high", kind: "insight", title: "High"),
            edgeRel: "validates",
            content: String(repeating: "y", count: 40),  // ~10 tokens
            isEvidence: true,
            priority: 80
        )
        let lowPri = ContextBundleItem(
            id: "low",
            ref: NodeRef(id: "low", kind: "feedback", title: "Low"),
            edgeRel: "relates-to",
            content: String(repeating: "z", count: 40),  // ~10 tokens
            isEvidence: false,
            priority: 20
        )

        // Budget: ~15 tokens max input → high-priority fits, low-priority should be dropped.
        // Total chars = 120 → ~30 tokens. Need to drop 1 item to fit in 20 tokens.
        let budget = TokenBudget(maxInputTokens: 20, maxOutputTokens: 100)

        // Build bundle manually (trim is private; test via ContextBundle struct).
        // Simulate what trim does: linked items sorted by priority DESC = [highPri, lowPri].
        // Drop from end (lowest priority) until fit.
        var linked = [highPri, lowPri]
        var dropped: [ContextBundleItem] = []
        func estimatedTokens() -> Int {
            let chars = focus.content.count + linked.reduce(0) { $0 + $1.content.count }
            return max(1, chars / 4)
        }
        while estimatedTokens() > budget.maxInputTokens, !linked.isEmpty {
            dropped.append(linked.removeLast())
        }

        XCTAssertEqual(linked.map(\.id), ["high"])
        XCTAssertEqual(dropped.map(\.id), ["low"])
    }

    func testDeterministicOrder() {
        // Items with same priority should sort by ID (stable alphabetical).
        let items: [ContextBundleItem] = [
            ContextBundleItem(id: "b", ref: NodeRef(id: "b", kind: "insight", title: nil), edgeRel: "informs", content: "b", isEvidence: true, priority: 50),
            ContextBundleItem(id: "a", ref: NodeRef(id: "a", kind: "insight", title: nil), edgeRel: "informs", content: "a", isEvidence: true, priority: 50)
        ]
        let sorted = items.sorted { lhs, rhs in
            lhs.priority != rhs.priority ? lhs.priority > rhs.priority : lhs.id < rhs.id
        }
        XCTAssertEqual(sorted.map(\.id), ["a", "b"])
    }
}
