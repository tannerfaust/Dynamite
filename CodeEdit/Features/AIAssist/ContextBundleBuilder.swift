//
//  ContextBundleBuilder.swift
//  CodeEdit
//
//  ADR-0007 §3 — assembles a ContextBundle from the LinkIndex for a focus artifact.
//

import Foundation
import GRDB

/// Walks the `LinkIndexManager` from a focus artifact, filters linked nodes by
/// operation relevance, trims to budget, and returns a deterministic `ContextBundle`.
///
/// Deterministic assembly rule (ADR-0007 §3):
///   focus → linked edges sorted by (relevancePriority DESC, fileOrder ASC)
///
/// Trimming rule: items are dropped whole (never truncated mid-document),
/// lowest-priority first, until `estimatedTokens ≤ budget.maxInputTokens`.
final class ContextBundleBuilder {

    private let linkIndex: LinkIndexManager?
    private let workspaceURL: URL

    init(linkIndex: LinkIndexManager?, workspaceURL: URL) {
        self.linkIndex    = linkIndex
        self.workspaceURL = workspaceURL
    }

    // MARK: - Public

    func build(focus artifact: ProductArtifact, operation: AssistOperation, budget: TokenBudget) async -> ContextBundle {
        let focusItem = makeFocusItem(artifact)
        let linkedItems = await fetchLinkedItems(for: artifact, operation: operation)
        return trim(focus: focusItem, linked: linkedItems, budget: budget)
    }

    // MARK: - Focus Item

    private func makeFocusItem(_ artifact: ProductArtifact) -> ContextBundleItem {
        let ref = NodeRef(id: artifact.id, kind: artifact.kindString, title: artifact.displayTitle)
        return ContextBundleItem(
            id: artifact.id,
            ref: ref,
            edgeRel: nil,
            content: artifact.body,
            isEvidence: isEvidenceKind(artifact.kindString),
            priority: 100  // focus always highest priority
        )
    }

    // MARK: - Linked Items

    private func fetchLinkedItems(for artifact: ProductArtifact, operation: AssistOperation) async -> [ContextBundleItem] {
        guard let linkIndex else { return [] }
        // Fetch one-hop outgoing edges from the index.
        let edges: [LinkIndexEdge] = (try? await linkIndex.database.dbWriter.read { db in
            try LinkIndexEdge.fetchAll(db, sql: "SELECT * FROM edges WHERE srcId = ?", arguments: [artifact.id])
        }) ?? []

        var items: [ContextBundleItem] = []
        for edge in edges {
            guard edge.resolved else { continue }
            guard shouldInclude(edge: edge, for: operation) else { continue }

            guard let node = (try? await linkIndex.database.dbWriter.read { db in
                try LinkIndexNode.fetchOne(db, sql: "SELECT * FROM nodes WHERE id = ?", arguments: [edge.dstId])
            }) else { continue }

            let content = fileContent(for: node)
            let ref = NodeRef(id: node.id, kind: node.kind, title: node.title)
            let item = ContextBundleItem(
                id: node.id,
                ref: ref,
                edgeRel: edge.rel,
                content: content,
                isEvidence: isEvidenceKind(node.kind),
                priority: priority(for: edge.rel, operation: operation, fileOrder: edge.fileOrder)
            )
            items.append(item)
        }

        // Deterministic order: priority DESC, then fileOrder ASC (stable).
        return items.sorted { lhs, rhs in
            lhs.priority != rhs.priority ? lhs.priority > rhs.priority : lhs.id < rhs.id
        }
    }

    // MARK: - Relevance Filters

    /// `crossCheck` pulls only evidence-kind nodes via validates/contradicts edges.
    /// `draft` pulls personas/problems/assumptions via any edge.
    private func shouldInclude(edge: LinkIndexEdge, for operation: AssistOperation) -> Bool {
        switch operation {
        case .crossCheck:
            return ["validates", "contradicts", "supports", "informs"].contains(edge.rel)
        case .draft:
            return true  // all linked context is useful for drafting
        case .refine:
            return true  // context improves refinements
        case .summarize, .extract, .narrate:
            return true
        }
    }

    private func priority(for rel: String, operation: AssistOperation, fileOrder: Int) -> Int {
        // Evidence nodes rank higher in crossCheck; structural nodes rank higher in draft.
        let base: Int
        switch operation {
        case .crossCheck:
            base = ["validates", "contradicts"].contains(rel) ? 80 : 40
        case .draft:
            base = ["relates-to", "informs"].contains(rel) ? 70 : 50
        default:
            base = 50
        }
        // Small fileOrder penalty to achieve deterministic tie-break.
        return base - min(fileOrder, 20)
    }

    // MARK: - Budget Trimming (ADR-0007 §3)

    private func trim(focus: ContextBundleItem, linked: [ContextBundleItem], budget: TokenBudget) -> ContextBundle {
        var included = linked
        var dropped: [ContextBundleItem] = []

        // Estimate chars/4 per ADR-0007 §4.
        func estimatedTokens() -> Int {
            let chars = focus.content.count + included.reduce(0) { $0 + $1.content.count }
            return max(1, chars / 4)
        }

        // Drop lowest-priority items whole until we fit.
        while estimatedTokens() > budget.maxInputTokens, !included.isEmpty {
            // included is already sorted priority DESC → drop from end.
            let dropped_ = included.removeLast()
            dropped.append(dropped_)
        }

        return ContextBundle(focus: focus, linkedItems: included, droppedItems: dropped)
    }

    // MARK: - Helpers

    private func isEvidenceKind(_ kind: String) -> Bool {
        ["interview", "feedback", "insight", "assumption", "research-note"].contains(kind)
    }

    private func fileContent(for node: LinkIndexNode) -> String {
        let url = workspaceURL.appendingPathComponent(node.path)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
