// swiftlint:disable identifier_name line_length missing_docs
import Foundation
import GRDB

public final class LinkIndexDatabase {
    public let dbWriter: DatabaseWriter

    public init(databaseURL: URL) throws {
        // Use WAL mode. No statement tracing — `cachedKind(for:)` runs per file-tree
        // cell, so tracing would print every SQL statement during navigator scrolls.
        let config = Configuration()
        dbWriter = try DatabasePool(path: databaseURL.path, configuration: config)
        try migrator.migrate(dbWriter)
    }

    // In-memory version for tests
    public init() throws {
        dbWriter = try DatabaseQueue()
        try migrator.migrate(dbWriter)
    }

    public func close() throws {
        try dbWriter.close()
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // ADR-0001: "No migrations. Index schema version bump... delete and rebuild"
        // But we need an initial migration to create the schema.
        migrator.registerMigration("v1") { db in
            try db.create(table: "nodes") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull()
                t.column("status", .text).notNull()
                t.column("title", .text)
                t.column("path", .text).notNull()
                t.column("mtime", .datetime).notNull()
                t.column("size", .integer).notNull()
                t.column("contentSHA", .text).notNull()
                t.column("parseState", .text).notNull()
                t.column("created", .text).notNull()
                t.column("updated", .text).notNull()
                t.column("extraJSON", .text)
            }

            try db.create(table: "edges") { t in
                t.column("srcId", .text).notNull().references("nodes", column: "id", onDelete: .cascade)
                t.column("rel", .text).notNull()
                t.column("dstId", .text).notNull()
                t.column("label", .text)
                t.column("fileOrder", .integer).notNull()
                t.column("resolved", .boolean).notNull()
            }

            try db.create(table: "code_links") { t in
                t.column("srcId", .text).notNull().references("nodes", column: "id", onDelete: .cascade)
                t.column("pathHint", .text).notNull()
                t.column("symbol", .text)
                t.column("anchor", .text).notNull()
                t.column("resolvedPath", .text)
                t.column("resolveState", .text).notNull()
                t.column("fileOrder", .integer).notNull()
            }

            try db.create(virtualTable: "fts", using: FTS5()) { t in
                t.column("title")
                t.column("body")
                t.column("tags")
                t.content = ""
            }

            try db.create(table: "meta") { t in
                t.column("index_schema_version", .integer).notNull()
                t.column("app_version", .text).notNull()
                t.column("built_at", .datetime).notNull()
            }

            try db.execute(sql: "INSERT INTO meta (index_schema_version, app_version, built_at) VALUES (1, '1.0', CURRENT_TIMESTAMP)")
        }

        return migrator
    }
}

// MARK: - GRDB Records
extension LinkIndexNode: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "nodes"
}

extension LinkIndexEdge: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "edges"
}

extension LinkIndexCodeEdge: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "code_links"
}
