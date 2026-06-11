//
//  KindBadge.swift
//  CodeEdit
//

import SwiftUI
import AppKit

/// Compact category-colored capsule showing the artifact kind abbreviation.
///
/// `size: .regular` is used in the Studio artifact list.
/// `size: .compact` is used in the file tree and quick-open results.
struct KindBadge: View {
    let kind: ArtifactKind?
    let kindString: String

    enum BadgeSize {
        case regular, compact

        var fontSize: CGFloat { self == .regular ? 9.5 : 8.0 }
        var hPad: CGFloat { self == .regular ? 5 : 4 }
        var vPad: CGFloat { self == .regular ? 2 : 1 }
    }
    var size: BadgeSize = .regular

    private var label: String {
        kind?.shortName ?? String(kindString.prefix(4)).uppercased()
    }

    private var color: Color {
        Color(nsColor: kind?.categoryColor ?? .systemGray)
    }

    var body: some View {
        Text(label)
            .font(.system(size: size.fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, size.hPad)
            .padding(.vertical, size.vPad)
            .background(color, in: Capsule())
    }
}

/// Pill-shaped status indicator with per-state color semantics.
struct StatusBadge: View {
    let status: String

    private var color: Color {
        switch status {
        case "active", "accepted", "validated":
            return Color(nsColor: .systemGreen)
        case "draft", "proposed", "planned", "untested":
            return Color(nsColor: .systemGray)
        case "superseded", "archived", "falsified":
            return Color(nsColor: .systemRed).opacity(0.8)
        case "validating", "running":
            return Color(nsColor: .systemYellow)
        case "concluded":
            return Color(nsColor: .systemTeal)
        default:
            return Color(nsColor: .systemGray)
        }
    }

    var body: some View {
        Text(status)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 0.5))
    }
}
