import Foundation
import GRDB
import Combine
import CryptoKit

public final class LinkIndexManager: ObservableObject {
    public let database: LinkIndexDatabase
    private let workspaceURL: URL
    private var eventStream: DirectoryEventStream?
    private let fileManager = FileManager.default

    @Published public var brokenLinks: [LinkIndexEdge] = []

    public init(workspaceURL: URL, watchesFileSystem: Bool = true) throws {
        self.workspaceURL = workspaceURL
        let dynamiteDir = workspaceURL.appendingPathComponent(".dynamite")
        if !fileManager.fileExists(atPath: dynamiteDir.path) {
            try fileManager.createDirectory(at: dynamiteDir, withIntermediateDirectories: true)
        }

        let dbURL = dynamiteDir.appendingPathComponent("index.db")
        self.database = try LinkIndexDatabase(databaseURL: dbURL)

        if watchesFileSystem {
            startEventStreamIfPossible()
        }

        // `product/` may not exist yet in a fresh workspace. ArtifactStore posts this
        // notification after creating the first artifact so the watcher can attach and
        // the index picks up artifacts without a relaunch (standalone-mode invariant).
        NotificationCenter.default.addObserver(
            forName: .productArtifactsDidChange, object: nil, queue: nil
        ) { [weak self] note in
            guard let self, self.eventStream == nil,
                  let changedURL = note.userInfo?["workspaceURL"] as? URL,
                  changedURL.standardizedFileURL.path == self.workspaceURL.standardizedFileURL.path
            else { return }
            self.startEventStreamIfPossible()
            Task { try? await self.rebuildIndex() }
        }
    }

    deinit {
        close()
    }

    /// Attaches the `product/` directory watcher if the folder exists. Safe to call repeatedly.
    private func startEventStreamIfPossible() {
        guard eventStream == nil else { return }
        let productDir = workspaceURL.appendingPathComponent("product")
        guard fileManager.fileExists(atPath: productDir.path) else { return }
        eventStream = DirectoryEventStream(directory: productDir.path, debounceDuration: 1.0) { [weak self] events in
            self?.handleEvents(events)
        }
    }

    // For testing
    public init(database: LinkIndexDatabase, workspaceURL: URL) {
        self.database = database
        self.workspaceURL = workspaceURL
    }

    public func close() {
        eventStream?.cancel()
        eventStream = nil
        try? database.close()
    }

    public func rebuildIndex() async throws {
        // Clear all
        try await database.dbWriter.write { db in
            try LinkIndexEdge.deleteAll(db)
            try LinkIndexCodeEdge.deleteAll(db)
            try LinkIndexNode.deleteAll(db)
            try db.execute(sql: "DELETE FROM fts")
        }

        let productDir = workspaceURL.appendingPathComponent("product")
        guard fileManager.fileExists(atPath: productDir.path) else { return }

        guard let enumerator = fileManager.enumerator(at: productDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { return }

        var nodes: [LinkIndexNode] = []
        var edges: [LinkIndexEdge] = []
        var codeEdges: [LinkIndexCodeEdge] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }

            let attrs = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let mtime = attrs.contentModificationDate ?? Date()
            let size = attrs.fileSize ?? 0

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let sha = sha256(content)

            let parsed = FrontMatterParser.parse(contents: content)

            let id = parsed.id ?? UUID().uuidString // fallback
            let kind = parsed.kind ?? "unknown"
            let status = parsed.status ?? "unknown"

            let node = LinkIndexNode(
                id: id,
                kind: kind,
                status: status,
                title: parsed.title,
                path: fileURL.path.replacingOccurrences(of: workspaceURL.path + "/", with: ""),
                mtime: mtime,
                size: size,
                contentSHA: sha,
                parseState: parsed.id != nil ? "ok" : "failed",
                created: parsed.created ?? "",
                updated: parsed.updated ?? "",
                extraJSON: nil
            )
            nodes.append(node)

            for (idx, link) in parsed.links.enumerated() {
                edges.append(LinkIndexEdge(
                    srcId: id,
                    rel: link.rel,
                    dstId: link.to,
                    label: link.label,
                    fileOrder: idx,
                    resolved: false
                ))
            }

            for (idx, clink) in parsed.codeLinks.enumerated() {
                codeEdges.append(LinkIndexCodeEdge(
                    srcId: id,
                    pathHint: clink.path,
                    symbol: clink.symbol,
                    anchor: clink.anchor,
                    resolvedPath: nil,
                    resolveState: "unresolved",
                    fileOrder: idx
                ))
            }
        }

        // Save to DB
        try await database.dbWriter.write { db in
            for node in nodes {
                try node.insert(db)
            }
            for edge in edges {
                try edge.insert(db)
            }
            for codeEdge in codeEdges {
                try codeEdge.insert(db)
            }
        }

        try await resolveEdges()
    }

    private func handleEvents(_ events: [DirectoryEventStream.Event]) {
        // Debounced events. Rebuild index for simplicity for now.
        // ADR-0001 constraint: Invalidation... mismatch -> reparse that file only.
        // Doing full rebuild in this prototype for any event.
        Task {
            try? await rebuildIndex()
        }
    }

    private func resolveEdges() async throws {
        let broken = try await database.dbWriter.write { db in
            // Resolve standard edges
            let edges = try LinkIndexEdge.fetchAll(db)
            var broken = [LinkIndexEdge]()
            for edge in edges {
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM nodes WHERE id = ?", arguments: [edge.dstId]) ?? 0
                let targetExists = count > 0
                if targetExists {
                    try db.execute(
                        sql: """
                        UPDATE edges
                        SET resolved = 1
                        WHERE srcId = ? AND rel = ? AND dstId = ? AND fileOrder = ?
                        """,
                        arguments: [edge.srcId, edge.rel, edge.dstId, edge.fileOrder]
                    )
                } else {
                    broken.append(edge)
                }
            }
            return broken
        }

        await MainActor.run {
            self.brokenLinks = broken
        }
    }

    /// Synchronously returns the `kind` string for the node at `absolutePath`, or nil.
    ///
    /// Used by `FileSystemTableViewCell` for the navigator kind badge; hits the
    /// SQLite WAL pool which is fast for single PK-indexed reads.
    public func cachedKind(for absolutePath: String) -> String? {
        let relativePath = absolutePath.hasPrefix(workspaceURL.path + "/")
            ? String(absolutePath.dropFirst(workspaceURL.path.count + 1))
            : absolutePath
        return try? database.dbWriter.read { db in
            try String.fetchOne(db, sql: "SELECT kind FROM nodes WHERE path = ?", arguments: [relativePath])
        }
    }

    private func sha256(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension Notification.Name {
    /// Posted by `ArtifactStore` after creating or saving an artifact file.
    ///
    /// `LinkIndexManager` uses it to attach the `product/` watcher when the folder is
    /// created mid-session; once the watcher is attached, file events drive reindexing.
    public static let productArtifactsDidChange = Notification.Name("dynamite.product.artifactsDidChange")
}
