// swiftlint:disable identifier_name pattern_matching_keywords
//
//  AIAssistService.swift
//  CodeEdit
//
//  ADR-0007 §1, §2 — protocol definitions.
//

import Foundation

// MARK: - AIAssistService

/// The **only** path to AI providers in the codebase (ADR-0007 §1).
///
/// Single request → streamed response. Stateless by construction:
/// - No conversation object.
/// - No tool schema exposed to the provider.
/// - No background/queued calls — every call is user-initiated.
///
/// Concrete implementation: `LiveAIAssistService`.
/// Testable stub: `MockAIAssistService`.
protocol AIAssistService: AnyObject {
    /// Stream a single AI request. The stream emits `.delta` chunks, a final `.usage` event,
    /// then `.done`. Throws if the provider is unavailable or the request violates a budget.
    func run(_ request: AssistRequest) -> AsyncThrowingStream<AssistEvent, Error>

    /// Pre-flight cost estimate — pure computation, no network call.
    func estimate(_ request: AssistRequest) -> CostEstimate
}

// MARK: - AIProvider

/// Abstraction over a single AI backend (Anthropic / OpenAI / Google).
///
/// Features must NOT import provider SDKs directly. All SDK usage is restricted
/// to concrete `AIProvider` implementations inside `Features/AIAssist/Providers/`.
protocol AIProvider: AnyObject {
    var id: AIProviderID { get }
    var displayName: String { get }

    /// Stream a raw completion. System prompt + messages are assembled by `LiveAIAssistService`
    /// from the `AssistRequest` + `PromptTemplate`. The provider must NOT receive tool schemas.
    func stream(
        systemPrompt: String,
        userMessage: String,
        modelID: String,
        maxOutputTokens: Int
    ) -> AsyncThrowingStream<ProviderEvent, Error>

    /// Approximate cost per 1k tokens for the given model (may be 0 if unknown).
    func costPer1kTokens(modelID: String) -> (input: Double, output: Double)
}

// MARK: - Provider ID & Events

enum AIProviderID: String, Codable, CaseIterable {
    case anthropic
    case openAI = "openai"
    case google

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openAI:    return "OpenAI (GPT)"
        case .google:    return "Google (Gemini)"
        }
    }
}

/// Low-level events emitted by an `AIProvider` stream, mapped to `AssistEvent` upstream.
enum ProviderEvent {
    case token(String)
    case usage(inputTokens: Int, outputTokens: Int, modelID: String)
    case done
}

// MARK: - Errors

enum AIAssistError: LocalizedError {
    case noAPIKey(provider: AIProviderID)
    case budgetExceeded(estimatedTokens: Int, cap: Int)
    case monthlyCapReached(spendUSD: Double, capUSD: Double)
    case providerError(message: String)
    case noProviderConfigured

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let p):
            return "No API key configured for \(p.displayName). Add one in Settings → AI Assist."
        case .budgetExceeded(let est, let cap):
            return "Context too large: ~\(est) tokens exceeds the \(cap)-token input cap."
        case .monthlyCapReached(let spend, let cap):
            return String(format: "Monthly spend cap reached (%.2f / %.2f USD).", spend, cap)
        case .providerError(let msg):
            return "Provider error: \(msg)"
        case .noProviderConfigured:
            return "No AI provider configured. Set one up in Settings → AI Assist."
        }
    }
}
