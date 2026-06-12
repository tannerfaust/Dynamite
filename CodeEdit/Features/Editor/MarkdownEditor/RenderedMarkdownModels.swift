//
//  RenderedMarkdownModels.swift
//  CodeEdit
//

import Foundation

struct RenderedMarkdownDocument: Equatable {
    var blocks: [RenderedMarkdownBlock]

    var renderedPlainText: String {
        blocks.map(\.renderedPlainText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

indirect enum RenderedMarkdownBlock: Equatable {
    case heading(level: Int, inlines: [RenderedMarkdownInline])
    case paragraph([RenderedMarkdownInline])
    case blockquote([RenderedMarkdownBlock])
    case codeBlock(language: String?, code: String)
    case horizontalRule
    case unorderedList([RenderedMarkdownListItem])
    case orderedList(start: Int, items: [RenderedMarkdownListItem])
    case table(RenderedMarkdownTable)

    var renderedPlainText: String {
        switch self {
        case .heading(_, let inlines), .paragraph(let inlines):
            return inlines.renderedPlainText
        case .blockquote(let blocks):
            return blocks.map(\.renderedPlainText).joined(separator: "\n")
        case .codeBlock(_, let code):
            return code
        case .horizontalRule:
            return ""
        case .unorderedList(let items), .orderedList(_, let items):
            return items.map { $0.inlines.renderedPlainText }.joined(separator: "\n")
        case .table(let table):
            return ([table.header] + table.rows)
                .map { $0.cells.map(\.renderedPlainText).joined(separator: "\t") }
                .joined(separator: "\n")
        }
    }
}

struct RenderedMarkdownListItem: Equatable {
    var taskState: RenderedMarkdownTaskState?
    var inlines: [RenderedMarkdownInline]
}

enum RenderedMarkdownTaskState: Equatable {
    case unchecked
    case checked
}

struct RenderedMarkdownTable: Equatable {
    var header: RenderedMarkdownTableRow
    var alignments: [RenderedMarkdownColumnAlignment]
    var rows: [RenderedMarkdownTableRow]
}

struct RenderedMarkdownTableRow: Equatable {
    var cells: [[RenderedMarkdownInline]]
}

enum RenderedMarkdownColumnAlignment: Equatable {
    case leading
    case center
    case trailing
}

indirect enum RenderedMarkdownInline: Equatable {
    case text(String)
    case emphasis([RenderedMarkdownInline])
    case strong([RenderedMarkdownInline])
    case strongEmphasis([RenderedMarkdownInline])
    case strikethrough([RenderedMarkdownInline])
    case code(String)
    case link(label: [RenderedMarkdownInline], destination: String)
    case image(alt: String, source: String)

    var renderedPlainText: String {
        switch self {
        case .text(let text), .code(let text):
            return text
        case .emphasis(let inlines),
             .strong(let inlines),
             .strongEmphasis(let inlines),
             .strikethrough(let inlines):
            return inlines.renderedPlainText
        case .link(let label, _):
            return label.renderedPlainText
        case .image(let alt, _):
            return alt
        }
    }
}

extension Array where Element == RenderedMarkdownInline {
    var renderedPlainText: String {
        map(\.renderedPlainText).joined()
    }
}
