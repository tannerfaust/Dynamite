//
//  BacklinksInspectorView.swift
//  CodeEdit
//

import SwiftUI
import GRDB

/// Inspector panel showing typed product-graph links for the focused file or artifact.
///
/// Outgoing: links declared in the focused file's front-matter (srcId = this node).
/// Incoming: other artifacts that point to this file (dstId = this node).
/// Each row navigates to the linked node via `Router`.
struct BacklinksInspectorView: View {
    @EnvironmentObject private var workspace: WorkspaceDocument
    @EnvironmentObject private var editorManager: EditorManager

    @State private var currentNodeID: String?
    @State private var outgoing: [LinkRow] = []
    @State private var incoming: [LinkRow] = []
    @State private var isLoading = false

    struct LinkRow: Identifiable {
        let id: String
        let nodeID: String
        let title: String
        let kindString: String
        let rel: String
        let resolved: Bool
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if currentNodeID == nil {
                NoSelectionInspectorView()
            } else {
                linksList
            }
        }
        .onAppear { refresh() }
        .onReceive(editorManager.activeEditor.objectWillChange) { _ in refresh() }
        .onChange(of: editorManager.activeEditor) { _, _ in refresh() }
        .onChange(of: editorManager.activeEditor.selectedTab) { _, _ in refresh() }
    }

    // MARK: - List

    @ViewBuilder private var linksList: some View {
        Form {
            if !outgoing.isEmpty {
                Section("Outgoing (\(outgoing.count))") {
                    ForEach(outgoing, content: linkRow)
                }
            }
            if !incoming.isEmpty {
                Section("Incoming (\(incoming.count))") {
                    ForEach(incoming, content: linkRow)
                }
            }
            if outgoing.isEmpty && incoming.isEmpty {
                Section {
                    Text("No links for this file.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }

    private func linkRow(_ row: LinkRow) -> some View {
        Button {
            workspace.router?.handle(route: .node(id: row.nodeID))
        } label: {
            HStack(spacing: 8) {
                relBadge(row.rel)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                KindBadge(
                    kind: ArtifactKind.from(row.kindString),
                    kindString: row.kindString,
                    size: .compact
                )
                if !row.resolved {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("Target not found in index")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func relBadge(_ rel: String) -> some View {
        Text(rel)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.8), in: Capsule())
            .lineLimit(1)
    }

    // MARK: - Load

    private func refresh() {
        guard let fileURL = editorManager.activeEditor.selectedTab?.file.url,
              let manager = workspace.linkIndexManager else {
            currentNodeID = nil; outgoing = []; incoming = []; return
        }
        let relPath = relativePath(of: fileURL)
        isLoading = true
        Task {
            let result = await queryLinks(for: relPath, manager: manager)
            await MainActor.run {
                currentNodeID = result.nodeID
                outgoing = result.outgoing
                incoming = result.incoming
                isLoading = false
            }
        }
    }

    private func relativePath(of url: URL) -> String {
        let absolutePath = url.path
        let workspacePath = (workspace.fileURL?.path ?? "") + "/"
        return absolutePath.hasPrefix(workspacePath)
            ? String(absolutePath.dropFirst(workspacePath.count))
            : absolutePath
    }

    // MARK: - DB helpers

    private struct QueryResult {
        let nodeID: String?
        let outgoing: [LinkRow]
        let incoming: [LinkRow]
    }

    private func queryLinks(for relPath: String, manager: LinkIndexManager) async -> QueryResult {
        (try? await manager.database.dbWriter.read { db -> QueryResult in
            guard let nodeID = try String.fetchOne(
                db, sql: "SELECT id FROM nodes WHERE path = ?", arguments: [relPath]
            ) else { return QueryResult(nodeID: nil, outgoing: [], incoming: []) }

            let outRows = try fetchEdgeRows(
                db,
                sql: """
                     SELECT e.dstId, e.rel, e.resolved, n.title, n.kind
                     FROM edges e LEFT JOIN nodes n ON e.dstId = n.id
                     WHERE e.srcId = ? ORDER BY e.fileOrder
                     """,
                nodeID: nodeID,
                prefix: "out"
            )

            let inRows = try fetchEdgeRows(
                db,
                sql: """
                     SELECT e.srcId, e.rel, e.resolved, n.title, n.kind
                     FROM edges e LEFT JOIN nodes n ON e.srcId = n.id
                     WHERE e.dstId = ? ORDER BY e.fileOrder
                     """,
                nodeID: nodeID,
                prefix: "in"
            )
            return QueryResult(nodeID: nodeID, outgoing: outRows, incoming: inRows)
        }) ?? QueryResult(nodeID: nil, outgoing: [], incoming: [])
    }

    private func fetchEdgeRows(
        _ db: Database, sql: String, nodeID: String, prefix: String
    ) throws -> [LinkRow] {
        let oppositeCol = prefix == "out" ? "dstId" : "srcId"
        return try Row.fetchAll(db, sql: sql, arguments: [nodeID]).enumerated().map { (idx, row) in
            let peerID = row[oppositeCol] as? String ?? ""
            return LinkRow(
                id: "\(nodeID)-\(prefix)-\(idx)",
                nodeID: peerID,
                title: (row["title"] as? String) ?? peerID,
                kindString: row["kind"] as? String ?? "",
                rel: row["rel"] as? String ?? "ref",
                resolved: (row["resolved"] as? Bool) ?? false
            )
        }
    }
}
