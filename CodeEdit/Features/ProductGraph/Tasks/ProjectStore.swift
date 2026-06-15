//
//  ProjectStore.swift
//  CodeEdit
//

import SwiftUI

/// Loads and persists `ProjectItem`s as `.md` files under `product/projects/`.
///
/// Same file-authoritative model as `TaskStore`. Project-specific fields (`lead`, `target`) ride
/// in the front-matter `extraFields`.
@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [ProjectItem] = []

    let workspaceURL: URL
    private let fileManager = FileManager.default

    init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
        Task { await reload() }
    }

    private var projectsRoot: URL {
        workspaceURL.appendingPathComponent("product").appendingPathComponent("projects")
    }

    // MARK: - Load

    func reload() async {
        guard fileManager.fileExists(atPath: projectsRoot.path) else { projects = []; return }
        guard let urls = try? fileManager.contentsOfDirectory(
            at: projectsRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { projects = []; return }

        var loaded: [ProjectItem] = []
        for url in urls where url.pathExtension == "md" {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  let parsed = FrontMatterEditor.parse(fileContents: contents),
                  !parsed.id.isEmpty else { continue }
            let extras = Dictionary(parsed.extraFields, uniquingKeysWith: { _, new in new })
            loaded.append(ProjectItem(
                id: parsed.id,
                title: parsed.title,
                status: ProjectStatus(rawValue: parsed.status) ?? .planned,
                lead: extras["lead"].flatMap { $0.isEmpty ? nil : $0 },
                target: extras["target"].flatMap { $0.isEmpty ? nil : $0 },
                body: parsed.body,
                created: parsed.created,
                updated: parsed.updated,
                url: url
            ))
        }
        projects = loaded.sorted { $0.updated > $1.updated }
    }

    // MARK: - Create

    @discardableResult
    func newProject(title: String, status: ProjectStatus = .planned) async throws -> ProjectItem {
        try fileManager.createDirectory(at: projectsRoot, withIntermediateDirectories: true)
        let today = WorkItemKit.isoToday()
        let id = WorkItemKit.makeID(prefix: "prj")
        let displayTitle = title.isEmpty ? "Untitled project" : title
        let url = WorkItemKit.uniqueURL(in: projectsRoot, slug: WorkItemKit.slugify(displayTitle))

        let item = ProjectItem(
            id: id, title: displayTitle, status: status, lead: nil, target: nil,
            body: "", created: today, updated: today, url: url
        )
        try write(item, isNew: true)
        await reload()
        return projects.first(where: { $0.id == id }) ?? item
    }

    // MARK: - Mutate

    func save(_ project: ProjectItem) {
        try? write(project, isNew: false)
        if let idx = projects.firstIndex(where: { $0.id == project.id }) { projects[idx] = project }
    }

    // MARK: - Disk

    private func write(_ project: ProjectItem, isNew: Bool) throws {
        var parsed: FrontMatterEditor.Parsed
        if !isNew, let contents = try? String(contentsOf: project.url, encoding: .utf8),
           let existing = FrontMatterEditor.parse(fileContents: contents) {
            parsed = existing
        } else {
            parsed = FrontMatterEditor.Parsed(
                id: project.id, kind: "project", status: project.status.rawValue, title: project.title,
                tags: [], links: [], created: project.created, updated: project.updated,
                extraFields: [], body: project.body
            )
        }
        parsed.kind = "project"
        parsed.status = project.status.rawValue
        parsed.title = project.title
        parsed.body = project.body

        var extras = Dictionary(parsed.extraFields, uniquingKeysWith: { _, new in new })
        extras["lead"] = project.lead ?? ""
        extras["target"] = project.target ?? ""
        parsed.extraFields = extras.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }

        let out = FrontMatterEditor.serialize(parsed, today: WorkItemKit.isoToday())
        let tmp = project.url.appendingPathExtension("tmp")
        try out.write(to: tmp, atomically: true, encoding: .utf8)
        if fileManager.fileExists(atPath: project.url.path) {
            _ = try fileManager.replaceItemAt(project.url, withItemAt: tmp)
        } else {
            try fileManager.moveItem(at: tmp, to: project.url)
        }
    }

    func project(id: String?) -> ProjectItem? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    var activeCount: Int { projects.filter { $0.status.isActive }.count }
}
