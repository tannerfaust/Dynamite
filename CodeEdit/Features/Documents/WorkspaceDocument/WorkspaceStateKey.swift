//
//  WorkspaceStateKey.swift
//  CodeEdit
//
//  Created by Khan Winter on 7/3/23.
//

enum WorkspaceStateKey: String {
    case utilityAreaCollapsed
    case utilityAreaMaximized
    case utilityAreaHeight
    case openTabs
    case workspaceWindowSize
    case splitViewWidth
    case navigatorCollapsed
    case inspectorCollapsed
    case toolbarCollapsed

    // MARK: - Shell (ADR-0006)

    /// Last-used `ViewMode.rawValue` for this workspace; absence defaults to `.ide`.
    case viewMode
    /// Last selected Cockpit surface `id` (from `CockpitSurfaceRegistry`).
    case cockpitSelectedSurface
    /// Last focused product-graph node `id` in the Cockpit view.
    case cockpitSelectedNode
}
