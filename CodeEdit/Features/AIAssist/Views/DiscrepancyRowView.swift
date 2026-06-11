//
//  DiscrepancyRowView.swift
//  CodeEdit
//
//  ADR-0007 §6 — one row in the cross-check discrepancy list.
//

import SwiftUI

/// Renders one discrepancy from a Cross-check result.
///
/// Each row shows the claim excerpt, kind badge (contradicts / unsupported / stale),
/// the evidence chip, and dismiss / flag-as-linked-issue actions.
struct DiscrepancyRowView: View {

    let discrepancy: Discrepancy
    var onNavigateToEvidence: ((NodeRef) -> Void)?
    var onDismiss: ((Discrepancy) -> Void)?
    var onFlag: ((Discrepancy) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Claim
            Text("\u{201C}\(discrepancy.claimExcerpt)\u{201D}")
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)

            HStack(alignment: .center, spacing: 8) {
                kindBadge

                Text("vs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GroundingChipView(ref: discrepancy.evidenceRef, onTap: onNavigateToEvidence)

                Spacer()

                // Dismiss
                Button {
                    onDismiss?(discrepancy)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Dismiss")

                // Flag as issue
                Button {
                    onFlag?(discrepancy)
                } label: {
                    Image(systemName: "flag")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .help("Flag as linked issue")
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var kindBadge: some View {
        Text(discrepancy.kind.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(discrepancy.kind.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(discrepancy.kind.color.opacity(0.12), in: Capsule())
    }
}

private extension DiscrepancyKind {
    var label: String {
        switch self {
        case .contradicts:  return "Contradicts"
        case .unsupported:  return "Unsupported"
        case .stale:        return "Stale"
        }
    }

    var color: Color {
        switch self {
        case .contradicts:  return .red
        case .unsupported:  return .orange
        case .stale:        return .secondary
        }
    }
}
