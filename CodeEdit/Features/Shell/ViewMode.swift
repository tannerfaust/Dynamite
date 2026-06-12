//
//  ViewMode.swift
//  CodeEdit
//

import Foundation

/// The top-level view mode for a Dynamite workspace window.
///
/// Each window remembers its mode per project via `WorkspaceStateKey.viewMode`.
/// Two windows on the same workspace may show different modes simultaneously (per ADR-0006).
enum ViewMode: String, Codable, Equatable, Hashable, CaseIterable {
    /// The product ownership cockpit — Studio, canvases, Pulse, Ask the Product, ledgers.
    case cockpit

    /// The classic IDE layout (CodeEdit) with product-context toggles.
    case ide

    /// Human-readable display name for toolbar labels and menu items.
    var displayName: String {
        switch self {
        case .cockpit: return "Cockpit"
        case .ide: return "IDE"
        }
    }

    /// SF Symbol name for toolbar icons and Picker tags.
    var systemImage: String {
        switch self {
        case .cockpit: return "square.grid.2x2.fill"
        case .ide: return "curlybraces"
        }
    }
}
