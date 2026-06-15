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
    /// The Product Studio — Dynamite's product-ownership environment.
    case studio = "cockpit"

    /// Ground Control — the CodeEdit-powered code review, terminal, and agent-supervision environment.
    case groundControl = "ide"

    /// Builds a mode from saved workspace state or a route segment.
    ///
    /// Accepts both the old storage values (`cockpit`, `ide`) and the current product names
    /// (`studio`, `ground-control`) so deep links can use the clearer language without a
    /// workspace-state migration.
    init?(legacyOrRouteValue value: String) {
        switch value {
        case "cockpit", "studio", "product-studio":
            self = .studio
        case "ide", "ground-control", "groundControl", "ground":
            self = .groundControl
        default:
            return nil
        }
    }

    /// Builds a mode from saved workspace state.
    ///
    /// Old Phase-B builds saved `ide` because the inherited editor was the dev default. Treat that
    /// stale value as Product Studio so existing workspaces migrate into the new product-first
    /// default. Future explicit Ground Control selections are stored as `ground-control`.
    init?(workspaceStateValue value: String) {
        switch value {
        case "cockpit", "studio", "product-studio", "ide":
            self = .studio
        case "ground-control", "groundControl", "ground":
            self = .groundControl
        default:
            return nil
        }
    }

    /// URL route segment for new links. `rawValue` remains the legacy storage value.
    var routeValue: String {
        switch self {
        case .studio: return "studio"
        case .groundControl: return "ground-control"
        }
    }

    /// Human-readable display name for toolbar labels and menu items.
    var displayName: String {
        switch self {
        case .studio: return "Product Studio"
        case .groundControl: return "Ground Control"
        }
    }

    /// SF Symbol name for toolbar icons and Picker tags.
    var systemImage: String {
        switch self {
        case .studio: return "square.grid.2x2"
        case .groundControl: return "terminal"
        }
    }
}
