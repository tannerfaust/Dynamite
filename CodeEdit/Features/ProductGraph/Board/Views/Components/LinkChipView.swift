//
//  LinkChipView.swift
//  CodeEdit
//

import SwiftUI

/// Compact chip for a typed front-matter or card-level link.
struct LinkChipView: View {
    let link: ProductArtifact.ArtifactLink
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            Text(link.rel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(link.label?.isEmpty == false ? (link.label ?? link.to) : link.to)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
            if onDelete != nil {
                Button(
                    action: { onDelete?() },
                    label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                    }
                )
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.accentColor.opacity(0.10)))
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 0.5))
        .onTapGesture { onTap?() }
        .help("\(link.rel) → \(link.to)")
    }
}
