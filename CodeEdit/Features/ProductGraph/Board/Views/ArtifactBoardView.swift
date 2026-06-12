//
//  ArtifactBoardView.swift
//  CodeEdit
//

import SwiftUI

/// Dispatches to the correct native board view for a canvas artifact kind.
struct ArtifactBoardView: View {
    @Binding var artifact: ProductArtifact
    var onCommit: () -> Void
    var onNavigateLink: ((ProductArtifact.ArtifactLink) -> Void)?

    @State private var canvasDocument: CanvasDocument = .init()
    @State private var treeNodes: [CanvasTreeNode] = []

    var body: some View {
        Group {
            switch artifact.kind {
            case .vpc, .bmc, .leanCanvas:
                BlockGridBoardView(
                    kind: artifact.kind!,
                    document: $canvasDocument,
                    onCommit: commitCanvas,
                    onNavigateLink: onNavigateLink
                )
            case .journey:
                JourneyBoardView(
                    document: $canvasDocument,
                    onCommit: commitCanvas,
                    onNavigateLink: onNavigateLink
                )
            case .storyMap:
                StoryMapBoardView(
                    document: $canvasDocument,
                    onCommit: commitCanvas,
                    onNavigateLink: onNavigateLink
                )
            case .ost:
                OSTBoardView(
                    nodes: $treeNodes,
                    title: canvasDocument.title,
                    onCommit: commitTree,
                    onNavigateLink: onNavigateLink
                )
            default:
                Text("No board view for this kind.")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: loadFromBody)
        .onChange(of: artifact.body) { _, _ in loadFromBody() }
    }

    private func loadFromBody() {
        guard let kind = artifact.kind else { return }
        if kind == .ost {
            treeNodes = CanvasBodyParser.parseTree(artifact.body)
            canvasDocument = CanvasBodyParser.parse(artifact.body)
        } else {
            let parsed = CanvasBodyParser.parse(artifact.body)
            canvasDocument = kind.normalizedCanvasDocument(from: parsed)
        }
    }

    private func commitCanvas() {
        guard let kind = artifact.kind else { return }
        artifact.body = CanvasBodyParser.serialize(canvasDocument)
        if !canvasDocument.title.isEmpty {
            artifact.title = canvasDocument.title
        }
        _ = kind // normalized layout preserved in sections
        onCommit()
    }

    private func commitTree() {
        artifact.body = CanvasBodyParser.serializeTree(treeNodes, title: canvasDocument.title)
        onCommit()
    }
}
