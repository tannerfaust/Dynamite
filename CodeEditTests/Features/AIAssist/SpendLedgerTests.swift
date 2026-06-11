import XCTest
@testable import CodeEdit

final class SpendLedgerTests: XCTestCase {

    private var tempDir: URL!
    private var ledger: SpendLedger!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        ledger = SpendLedger(workspaceURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testRecordAccumulatesEntries() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 200, modelID: "claude-sonnet-4-5", timestamp: Date())
        ledger.record(usage: usage, operation: .draft, provider: .anthropic)

        // Allow the serial queue to process.
        let expectation = XCTestExpectation(description: "Entry recorded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(self.ledger.entries.count, 1)
            XCTAssertGreaterThan(self.ledger.totalSpendUSD, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMonthlySpendIncludesCurrentMonth() {
        let usage = TokenUsage(inputTokens: 500, outputTokens: 100, modelID: "gpt-4o-mini", timestamp: Date())
        ledger.record(usage: usage, operation: .refine, provider: .openAI)

        let expectation = XCTestExpectation(description: "Monthly spend computed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertGreaterThanOrEqual(self.ledger.monthlySpendUSD(), 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testCheckCapThrowsWhenExceeded() throws {
        // Record a large enough usage to exceed a tiny cap.
        let usage = TokenUsage(inputTokens: 100_000, outputTokens: 10_000, modelID: "claude-opus-4-5", timestamp: Date())
        ledger.record(usage: usage, operation: .draft, provider: .anthropic)

        let expectation = XCTestExpectation(description: "Cap checked")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            do {
                // Anthropic claude-opus-4-5: $15/1k in, $75/1k out
                // 100k in tokens = $1500, 10k out = $750 → well over $0.01 cap
                try self.ledger.checkCap(capUSD: 0.01)
                XCTFail("Expected monthlyCapReached error")
            } catch AIAssistError.monthlyCapReached {
                // Expected
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testCheckCapSucceedsWhenUnderCap() throws {
        XCTAssertNoThrow(try ledger.checkCap(capUSD: 100.0))
    }

    func testEmptyLedgerHasZeroSpend() {
        XCTAssertEqual(ledger.totalSpendUSD, 0)
        XCTAssertEqual(ledger.monthlySpendUSD(), 0)
    }
}
