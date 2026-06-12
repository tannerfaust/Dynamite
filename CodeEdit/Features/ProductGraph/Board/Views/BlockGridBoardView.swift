//
//  BlockGridBoardView.swift
//  CodeEdit
//

import SwiftUI

/// Shared block-grid renderer for VPC, BMC, and Lean Canvas layouts.
struct BlockGridBoardView: View {
    let kind: ArtifactKind
    @Binding var document: CanvasDocument
    var onCommit: () -> Void
    var onNavigateLink: ((ProductArtifact.ArtifactLink) -> Void)?

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            gridContent
                .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder private var gridContent: some View {
        switch kind {
        case .vpc:
            vpcGrid
        case .bmc:
            bmcGrid
        case .leanCanvas:
            leanGrid
        default:
            genericGrid
        }
    }

    private var genericGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(sectionIndices, id: \.self) { index in
                block(at: index)
            }
        }
        .frame(minWidth: 900)
    }

    private var vpcGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                block(at: 0).frame(width: 220)
                VStack(spacing: 12) {
                    block(at: 1)
                    block(at: 2)
                }
                .frame(width: 220)
            }
            HStack(spacing: 12) {
                block(at: 3).frame(width: 220)
                block(at: 4)
                block(at: 5)
            }
        }
        .frame(minWidth: 900)
    }

    private var bmcGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                block(at: 0).frame(width: 180)
                block(at: 1).frame(width: 180)
                block(at: 2).frame(width: 180)
                block(at: 3).frame(width: 180)
                block(at: 4).frame(width: 180)
            }
            HStack(spacing: 12) {
                block(at: 5).frame(width: 220)
                block(at: 6).frame(width: 220)
                block(at: 7).frame(width: 220)
                block(at: 8).frame(width: 220)
            }
        }
        .frame(minWidth: 980)
    }

    private var leanGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                block(at: 0).frame(width: 200)
                block(at: 1).frame(width: 200)
                block(at: 2).frame(width: 240)
                block(at: 3).frame(width: 200)
                block(at: 4).frame(width: 200)
            }
            HStack(spacing: 12) {
                block(at: 5).frame(width: 200)
                block(at: 6).frame(width: 200)
                block(at: 7).frame(width: 240)
                block(at: 8).frame(width: 200)
            }
        }
        .frame(minWidth: 1100)
    }

    private var sectionIndices: [Int] {
        Array(document.sections.indices)
    }

    /// The first body evaluation can run before `ArtifactBoardView.loadFromBody()` populates
    /// the document, so fixed layouts (which hardcode indices 0…8) must tolerate a short or
    /// empty sections array instead of crashing on subscript.
    @ViewBuilder
    private func block(at index: Int) -> some View {
        if document.sections.indices.contains(index) {
            BoardBlockView(
                title: document.sections[index].heading,
                guidance: document.sections[index].guidance,
                cards: $document.sections[index].cards,
                accent: Color(nsColor: kind.categoryColor),
                onCommit: onCommit,
                onNavigateLink: onNavigateLink
            )
            .frame(minHeight: 160)
        } else {
            Color.clear.frame(minHeight: 160)
        }
    }
}
