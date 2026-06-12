//
//  OSTBoardView.swift
//  CodeEdit
//

import SwiftUI

/// Tree board for opportunity solution trees (outcome → opportunity → solution → experiment).
struct OSTBoardView: View {
    @Binding var nodes: [CanvasTreeNode]
    var title: String
    var onCommit: () -> Void
    var onNavigateLink: ((ProductArtifact.ArtifactLink) -> Void)?

    private let levelLabels = ["Outcome", "Opportunity", "Solution", "Experiment"]

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                if nodes.isEmpty {
                    emptyState
                } else {
                    ForEach($nodes) { $node in
                        TreeNodeColumn(
                            node: $node,
                            depth: 0,
                            levelLabels: levelLabels,
                            onCommit: onCommit,
                            onNavigateLink: onNavigateLink
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No outcomes yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("Add outcome") {
                nodes.append(CanvasTreeNode(text: ""))
                onCommit()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

private struct TreeNodeColumn: View {
    @Binding var node: CanvasTreeNode
    let depth: Int
    let levelLabels: [String]
    var onCommit: () -> Void
    var onNavigateLink: ((ProductArtifact.ArtifactLink) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            nodeCard

            if !node.children.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($node.children) { $child in
                        TreeNodeColumn(
                            node: $child,
                            depth: depth + 1,
                            levelLabels: levelLabels,
                            onCommit: onCommit,
                            onNavigateLink: onNavigateLink
                        )
                    }
                }
            } else if depth < levelLabels.count - 1 {
                addChildButton
            }
        }
    }

    private var nodeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(levelLabels[safe: depth] ?? "Node")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            BoardCardView(
                card: Binding(
                    get: {
                        CanvasCard(id: node.id, text: node.text, links: node.links)
                    },
                    set: { updated in
                        node.text = updated.text
                        node.links = updated.links
                    }
                ),
                accent: ostAccent(depth: depth),
                onCommit: onCommit,
                onNavigateLink: onNavigateLink
            )
            .frame(width: 220)
        }
    }

    private var addChildButton: some View {
        Button {
            let label = levelLabels[safe: depth + 1] ?? "Child"
            node.children.append(CanvasTreeNode(text: "New \(label.lowercased())"))
            onCommit()
        } label: {
            Label("Add \(levelLabels[safe: depth + 1]?.lowercased() ?? "child")", systemImage: "plus")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
    }

    private func ostAccent(depth: Int) -> Color {
        switch depth {
        case 0: return .indigo
        case 1: return .purple
        case 2: return .blue
        default: return .teal
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
