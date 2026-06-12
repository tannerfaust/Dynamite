//
//  BoardCardView.swift
//  CodeEdit
//

import SwiftUI

/// Editable card with optional typed link chips and drag-to-reorder support.
struct BoardCardView: View {
    @Binding var card: CanvasCard
    var accent: Color = .accentColor
    var onCommit: () -> Void
    var onNavigateLink: ((ProductArtifact.ArtifactLink) -> Void)?

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.quaternary)
                    .padding(.top, 3)
                TextField("Card", text: $card.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .lineLimit(1...6)
                    .onSubmit(onCommit)
            }

            if !card.links.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(card.links) { link in
                        LinkChipView(
                            link: link,
                            onTap: { onNavigateLink?(link) },
                            onDelete: {
                                card.links.removeAll { $0.id == link.id }
                                onCommit()
                            }
                        )
                    }
                }
            }

            Button {
                card.links.append(.init(rel: "relates-to", to: "", label: nil))
                onCommit()
            } label: {
                Label("Add link", systemImage: "link.badge.plus")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isTargeted ? accent : Color.primary.opacity(0.08), lineWidth: isTargeted ? 1.5 : 0.5)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first, id == card.id.uuidString else { return false }
            isTargeted = false
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .draggable(card.id.uuidString)
    }
}

/// Simple left-to-right wrapping layout for link chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if offsetX + size.width > width, offsetX > 0 {
                offsetX = 0
                offsetY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            offsetX += size.width + spacing
        }
        return CGSize(width: width, height: offsetY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var offsetX = bounds.minX
        var offsetY = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if offsetX + size.width > bounds.maxX, offsetX > bounds.minX {
                offsetX = bounds.minX
                offsetY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: offsetX, y: offsetY), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            offsetX += size.width + spacing
        }
    }
}
