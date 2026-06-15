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

    /// Last-used `ViewMode.routeValue` for this workspace; absence defaults to Product Studio.
    case viewMode
    /// Last selected Product Studio surface `id`.
    case cockpitSelectedSurface
    /// Last focused product-graph node `id` in Product Studio.
    case cockpitSelectedNode
}
