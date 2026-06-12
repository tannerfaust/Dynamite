// swiftlint:disable identifier_name
//
//  AIAssistSettings.swift
//  CodeEdit
//
//  ADR-0007 §2, §4 — user-configurable provider and budget settings.
//  API keys are stored in the macOS Keychain, NOT in this struct.
//

import Foundation

/// User-facing AIAssist configuration, persisted as part of `SettingsData`.
///
/// API keys are stored via `AIKeychainStore` and referenced here only by the
/// provider ID. This struct is intentionally Codable and written to disk; it
/// must never contain secrets.
struct AIAssistSettings: Codable, Hashable {

    // MARK: - Provider

    /// The currently active provider. Nil = feature disabled / no key set.
    var activeProvider: AIProviderID?

    // MARK: - Model Tiers

    /// Overridable model ID per operation. Nil = use the provider's default tier.
    var modelOverrides: [String: String] = [:]  // keyed by AssistOperation.rawValue

    // MARK: - Token Budgets

    /// Per-operation input token cap (overrides the ADR-0007 §4 defaults).
    var inputTokenCaps: [String: Int] = [:]     // keyed by AssistOperation.rawValue

    /// Per-operation output token cap.
    var outputTokenCaps: [String: Int] = [:]

    // MARK: - Spend Controls

    /// Soft monthly spend cap in USD. Default: $5.
    var monthlyCapUSD: Double = 5.0

    // MARK: - Helpers

    func tokenBudget(for operation: AssistOperation) -> TokenBudget {
        let defaultBudget = TokenBudget.default(for: operation)
        let inputCap  = inputTokenCaps[operation.rawValue]  ?? defaultBudget.maxInputTokens
        let outputCap = outputTokenCaps[operation.rawValue] ?? defaultBudget.maxOutputTokens
        return TokenBudget(maxInputTokens: inputCap, maxOutputTokens: outputCap)
    }

    func modelID(for operation: AssistOperation, provider: AIProviderID) -> String {
        if let override = modelOverrides[operation.rawValue] { return override }
        return defaultModelID(for: operation, provider: provider)
    }

    // MARK: - Default Model Tiers

    /// Cheap tier for refine/narrate; capable tier for draft/crossCheck/extract.
    private func defaultModelID(for operation: AssistOperation, provider: AIProviderID) -> String {
        let isCheap: Bool
        switch operation {
        case .refine, .narrate: isCheap = true
        default:                isCheap = false
        }

        switch provider {
        case .anthropic:
            return isCheap ? "claude-haiku-4-5" : "claude-sonnet-4-5"
        case .openAI:
            return isCheap ? "gpt-4o-mini" : "gpt-4o"
        case .google:
            return isCheap ? "gemini-2.0-flash" : "gemini-2.5-pro"
        }
    }

    // MARK: - Codable (decodeIfPresent pattern — same as SettingsData)

    private enum CodingKeys: String, CodingKey {
        case activeProvider, modelOverrides, inputTokenCaps, outputTokenCaps, monthlyCapUSD
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activeProvider   = try c.decodeIfPresent(AIProviderID.self, forKey: .activeProvider)
        modelOverrides   = try c.decodeIfPresent([String: String].self, forKey: .modelOverrides)   ?? [:]
        inputTokenCaps   = try c.decodeIfPresent([String: Int].self, forKey: .inputTokenCaps)   ?? [:]
        outputTokenCaps  = try c.decodeIfPresent([String: Int].self, forKey: .outputTokenCaps)  ?? [:]
        monthlyCapUSD    = try c.decodeIfPresent(Double.self, forKey: .monthlyCapUSD)    ?? 5.0
    }

    // MARK: Search Keys (for Settings search)
    var searchKeys: [String] {
        ["AI provider", "API key", "token budget", "spend cap", "monthly limit",
         "Claude", "GPT", "Gemini", "AI Assist", "draft", "refine", "cross-check"]
    }
}
