//
//  ArtifactStore.swift
//  CodeEdit
//

import Foundation
import Security

/// Manages the collection of product artifacts in the workspace's `product/` folder.
///
/// Provides artifact CRUD operations (create from template, load, save) and maintains a
/// lightweight path→kind cache used by file-tree and quick-open badges. Follows ADR-0001:
/// files are authoritative, the store is a rebuildable view over them.
@MainActor
final class ArtifactStore: ObservableObject {
    @Published private(set) var artifacts: [ProductArtifact] = []
    @Published private(set) var isLoading = false

    let workspaceURL: URL

    /// Path → kind string mapping, updated on every reload. Used by `FileSystemTableViewCell`.
    private(set) var kindByPath: [String: String] = [:]

    private let fileManager = FileManager.default

    init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
        Task { await reload() }
    }

    var productRoot: URL {
        workspaceURL.appendingPathComponent("product")
    }

    // MARK: - Load

    /// Re-scans `product/` and rebuilds the in-memory artifact list.
    func reload() async {
        isLoading = true
        defer { isLoading = false }

        guard fileManager.fileExists(atPath: productRoot.path) else {
            artifacts = []; kindByPath = [:]; return
        }

        var loaded: [ProductArtifact] = []
        var kinds: [String: String] = [:]

        guard let enumerator = fileManager.enumerator(
            at: productRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { artifacts = []; kindByPath = [:]; return }

        for case let url as URL in enumerator {
            guard url.pathExtension == "md",
                  let contents = try? String(contentsOf: url, encoding: .utf8),
                  let parsed = FrontMatterEditor.parse(fileContents: contents),
                  !parsed.id.isEmpty else { continue }

            let typedKind = ArtifactKind.from(parsed.kind)
            let artifact = ProductArtifact(
                id: parsed.id,
                kind: typedKind,
                kindString: parsed.kind,
                status: parsed.status,
                title: parsed.title,
                tags: parsed.tags,
                links: parsed.links.map { .init(rel: $0.rel, to: $0.to, label: $0.label) },
                created: parsed.created,
                updated: parsed.updated,
                extraFields: Dictionary(uniqueKeysWithValues: parsed.extraFields),
                body: parsed.body,
                url: url
            )
            loaded.append(artifact)
            kinds[url.path] = parsed.kind
        }

        artifacts = loaded.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
        kindByPath = kinds
    }

    // MARK: - Create

    /// Creates a new artifact from the kind's bundled template, returns the saved artifact.
    func newArtifact(kind: ArtifactKind, title: String) async throws -> ProductArtifact {
        let today = isoToday()
        let id = makeID(prefix: kind.idPrefix)
        let displayTitle = title.isEmpty ? kind.displayName : title
        let fileName = slugify(displayTitle) + ".md"

        let folderURL = productRoot.appendingPathComponent(kind.category.folderName)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        ensureProductREADME()

        let fileURL = uniqueURL(in: folderURL, fileName: fileName)
        let body = templateContents(for: kind, id: id, title: displayTitle, today: today)
        try body.write(to: fileURL, atomically: true, encoding: .utf8)
        postArtifactsDidChange()

        await reload()
        guard let artifact = artifacts.first(where: { $0.id == id }) else {
            throw ArtifactStoreError.notFoundAfterCreate
        }
        return artifact
    }

    // MARK: - Save

    /// Writes a mutated `ProductArtifact` back to disk, preserving front-matter fields
    /// that the UI doesn't expose (e.g. `code:`, extra kind-specific fields).
    func save(_ artifact: ProductArtifact) throws {
        guard let diskContents = try? String(contentsOf: artifact.url, encoding: .utf8),
              var parsed = FrontMatterEditor.parse(fileContents: diskContents) else {
            throw ArtifactStoreError.parseFailure
        }

        parsed.title  = artifact.title
        parsed.status = artifact.status
        parsed.tags   = artifact.tags
        parsed.links  = artifact.links.map { .init(rel: $0.rel, to: $0.to, label: $0.label) }
        parsed.body   = artifact.body
        // Merge UI-editable extra fields (e.g. roadmap `horizon`) over disk values.
        var extras = Dictionary(uniqueKeysWithValues: parsed.extraFields)
        extras.merge(artifact.extraFields) { _, new in new }
        parsed.extraFields = extras.map { (key: $0.key, value: $0.value) }
        // id, kind, created kept from disk.

        let newContents = FrontMatterEditor.serialize(parsed, today: isoToday())
        let tmp = artifact.url.appendingPathExtension("tmp")
        try newContents.write(to: tmp, atomically: true, encoding: .utf8)
        _ = try fileManager.replaceItemAt(artifact.url, withItemAt: tmp)
        postArtifactsDidChange()

        if let idx = artifacts.firstIndex(where: { $0.id == artifact.id }) {
            artifacts[idx] = artifact
        }
        kindByPath[artifact.url.path] = artifact.kindString
    }

    // MARK: - Private helpers

    /// Posts the change notification scoped to this workspace; observers must match on
    /// `userInfo["workspaceURL"]` so a save in one project window never triggers work
    /// in another project's window.
    private func postArtifactsDidChange() {
        NotificationCenter.default.post(
            name: .productArtifactsDidChange,
            object: nil,
            userInfo: ["workspaceURL": workspaceURL]
        )
    }

    private func templateContents(for kind: ArtifactKind, id: String, title: String, today: String) -> String {
        // Xcode 16 synchronized groups flatten folder resources into Resources/, so try
        // the subdirectory first, then the bundle root.
        let tmplURL = Bundle.main.url(
            forResource: kind.templateName, withExtension: "md", subdirectory: "Templates"
        ) ?? Bundle.main.url(forResource: kind.templateName, withExtension: "md")
        if let tmplURL, var tmpl = try? String(contentsOf: tmplURL, encoding: .utf8) {
            // Replace placeholder tokens from the template
            let prefixPattern = kind.idPrefix + "-xxxxx"
            tmpl = tmpl.replacingOccurrences(of: prefixPattern, with: id)
            tmpl = tmpl.replacingOccurrences(of: "2026-06-10", with: today)
            // Swap generic title placeholders
            for placeholder in ["\(kind.displayName) Title", "\(kind.displayName) Name",
                                 "Persona Name", "Spec Title"] {
                tmpl = tmpl.replacingOccurrences(of: placeholder, with: title)
            }
            return tmpl
        }
        // Minimal inline fallback when the bundle template isn't found.
        return """
---
id: \(id)
kind: \(kind.rawValue)
status: \(kind.defaultStatus)
created: \(today)
updated: \(today)
v: 1
title: \(title)
tags: []
links: []
---

# \(title)

"""
    }

    private func ensureProductREADME() {
        let readme = productRoot.appendingPathComponent("README.md")
        guard !fileManager.fileExists(atPath: readme.path) else { return }
        let content = """
# product/

Typed product artifacts. Managed by Dynamite (ADR-0001).

Folders: `discovery/` · `planning/` · `evidence/` · `gtm/`

Each `.md` file carries YAML front-matter (`id`, `kind`, `status`, `links`) and a markdown body.
`.dynamite/index.db` is gitignored — delete it any time to rebuild.
"""
        try? content.write(to: readme, atomically: true, encoding: .utf8)
    }

    /// Crockford base32 5-char random suffix per ADR-0001 §1 id scheme.
    private func makeID(prefix: String) -> String {
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

    private func isoToday() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: Date())
    }

    private func slugify(_ str: String) -> String {
        str.lowercased()
           .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
           .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func uniqueURL(in folder: URL, fileName: String) -> URL {
        var url = folder.appendingPathComponent(fileName)
        var counter = 2
        let base = (fileName as NSString).deletingPathExtension
        while fileManager.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base)-\(counter).md")
            counter += 1
        }
        return url
    }
}

// MARK: - Errors

enum ArtifactStoreError: LocalizedError {
    case notFoundAfterCreate
    case parseFailure

    var errorDescription: String? {
        switch self {
        case .notFoundAfterCreate: return "Artifact was created but could not be loaded."
        case .parseFailure:        return "Could not parse artifact front-matter."
        }
    }
}
