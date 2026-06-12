// swiftlint:disable line_length
//
//  PromptTemplate.swift
//  CodeEdit
//
//  ADR-0007 §6 — per-operation system + user prompts.
//  All prompt text lives here. No tool schemas are produced (ADR-0007 §5).
//

import Foundation

/// Generates the system prompt and user message for a given `AssistRequest`.
enum PromptTemplate {

    // MARK: - Public API

    struct Prompt {
        let system: String
        let user: String
    }

    static func build(for request: AssistRequest) -> Prompt {
        switch request.operation {
        case .draft:      return draft(request)
        case .refine:     return refine(request)
        case .crossCheck: return crossCheck(request)
        case .summarize:  return summarize(request)
        case .extract:    return extract(request)
        case .narrate:    return narrate(request)
        }
    }

    // MARK: - Draft

    private static func draft(_ request: AssistRequest) -> Prompt {
        let system = """
        You are a product management expert helping to write a product artifact.
        Write clearly, concisely, and with precision. Follow the structure implied by \
        the artifact kind and linked context. Produce only the artifact body in \
        well-structured markdown — no preamble, no commentary.
        """

        var user = ""
        if !request.prompt.isEmpty {
            user += "Instruction: \(request.prompt)\n\n"
        }
        user += "Artifact to draft:\n\(bundleSummary(request.bundle))"
        return Prompt(system: system, user: user)
    }

    // MARK: - Refine

    private static func refine(_ request: AssistRequest) -> Prompt {
        let system = """
        You are a precise editor improving a section of a product artifact.
        Return ONLY the improved replacement text — nothing else, no explanation.
        Preserve the author's voice; make it tighter and clearer.
        """

        var user = ""
        if let selection = request.selection, !selection.isEmpty {
            user += "Selected text to refine:\n```\n\(selection)\n```\n\n"
        }
        if !request.prompt.isEmpty {
            user += "Refinement instruction: \(request.prompt)\n\n"
        }
        user += "Context:\n\(bundleSummary(request.bundle))"
        return Prompt(system: system, user: user)
    }

    // MARK: - Cross-check

    private static func crossCheck(_ request: AssistRequest) -> Prompt {
        let system = """
        You are a rigorous fact-checker for product artifacts.
        Your task: compare the artifact's claims against the provided evidence nodes.

        For each discrepancy, output a JSON array where every item has:
        - "claim": verbatim excerpt from the artifact (max 120 chars)
        - "evidenceId": the node ID of the contradicting/unsupporting evidence
        - "kind": one of "contradicts", "unsupported", "stale"
        - "explanation": one sentence

        Output ONLY the JSON array. If there are no discrepancies, output [].
        """

        let user = bundleSummary(request.bundle)
        return Prompt(system: system, user: user)
    }

    // MARK: - Summarize (Phase 2)

    private static func summarize(_ request: AssistRequest) -> Prompt {
        let system = "Summarise the following product artifact in 2–3 sentences."
        return Prompt(system: system, user: bundleSummary(request.bundle))
    }

    // MARK: - Extract (Phase 2)

    private static func extract(_ request: AssistRequest) -> Prompt {
        let system = """
        Extract structured insights from the interview transcript.
        Return a JSON object with keys: "painPoints", "jobs", "quotes" — each an array of strings.
        """
        return Prompt(system: system, user: bundleSummary(request.bundle))
    }

    // MARK: - Narrate (Phase 2)

    private static func narrate(_ request: AssistRequest) -> Prompt {
        let system = "Write a 2–3 sentence narrative summary of the following metrics update."
        return Prompt(system: system, user: bundleSummary(request.bundle))
    }

    // MARK: - Bundle Serialisation

    /// Converts a `ContextBundle` into the text block sent to the model.
    /// Deterministic order: focus → linked items by priority desc.
    private static func bundleSummary(_ bundle: ContextBundle) -> String {
        var parts: [String] = []

        parts.append("## Focus artifact: \(bundle.focus.ref.title ?? bundle.focus.ref.id) [\(bundle.focus.ref.kind)]\n\n\(bundle.focus.content)")

        let sorted = bundle.linkedItems.sorted { $0.priority > $1.priority }
        for item in sorted {
            let rel = item.edgeRel.map { " (\($0))" } ?? ""
            parts.append("## Linked: \(item.ref.title ?? item.ref.id) [\(item.ref.kind)]\(rel)\n\n\(item.content)")
        }

        if !bundle.droppedItems.isEmpty {
            let dropped = bundle.droppedItems.map { $0.ref.title ?? $0.ref.id }.joined(separator: ", ")
            parts.append("<!-- dropped due to budget: \(dropped) -->")
        }

        return parts.joined(separator: "\n\n---\n\n")
    }
}
