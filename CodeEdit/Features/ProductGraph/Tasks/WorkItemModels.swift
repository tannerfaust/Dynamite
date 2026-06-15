//
//  WorkItemModels.swift
//  CodeEdit
//
//  Local-first Tasks & Projects for the Product Studio. Each record is a plain `.md` file with
//  YAML front-matter under `product/tasks/` or `product/projects/` (ADR-0001: files are
//  authoritative). The same front-matter shape a future `LinearSyncing` adapter maps to/from
//  Linear issues/projects.
//

import SwiftUI
import Security

// MARK: - Task

/// A unit of product work. Persisted as `product/tasks/<slug>.md`.
struct TaskItem: Identifiable, Equatable {
    let id: String
    var title: String
    var status: TaskStatus
    var priority: TaskPriority
    /// `id` of the owning `ProjectItem`, if any.
    var projectID: String?
    /// Free-text assignee initials/handle (local until Linear maps real users).
    var assignee: String?
    /// `yyyy-MM-dd` due date, or nil.
    var due: String?
    var tags: [String]
    /// Markdown description.
    var body: String
    var created: String
    var updated: String
    let url: URL

    var displayTitle: String {
        title.isEmpty ? url.deletingPathExtension().lastPathComponent : title
    }
}

enum TaskStatus: String, CaseIterable, Identifiable {
    case backlog
    case todo
    case inProgress = "in-progress"
    case done
    case canceled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backlog:    return "Backlog"
        case .todo:       return "Todo"
        case .inProgress: return "In progress"
        case .done:       return "Done"
        case .canceled:   return "Canceled"
        }
    }

    /// Order used for grouping the task list (active work first).
    var sortRank: Int {
        switch self {
        case .inProgress: return 0
        case .todo:       return 1
        case .backlog:    return 2
        case .done:       return 3
        case .canceled:   return 4
        }
    }

    /// Counts toward the "active tasks" metric.
    var isActive: Bool { self == .todo || self == .inProgress }

    var systemImage: String {
        switch self {
        case .backlog:    return "circle.dotted"
        case .todo:       return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .done:       return "checkmark.circle.fill"
        case .canceled:   return "xmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .backlog:    return Color(nsColor: .tertiaryLabelColor)
        case .todo:       return .secondary
        case .inProgress: return .accentColor
        case .done:       return .green
        case .canceled:   return Color(nsColor: .tertiaryLabelColor)
        }
    }
}

enum TaskPriority: String, CaseIterable, Identifiable {
    case none
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:   return "No priority"
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        case .urgent: return "Urgent"
        }
    }

    var rank: Int {
        switch self {
        case .urgent: return 0
        case .high:   return 1
        case .medium: return 2
        case .low:    return 3
        case .none:   return 4
        }
    }

    var systemImage: String {
        self == .urgent ? "exclamationmark.square.fill" : "square.stack.3d.up"
    }

    /// Small bar-strength glyph used in lists.
    var barImage: String { "chart.bar.fill" }

    var tint: Color {
        switch self {
        case .none:   return Color(nsColor: .quaternaryLabelColor)
        case .low:    return .secondary
        case .medium: return .accentColor
        case .high:   return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Project

/// A bounded body of work that groups tasks. Persisted as `product/projects/<slug>.md`.
struct ProjectItem: Identifiable, Equatable {
    let id: String
    var title: String
    var status: ProjectStatus
    var lead: String?
    /// `yyyy-MM-dd` target date, or nil.
    var target: String?
    var body: String
    var created: String
    var updated: String
    let url: URL

    var displayTitle: String {
        title.isEmpty ? url.deletingPathExtension().lastPathComponent : title
    }
}

enum ProjectStatus: String, CaseIterable, Identifiable {
    case backlog
    case planned
    case inProgress = "in-progress"
    case completed
    case canceled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backlog:    return "Backlog"
        case .planned:    return "Planned"
        case .inProgress: return "In progress"
        case .completed:  return "Completed"
        case .canceled:   return "Canceled"
        }
    }

    var isActive: Bool { self == .planned || self == .inProgress }

    var tint: Color {
        switch self {
        case .backlog:    return Color(nsColor: .tertiaryLabelColor)
        case .planned:    return .secondary
        case .inProgress: return .accentColor
        case .completed:  return .green
        case .canceled:   return Color(nsColor: .tertiaryLabelColor)
        }
    }
}

// MARK: - Shared persistence helpers

/// Small file-system helpers shared by `TaskStore` and `ProjectStore`, mirroring the id/slug/date
/// conventions in `ArtifactStore`.
enum WorkItemKit {
    /// Crockford base32 5-char random suffix (ADR-0001 §1 id scheme), e.g. `tsk-a3k9p`.
    static func makeID(prefix: String) -> String {
        let alphabet = Array("0123456789abcdefghjkmnpqrstvwxyz")
        var bytes = [UInt8](repeating: 0, count: 4)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let value = UInt64(bytes[0]) << 24 | UInt64(bytes[1]) << 16
                  | UInt64(bytes[2]) << 8 | UInt64(bytes[3])
        var suffix = ""
        var bits = value
        for _ in 0..<5 {
            suffix = String(alphabet[Int(bits & 0x1F)]) + suffix
            bits >>= 5
        }
        return "\(prefix)-\(suffix)"
    }

    static func isoToday() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: Date())
    }

    static func slugify(_ str: String) -> String {
        let slug = str.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "untitled" : slug
    }

    static func uniqueURL(in folder: URL, slug: String) -> URL {
        let fileManager = FileManager.default
        var url = folder.appendingPathComponent(slug + ".md")
        var counter = 2
        while fileManager.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(slug)-\(counter).md")
            counter += 1
        }
        return url
    }
}
