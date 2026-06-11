//
//  LiveAIAssistService.swift
//  CodeEdit
//
//  ADR-0007 §1 — concrete AIAssistService implementation.
//

import Foundation

/// Production implementation of `AIAssistService`.
///
/// Single request → streamed response. Stateless: no conversation object, no queued calls.
/// The no-agent invariant is enforced by `PromptTemplate` (no tool schema produced) and
/// `AIProvider` (no tool parameters sent to provider).
final class LiveAIAssistService: AIAssistService {

    private let settings: AIAssistSettings
    private let spendLedger: SpendLedger

    init(settings: AIAssistSettings, spendLedger: SpendLedger) {
        self.settings    = settings
        self.spendLedger = spendLedger
    }

    // MARK: - AIAssistService

    func run(_ request: AssistRequest) -> AsyncThrowingStream<AssistEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let provider = try AIProviderRegistry.provider(for: settings)

                    // Pre-flight budget check.
                    let est = self.estimate(request)
                    if est.estimatedInputTokens > request.budget.maxInputTokens {
                        throw AIAssistError.budgetExceeded(
                            estimatedTokens: est.estimatedInputTokens,
                            cap: request.budget.maxInputTokens
                        )
                    }

                    // Monthly cap check.
                    try spendLedger.checkCap(capUSD: settings.monthlyCapUSD)

                    let modelID = settings.modelID(for: request.operation, provider: provider.id)
                    let prompt  = PromptTemplate.build(for: request)

                    var accumulated = ""

                    let providerStream = provider.stream(
                        systemPrompt: prompt.system,
                        userMessage:  prompt.user,
                        modelID:      modelID,
                        maxOutputTokens: request.budget.maxOutputTokens
                    )

                    for try await event in providerStream {
                        switch event {
                        case .token(let text):
                            accumulated += text
                            continuation.yield(.delta(text))

                        case .usage(let inputTokens, let outputTokens, let mid):
                            let usage = TokenUsage(
                                inputTokens:  inputTokens,
                                outputTokens: outputTokens,
                                modelID:      mid,
                                timestamp:    Date()
                            )
                            continuation.yield(.usage(usage))
                            spendLedger.record(usage: usage, operation: request.operation, provider: provider.id)

                        case .done:
                            let result = assemble(text: accumulated, request: request)
                            continuation.yield(.done(result))
                            continuation.finish()
                            return
                        }
                    }

                    // Stream ended without .done (shouldn't happen but guard anyway).
                    let result = assemble(text: accumulated, request: request)
                    continuation.yield(.done(result))
                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func estimate(_ request: AssistRequest) -> CostEstimate {
        let inputTokens  = request.bundle.estimatedTokens
        let outputTokens = request.budget.maxOutputTokens

        guard let providerID = settings.activeProvider else {
            return CostEstimate(estimatedInputTokens: inputTokens, maxOutputTokens: outputTokens, estimatedUSD: 0)
        }

        let modelID = settings.modelID(for: request.operation, provider: providerID)
        let rates: (input: Double, output: Double)
        switch providerID {
        case .anthropic: rates = ModelPriceTable.anthropic(modelID: modelID)
        case .openAI:    rates = ModelPriceTable.openAI(modelID: modelID)
        case .google:    rates = ModelPriceTable.google(modelID: modelID)
        }

        let usd = Double(inputTokens) / 1_000.0 * rates.input
                + Double(outputTokens) / 1_000.0 * rates.output
        return CostEstimate(estimatedInputTokens: inputTokens, maxOutputTokens: outputTokens, estimatedUSD: usd)
    }

    // MARK: - Result Assembly

    private func assemble(text: String, request: AssistRequest) -> AssistResult {
        // All linked items that were included are grounding refs.
        let groundingRefs = request.bundle.allIncludedItems.map { $0.ref }

        // Parse discrepancies from JSON for crossCheck.
        let discrepancies: [Discrepancy]?
        if request.operation == .crossCheck {
            discrepancies = parseDiscrepancies(from: text, bundle: request.bundle)
        } else {
            discrepancies = nil
        }

        return AssistResult(text: text, groundingRefs: groundingRefs, discrepancies: discrepancies)
    }

    // MARK: - Cross-check Discrepancy Parser

    private func parseDiscrepancies(from json: String, bundle: ContextBundle) -> [Discrepancy] {
        // Extract the JSON array — the model might wrap it in a markdown fence.
        let stripped = extractJSONArray(from: json)
        guard
            let data = stripped.data(using: .utf8),
            let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        return array.compactMap { obj -> Discrepancy? in
            guard
                let claim       = obj["claim"] as? String,
                let evidenceID  = obj["evidenceId"] as? String,
                let kindRaw     = obj["kind"] as? String,
                let kind        = DiscrepancyKind(rawValue: kindRaw)
            else { return nil }

            let evidenceNode = bundle.linkedItems.first { $0.id == evidenceID }
            let ref = evidenceNode?.ref ?? NodeRef(id: evidenceID, kind: "unknown", title: nil)
            return Discrepancy(claimExcerpt: claim, evidenceRef: ref, kind: kind)
        }
    }

    private func extractJSONArray(from text: String) -> String {
        // Strip markdown fences if present.
        if let start = text.range(of: "["), let end = text.range(of: "]", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return text
    }
}
