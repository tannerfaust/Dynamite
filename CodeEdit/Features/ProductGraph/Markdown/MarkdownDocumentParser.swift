//
//  MarkdownDocumentParser.swift
//  CodeEdit
//

import Foundation
import Markdown

struct MarkdownSection: Equatable {
    let level: Int
    let title: String
}

struct MarkdownTaskItem: Equatable {
    let text: String
    let isCompleted: Bool
}

struct MarkdownLink: Equatable {
    let title: String
    let destination: String
}

/// Small ProductGraph-facing wrapper around swift-markdown.
///
/// Keep direct swift-markdown AST usage inside this folder so ProductGraph,
/// LinkIndex, and ContextEngine can depend on Dynamite-shaped concepts.
enum MarkdownDocumentParser {

    static func sections(in source: String) -> [MarkdownSection] {
        var walker = SectionWalker()
        walker.visit(Document(parsing: source))
        return walker.sections
    }

    static func taskItems(in source: String) -> [MarkdownTaskItem] {
        var walker = TaskItemWalker()
        walker.visit(Document(parsing: source))
        return walker.items
    }

    static func links(in source: String) -> [MarkdownLink] {
        var walker = LinkWalker()
        walker.visit(Document(parsing: source))
        return walker.links
    }
}

private struct SectionWalker: MarkupWalker {
    var sections: [MarkdownSection] = []

    mutating func visitHeading(_ heading: Heading) {
        sections.append(
            MarkdownSection(
                level: heading.level,
                title: heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        descendInto(heading)
    }
}

private struct TaskItemWalker: MarkupWalker {
    var items: [MarkdownTaskItem] = []

    mutating func visitListItem(_ listItem: ListItem) {
        if let checkbox = listItem.checkbox {
            items.append(
                MarkdownTaskItem(
                    text: plainText(in: listItem),
                    isCompleted: checkbox == .checked
                )
            )
        }
        descendInto(listItem)
    }
}

private struct LinkWalker: MarkupWalker {
    var links: [MarkdownLink] = []

    mutating func visitLink(_ link: Link) {
        if let destination = link.destination, !destination.isEmpty {
            links.append(
                MarkdownLink(
                    title: plainText(in: link),
                    destination: destination
                )
            )
        }
        descendInto(link)
    }
}

private func plainText(in markup: Markup) -> String {
    if let inlineCode = markup as? InlineCode {
        return inlineCode.code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let childText = markup.children
        .map { plainText(in: $0) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if !childText.isEmpty {
        return childText
    }

    if let plainText = markup as? PlainTextConvertibleMarkup {
        return plainText.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return ""
}
