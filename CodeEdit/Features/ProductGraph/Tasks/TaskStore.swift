//
//  TaskStore.swift
//  CodeEdit
//

import SwiftUI

/// Loads and persists `TaskItem`s as `.md` files under `product/tasks/`.
///
/// Mirrors `ArtifactStore`'s file-authoritative model: the store is a rebuildable view over the
/// files on disk. Task-specific fields (`priority`, `project`, `assignee`, `due`) ride in the
/// front-matter `extraFields` that `FrontMatterEditor` round-trips verbatim.
@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []

    let workspaceURL: URL
    private let fileManager = FileManager.default

    init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
        Task { await reload() }
    }

    private var tasksRoot: URL {
        workspaceURL.appendingPathComponent("product").appendingPathComponent("tasks")
    }

    // MARK: - Load

    func reload() async {
        guard fileManager.fileExists(atPath: tasksRoot.path) else { tasks = []; return }
        guard let urls = try? fileManager.contentsOfDirectory(
            at: tasksRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { tasks = []; return }

        var loaded: [TaskItem] = []
        for url in urls where url.pathExtension == "md" {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  let parsed = FrontMatterEditor.parse(fileContents: contents),
                  !parsed.id.isEmpty else { continue }
            let extras = Dictionary(parsed.extraFields, uniquingKeysWith: { _, new in new })
            loaded.append(TaskItem(
                id: parsed.id,
                title: parsed.title,
                status: TaskStatus(rawValue: parsed.status) ?? .todo,
                priority: TaskPriority(rawValue: extras["priority"] ?? "") ?? .none,
                projectID: extras["project"].flatMap { $0.isEmpty ? nil : $0 },
                assignee: extras["assignee"].flatMap { $0.isEmpty ? nil : $0 },
                due: extras["due"].flatMap { $0.isEmpty ? nil : $0 },
                tags: parsed.tags,
                body: parsed.body,
                created: parsed.created,
                updated: parsed.updated,
                url: url
            ))
        }
        tasks = loaded.sorted { lhs, rhs in
            if lhs.status.sortRank != rhs.status.sortRank { return lhs.status.sortRank < rhs.status.sortRank }
            return lhs.updated > rhs.updated
        }
    }

    // MARK: - Create

    @discardableResult
    func newTask(title: String, status: TaskStatus = .todo, priority: TaskPriority = .none,
                 projectID: String? = nil) async throws -> TaskItem {
        try fileManager.createDirectory(at: tasksRoot, withIntermediateDirectories: true)
        let today = WorkItemKit.isoToday()
        let id = WorkItemKit.makeID(prefix: "tsk")
        let displayTitle = title.isEmpty ? "Untitled task" : title
        let url = WorkItemKit.uniqueURL(in: tasksRoot, slug: WorkItemKit.slugify(displayTitle))

        let item = TaskItem(
            id: id, title: displayTitle, status: status, priority: priority,
            projectID: projectID, assignee: nil, due: nil, tags: [],
            body: "", created: today, updated: today, url: url
        )
        try write(item, isNew: true)
        await reload()
        return tasks.first(where: { $0.id == id }) ?? item
    }

    // MARK: - Mutate

    func save(_ task: TaskItem) {
        try? write(task, isNew: false)
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) { tasks[idx] = task }
    }

    /// Flips a task between `done` and `todo`.
    func toggleDone(_ task: TaskItem) {
        var copy = task
        copy.status = task.status == .done ? .todo : .done
        save(copy)
        Task { await reload() }
    }

    func setStatus(_ status: TaskStatus, for task: TaskItem) {
        var copy = task
        copy.status = status
        save(copy)
        Task { await reload() }
    }

    // MARK: - Disk

    private func write(_ task: TaskItem, isNew: Bool) throws {
        var parsed: FrontMatterEditor.Parsed
        if !isNew, let contents = try? String(contentsOf: task.url, encoding: .utf8),
           let existing = FrontMatterEditor.parse(fileContents: contents) {
            parsed = existing
        } else {
            parsed = FrontMatterEditor.Parsed(
                id: task.id, kind: "task", status: task.status.rawValue, title: task.title,
                tags: [], links: [], created: task.created, updated: task.updated,
                extraFields: [], body: task.body
            )
        }
        parsed.kind = "task"
        parsed.status = task.status.rawValue
        parsed.title = task.title
        parsed.tags = task.tags
        parsed.body = task.body

        var extras = Dictionary(parsed.extraFields, uniquingKeysWith: { _, new in new })
        extras["priority"] = task.priority.rawValue
        extras["project"] = task.projectID ?? ""
        extras["assignee"] = task.assignee ?? ""
        extras["due"] = task.due ?? ""
        parsed.extraFields = extras.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }

        let out = FrontMatterEditor.serialize(parsed, today: WorkItemKit.isoToday())
        let tmp = task.url.appendingPathExtension("tmp")
        try out.write(to: tmp, atomically: true, encoding: .utf8)
        if fileManager.fileExists(atPath: task.url.path) {
            _ = try fileManager.replaceItemAt(task.url, withItemAt: tmp)
        } else {
            try fileManager.moveItem(at: tmp, to: task.url)
        }
    }

    // MARK: - Derived

    func tasks(for projectID: String) -> [TaskItem] {
        tasks.filter { $0.projectID == projectID }
    }

    var activeCount: Int { tasks.filter { $0.status.isActive }.count }
    var inProgressCount: Int { tasks.filter { $0.status == .inProgress }.count }
}
