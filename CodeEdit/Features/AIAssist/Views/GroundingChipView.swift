//
//  GroundingChipView.swift
//  CodeEdit
//
//  ADR-0007 §6 — single grounding-source chip shown under AI results.
//

import SwiftUI

/// A compact pill that represents one grounding source in an AIAssist result.
///
/// Tapping navigates to the node (via `onTap`).
struct GroundingChipView: View {

    let ref: NodeRef
    var onTap: ((NodeRef) -> Void)?

    var body: some View {
        Button {
            onTap?(ref)
        } label: {
            HStack(spacing: 4) {
                kindIcon
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(ref.title ?? ref.id)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var kindIcon: some View {
        if let sfSymbol = systemImage(for: ref.kind) {
            Image(systemName: sfSymbol)
        } else {
            Image(systemName: "doc")
        }
    }

    private func systemImage(for kind: String) -> String? {
        ArtifactKind.from(kind)?.systemImage
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HStack {
        GroundingChipView(ref: NodeRef(id: "int-001", kind: "interview", title: "User interview #3"))
        GroundingChipView(ref: NodeRef(id: "ins-002", kind: "insight", title: "Insight: Setup friction"))
    }
    .padding()
}
#endif
