//
//  AssistModels.swift
//  CodeEdit
//
//  ADR-0007 §1 — value types for the AIAssist seam.
//  Single-file home for all data flowing through AIAssistService so imports stay
//  within Features/AIAssist (enforced by the SwiftLint custom rule described in ADR-0007 §5).
//

import Foundation

// MARK: - Operation

/// The closed set of AI operations AIAssist may perform.
///
/// Every new AI behavior must be expressed as a new case here and reviewed
/// against the no-agent rule (ADR-0007 §5) before shipping.
enum AssistOperation: String, Codable, CaseIterable {
    /// Generate content for an empty or partial artifact from a prompt + linked nodes.
    case draft
    /// Improve a user-selected text range per a natural-language instruction.
    case refine
    /// Compare artifact claims against linked evidence nodes; produce a discrepancy list.
    case crossCheck
    /// Summarise a node for X-Ray (Phase 2).
    case summarize
    /// Extract structured insights from an interview transcript (Phase 2).
    case extract
    /// Narrate a Pulse / Loop Ledger entry (Phase 2).
    case narrate
}

// MARK: - Request

/// Everything the service needs to perform one AI call. Fully assembled by the caller;
/// the service has no global state (ADR-0007 §1).
struct AssistRequest {
    let operation: AssistOperation
    /// Natural-language instruction from the user. May be empty for `.draft` when a
    /// kind template provides sufficient scaffolding.
    let prompt: String
    /// Grounding context — focus artifact + linked nodes (ADR-0007 §3).
    let bundle: ContextBundle
    /// Per-call token caps (ADR-0007 §4).
    let budget: TokenBudget
    /// Optional: verbatim text selection to refine (`.refine` operation only).
    let selection: String?

    init(
        operation: AssistOperation,
        prompt: String,
        bundle: ContextBundle,
        budget: TokenBudget,
        selection: String? = nil
    ) {
        self.operation = operation
        self.prompt = prompt
        self.bundle = bundle
        self.budget = budget
        self.selection = selection
    }
}

// MARK: - Events

/// Streamed events emitted by `AIAssistService.run(_:)`.
enum AssistEvent {
    /// A token chunk from the provider stream.
    case delta(String)
    /// Final usage accounting (emitted once, after the last delta).
    case usage(TokenUsage)
    /// Stream complete; carries the assembled `AssistResult`.
    case done(AssistResult)
}

// MARK: - Result

/// The assembled result of a completed AI call.
struct AssistResult {
    /// Full text produced by the model.
    let text: String
    /// Which bundle items materially informed the output.
    /// Displayed as grounding-source chips in the UI (ADR-0007 §6).
    let groundingRefs: [NodeRef]
    /// Non-nil and non-empty only for `.crossCheck` operations (ADR-0007 §6).
    let discrepancies: [Discrepancy]?
}

// MARK: - NodeRef

/// A lightweight pointer to a node in the product graph.
struct NodeRef: Identifiable, Hashable {
    let id: String       // matches `LinkIndexNode.id` / `ProductArtifact.id`
    let kind: String
    let title: String?
}

// MARK: - Discrepancy

/// One discrepancy row emitted by a `.crossCheck` result.
struct Discrepancy: Identifiable {
    let id: UUID
    /// Verbatim excerpt of the artifact claim under scrutiny.
    let claimExcerpt: String
    /// The evidence node this claim was checked against.
    let evidenceRef: NodeRef
    /// Relationship between claim and evidence.
    let kind: DiscrepancyKind

    init(id: UUID = UUID(), claimExcerpt: String, evidenceRef: NodeRef, kind: DiscrepancyKind) {
        self.id = id
        self.claimExcerpt = claimExcerpt
        self.evidenceRef = evidenceRef
        self.kind = kind
    }
}

enum DiscrepancyKind: String, Codable {
    /// Evidence explicitly contradicts the claim.
    case contradicts
    /// Claim is not supported by any linked evidence.
    case unsupported
    /// Evidence is outdated relative to the claim's context.
    case stale
}

// MARK: - ContextBundle

/// Assembled grounding context passed into every `AssistRequest` (ADR-0007 §3).
///
/// Built by `ContextBundleBuilder`; never mutated after construction.
struct ContextBundle {
    /// The artifact being assisted; always present.
    let focus: ContextBundleItem
    /// One-hop linked nodes, filtered and ordered by `ContextBundleBuilder`.
    let linkedItems: [ContextBundleItem]
    /// Items that were dropped during budget trimming (for UI disclosure).
    let droppedItems: [ContextBundleItem]

    var allIncludedItems: [ContextBundleItem] { [focus] + linkedItems }

    /// Approximate token count of the assembled context (chars / 4).
    var estimatedTokens: Int {
        let totalChars = allIncludedItems.reduce(0) { $0 + $1.content.count }
        return max(1, totalChars / 4)
    }
}

/// One item inside a `ContextBundle`.
struct ContextBundleItem: Identifiable {
    let id: String          // node ID
    let ref: NodeRef
    /// The edge relationship from the focus node (nil for the focus itself).
    let edgeRel: String?
    /// Full markdown body or a trimmed excerpt.
    let content: String
    /// Whether this item is an evidence-kind node (interview/feedback/insight/assumption).
    let isEvidence: Bool
    /// Priority for trimming (lower = dropped first).
    let priority: Int
}

// MARK: - Token Budget

/// Per-call token caps (ADR-0007 §4). Defaults supplied per operation by `TokenBudget.default(for:)`.
struct TokenBudget {
    let maxInputTokens: Int
    let maxOutputTokens: Int

    static func `default`(for operation: AssistOperation) -> TokenBudget {
        switch operation {
        case .draft:      return TokenBudget(maxInputTokens: 16_000, maxOutputTokens: 4_000)
        case .refine:     return TokenBudget(maxInputTokens:  4_000, maxOutputTokens: 1_000)
        case .crossCheck: return TokenBudget(maxInputTokens: 24_000, maxOutputTokens: 2_000)
        case .summarize:  return TokenBudget(maxInputTokens:  8_000, maxOutputTokens: 1_000)
        case .extract:    return TokenBudget(maxInputTokens: 16_000, maxOutputTokens: 2_000)
        case .narrate:    return TokenBudget(maxInputTokens:  4_000, maxOutputTokens:   500)
        }
    }
}

// MARK: - Usage & Cost

/// Token consumption reported by the provider after a completed call.
struct TokenUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let modelID: String
    let timestamp: Date

    var totalTokens: Int { inputTokens + outputTokens }
}

/// Pre-flight cost estimate shown to the user before the API call is made (ADR-0007 §4).
struct CostEstimate {
    /// Approximate number of input tokens given the assembled bundle.
    let estimatedInputTokens: Int
    /// Maximum output tokens from the budget.
    let maxOutputTokens: Int
    /// Estimated USD cost (may be 0 if pricing is unknown).
    let estimatedUSD: Double
    /// Human-readable string e.g. "≈ $0.03"
    var displayString: String {
        if estimatedUSD < 0.005 {
            return "< $0.01"
        }
        return String(format: "≈ $%.2f", estimatedUSD)
    }
}
