//
//  SpendLedger.swift
//  CodeEdit
//
//  ADR-0007 §4 — local per-project spend log.
//  Persists token usage events to `.dynamite/spend.json`.
//

import Foundation

/// Records AI spend events per workspace and enforces the monthly soft cap.
///
/// Thread-safe: all mutations are dispatched to a dedicated serial queue.
final class SpendLedger {

    // MARK: - Stored entry

    struct Entry: Codable {
        let timestamp: Date
        let provider: AIProviderID
        let operation: AssistOperation
        let inputTokens: Int
        let outputTokens: Int
        let costUSD: Double
    }

    // MARK: - State

    private(set) var entries: [Entry] = []
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.dynamite.aiassist.spendledger", qos: .utility)

    // MARK: - Init

    init(workspaceURL: URL) {
        let dir = workspaceURL.appendingPathComponent(".dynamite")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("spend.json")
        self.entries = Self.load(from: fileURL)
    }

    // MARK: - API

    /// Records one `TokenUsage` event.
    func record(usage: TokenUsage, operation: AssistOperation, provider: AIProviderID) {
        let cost = ModelPriceTable.cost(usage: usage, provider: provider)
        let entry = Entry(
            timestamp:    usage.timestamp,
            provider:     provider,
            operation:    operation,
            inputTokens:  usage.inputTokens,
            outputTokens: usage.outputTokens,
            costUSD:      cost
        )
        queue.async { [weak self] in
            guard let self else { return }
            self.entries.append(entry)
            self.persist()
        }
    }

    /// Total spend (all time) in USD.
    var totalSpendUSD: Double { entries.reduce(0) { $0 + $1.costUSD } }

    /// Spend in the current calendar month.
    func monthlySpendUSD() -> Double {
        let calendar = Calendar.current
        let now = Date()
        return entries
            .filter { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.costUSD }
    }

    /// Returns an error if the monthly cap would be exceeded.
    func checkCap(capUSD: Double) throws {
        let current = monthlySpendUSD()
        if current >= capUSD {
            throw AIAssistError.monthlyCapReached(spendUSD: current, capUSD: capUSD)
        }
    }

    // MARK: - Persistence

    private static func load(from url: URL) -> [Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
