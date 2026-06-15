//
//  StudioSection.swift
//  CodeEdit
//

import Foundation

/// The top-level destinations inside the Product Studio surface.
///
/// Presented on a labeled, grouped sidebar (`StudioSidebar`) — closer to Linear/Obsidian than the
/// Ground Control's registry-driven panes.
enum StudioSection: String, CaseIterable, Identifiable {
    /// The home dashboard — greeting, metrics, up-next tasks, active projects, recent docs.
    case home
    /// The Linear-style task list.
    case tasks
    /// Projects that group tasks.
    case projects
    /// The roadmap board.
    case roadmap
    /// The typed-artifact workspace (PRDs, personas, interviews…).
    case docs
    /// The zoomable Product Map graph.
    case map

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:     return "Home"
        case .tasks:    return "Tasks"
        case .projects: return "Projects"
        case .roadmap:  return "Roadmap"
        case .docs:     return "Docs"
        case .map:      return "Map"
        }
    }

    /// Longer subtitle shown in section headers.
    var subtitle: String {
        switch self {
        case .home:     return "Your product at a glance"
        case .tasks:    return "Everything in flight"
        case .projects: return "Bodies of work"
        case .roadmap:  return "What ships when"
        case .docs:     return "Discovery, planning, evidence & GTM"
        case .map:      return "How everything connects"
        }
    }

    var systemImage: String {
        switch self {
        case .home:     return "house"
        case .tasks:    return "checkmark.circle"
        case .projects: return "folder"
        case .roadmap:  return "map"
        case .docs:     return "doc.text"
        case .map:      return "point.3.connected.trianglepath.dotted"
        }
    }

    /// Maps a deep-link surface id (from `Router`) onto a section.
    static func from(surfaceID: String) -> StudioSection? {
        switch surfaceID {
        case "studio":       return .docs
        case "product-map":  return .map
        case "tasks":        return .tasks
        case "projects":     return .projects
        case "roadmap":      return .roadmap
        default:             return nil
        }
    }
}

/// Sidebar grouping for the sections.
enum StudioNavGroup: String, CaseIterable, Identifiable {
    case main
    case plan
    case knowledge

    var id: String { rawValue }

    var title: String? {
        switch self {
        case .main:      return nil
        case .plan:      return "Plan"
        case .knowledge: return "Knowledge"
        }
    }

    var sections: [StudioSection] {
        switch self {
        case .main:      return [.home]
        case .plan:      return [.tasks, .projects, .roadmap]
        case .knowledge: return [.docs, .map]
        }
    }
}
