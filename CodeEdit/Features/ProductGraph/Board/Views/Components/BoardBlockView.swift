//
//  BoardBlockView.swift
//  CodeEdit
//

import SwiftUI

/// A labeled canvas block (H2 section) containing draggable cards.
struct BoardBlockView: View {
    let title: String
    let guidance: String
    @Binding var cards: [CanvasCard]
    var accent: Color = .accentColor
    var onCommit: () -> Void
    var onNavigateLink: ((ProductArtifact.ArtifactLink) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if !guidance.isEmpty {
                    Text(guidance)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            List {
                ForEach($cards) { $card in
                    BoardCardView(
                        card: $card,
                        accent: accent,
                        onCommit: onCommit,
                        onNavigateLink: onNavigateLink
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: moveCards)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(minHeight: CGFloat(max(cards.count, 1)) * 72)

            addCardButton
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(accent.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var addCardButton: some View {
        Button {
            cards.append(CanvasCard(text: ""))
            onCommit()
        } label: {
            Label("Add card", systemImage: "plus")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    private func moveCards(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
        onCommit()
    }
}
