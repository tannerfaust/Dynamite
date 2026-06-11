//
//  CockpitSurface.swift
//  CodeEdit
//

import SwiftUI

/// A surface that can be registered in the Cockpit view's sidebar navigation.
///
/// Surfaces register via `CockpitSurfaceRegistry`. Phase 1 surfaces (Studio, Product Map) are
/// added as separate feature registrations starting in T1.6+. The `CockpitRootView` renders
/// whatever surfaces the registry holds, so adding a new surface is a registration, not a
/// layout change (same pattern as `NavigatorTab` / `InspectorTab` in the IDE view).
protocol CockpitSurface: Identifiable where ID == String {
    /// Stable identifier used in `WorkspaceStateKey.cockpitSelectedSurface` and deep-link routes.
    var id: String { get }

    /// Human-readable display name shown in the sidebar.
    var title: String { get }

    /// SF Symbol name for the sidebar icon.
    var systemImage: String { get }

    /// The surface's root view, erased to `AnyView` so mixed surface types can be stored together.
    var body: AnyView { get }
}
