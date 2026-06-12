// swiftlint:disable identifier_name line_length missing_docs
import Foundation

public struct LinkIndexNode: Codable, Hashable, Identifiable {
    public let id: String
    public let kind: String
    public let status: String
    public let title: String?
    public let path: String
    public let mtime: Date
    public let size: Int
    public let contentSHA: String
    public let parseState: String // e.g. "ok", "failed"
    public let created: String
    public let updated: String
    public let extraJSON: String?

    public init(id: String, kind: String, status: String, title: String?, path: String, mtime: Date, size: Int, contentSHA: String, parseState: String, created: String, updated: String, extraJSON: String?) {
        self.id = id
        self.kind = kind
        self.status = status
        self.title = title
        self.path = path
        self.mtime = mtime
        self.size = size
        self.contentSHA = contentSHA
        self.parseState = parseState
        self.created = created
        self.updated = updated
        self.extraJSON = extraJSON
    }
}

public struct LinkIndexEdge: Codable, Hashable {
    public let srcId: String
    public let rel: String
    public let dstId: String
    public let label: String?
    public let fileOrder: Int
    public let resolved: Bool

    public init(srcId: String, rel: String, dstId: String, label: String?, fileOrder: Int, resolved: Bool) {
        self.srcId = srcId
        self.rel = rel
        self.dstId = dstId
        self.label = label
        self.fileOrder = fileOrder
        self.resolved = resolved
    }
}

public struct LinkIndexCodeEdge: Codable, Hashable {
    public let srcId: String
    public let pathHint: String
    public let symbol: String?
    public let anchor: String
    public let resolvedPath: String?
    public let resolveState: String // e.g. "exact", "anchor", "broken"
    public let fileOrder: Int

    public init(srcId: String, pathHint: String, symbol: String?, anchor: String, resolvedPath: String?, resolveState: String, fileOrder: Int) {
        self.srcId = srcId
        self.pathHint = pathHint
        self.symbol = symbol
        self.anchor = anchor
        self.resolvedPath = resolvedPath
        self.resolveState = resolveState
        self.fileOrder = fileOrder
    }
}

public struct ParsedFrontMatter {
    public var id: String?
    public var kind: String?
    public var status: String?
    public var title: String?
    public var created: String?
    public var updated: String?
    public var tags: [String] = []
    public var links: [ParsedLink] = []
    public var codeLinks: [ParsedCodeLink] = []
    public var extraKeys: [String: String] = [:]

    public struct ParsedLink {
        public let rel: String
        public let to: String
        public let label: String?
    }

    public struct ParsedCodeLink {
        public let path: String
        public let symbol: String?
        public let anchor: String
    }
}
