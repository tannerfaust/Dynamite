//
//  MarkdownSlashBlock.swift
//  CodeEdit
//

import Foundation

struct MarkdownSlashBlock: Identifiable, Equatable {
    static let caretToken = "{{caret}}"

    let id: String
    let category: String
    let title: String
    let subtitle: String
    let systemImage: String
    let snippet: String

    init(
        id: String,
        category: String,
        title: String,
        subtitle: String,
        systemImage: String,
        snippet: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.snippet = snippet
    }

    static let essentials: [MarkdownSlashBlock] = [
        MarkdownSlashBlock(
            id: "paragraph",
            category: "Text",
            title: "Paragraph",
            subtitle: "Plain text",
            systemImage: "text.alignleft",
            snippet: "{{caret}}"
        ),
        MarkdownSlashBlock(
            id: "heading-1",
            category: "Text",
            title: "Heading 1",
            subtitle: "Large section title",
            systemImage: "1.square",
            snippet: "# {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "heading-2",
            category: "Text",
            title: "Heading 2",
            subtitle: "Section title",
            systemImage: "2.square",
            snippet: "## {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "heading-3",
            category: "Text",
            title: "Heading 3",
            subtitle: "Subsection title",
            systemImage: "3.square",
            snippet: "### {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "bullet-list",
            category: "Lists",
            title: "Bullet List",
            subtitle: "Simple unordered list",
            systemImage: "list.bullet",
            snippet: "- {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "numbered-list",
            category: "Lists",
            title: "Numbered List",
            subtitle: "Ordered steps",
            systemImage: "list.number",
            snippet: "1. {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "checklist",
            category: "Lists",
            title: "Checklist",
            subtitle: "Track tasks",
            systemImage: "checklist",
            snippet: "- [ ] {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "quote",
            category: "Structure",
            title: "Quote",
            subtitle: "Indented quote block",
            systemImage: "quote.opening",
            snippet: "> {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "note",
            category: "Structure",
            title: "Callout: Note",
            subtitle: "Highlighted note",
            systemImage: "note.text",
            snippet: "> [!NOTE]\n> {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "warning",
            category: "Structure",
            title: "Callout: Warning",
            subtitle: "Important warning",
            systemImage: "exclamationmark.triangle",
            snippet: "> [!WARNING]\n> {{caret}}"
        ),
        MarkdownSlashBlock(
            id: "divider",
            category: "Structure",
            title: "Divider",
            subtitle: "Horizontal rule",
            systemImage: "minus",
            snippet: "---\n{{caret}}"
        ),
        MarkdownSlashBlock(
            id: "table",
            category: "Data",
            title: "Table",
            subtitle: "Two-column table",
            systemImage: "tablecells",
            snippet: "| Column | Column |\n| --- | --- |\n| {{caret}} | |"
        ),
        MarkdownSlashBlock(
            id: "code-block",
            category: "Code",
            title: "Code Block",
            subtitle: "Fenced code",
            systemImage: "curlybraces",
            snippet: "```\n{{caret}}\n```"
        ),
        MarkdownSlashBlock(
            id: "swift-code-block",
            category: "Code",
            title: "Swift Code Block",
            subtitle: "Fenced Swift code",
            systemImage: "swift",
            snippet: "```swift\n{{caret}}\n```"
        ),
        MarkdownSlashBlock(
            id: "link",
            category: "Media",
            title: "Link",
            subtitle: "Markdown link",
            systemImage: "link",
            snippet: "[{{caret}}](https://)"
        ),
        MarkdownSlashBlock(
            id: "image",
            category: "Media",
            title: "Image",
            subtitle: "Markdown image",
            systemImage: "photo",
            snippet: "![{{caret}}](image.png)"
        ),
        MarkdownSlashBlock(
            id: "details",
            category: "Advanced",
            title: "Details",
            subtitle: "Collapsible section",
            systemImage: "disclosure.triangle",
            snippet: "<details>\n<summary>{{caret}}</summary>\n\n\n</details>"
        )
    ]
}
