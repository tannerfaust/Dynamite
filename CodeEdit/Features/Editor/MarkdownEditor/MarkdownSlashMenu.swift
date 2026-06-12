//
//  MarkdownSlashMenu.swift
//  CodeEdit
//
//  Notion-style "/" block menu for the live markdown editor. Typing "/" at the start of an
//  otherwise-empty line opens a native menu of the essential blocks used when writing
//  instructions, specs, and concept docs. Selecting one replaces the "/" with the block's
//  markdown and positions the caret to keep typing.
//

import AppKit

/// A block type insertable from the slash menu.
struct MarkdownBlock {
    static let caretToken = "{{caret}}"

    let category: String
    let title: String
    let symbol: String
    /// Markdown text inserted in place of the trigger. `{{caret}}` marks the desired caret position
    /// (removed before insertion); if absent, the caret goes to the end.
    let snippet: String

    static let essentials: [MarkdownBlock] = [
        MarkdownBlock(category: "Text", title: "Paragraph", symbol: "text.alignleft", snippet: "{{caret}}"),
        MarkdownBlock(category: "Text", title: "Heading 1", symbol: "1.square", snippet: "# {{caret}}"),
        MarkdownBlock(category: "Text", title: "Heading 2", symbol: "2.square", snippet: "## {{caret}}"),
        MarkdownBlock(category: "Text", title: "Heading 3", symbol: "3.square", snippet: "### {{caret}}"),
        MarkdownBlock(category: "Text", title: "Heading 4", symbol: "4.square", snippet: "#### {{caret}}"),
        MarkdownBlock(category: "Text", title: "Heading 5", symbol: "5.square", snippet: "##### {{caret}}"),
        MarkdownBlock(category: "Text", title: "Heading 6", symbol: "6.square", snippet: "###### {{caret}}"),
        MarkdownBlock(category: "Lists", title: "Bullet List", symbol: "list.bullet", snippet: "- {{caret}}"),
        MarkdownBlock(category: "Lists", title: "Numbered List", symbol: "list.number", snippet: "1. {{caret}}"),
        MarkdownBlock(category: "Lists", title: "Checklist", symbol: "checklist", snippet: "- [ ] {{caret}}"),
        MarkdownBlock(category: "Lists", title: "Checked Task", symbol: "checkmark.square", snippet: "- [x] {{caret}}"),
        MarkdownBlock(category: "Inline", title: "Bold", symbol: "bold", snippet: "**{{caret}}**"),
        MarkdownBlock(category: "Inline", title: "Italic", symbol: "italic", snippet: "*{{caret}}*"),
        MarkdownBlock(
            category: "Inline",
            title: "Bold Italic",
            symbol: "bold.italic.underline",
            snippet: "***{{caret}}***"
        ),
        MarkdownBlock(category: "Inline", title: "Strikethrough", symbol: "strikethrough", snippet: "~~{{caret}}~~"),
        MarkdownBlock(category: "Inline", title: "Highlight", symbol: "highlighter", snippet: "=={{caret}}=="),
        MarkdownBlock(
            category: "Inline",
            title: "Inline Code",
            symbol: "chevron.left.forwardslash.chevron.right",
            snippet: "`{{caret}}`"
        ),
        MarkdownBlock(category: "Structure", title: "Quote", symbol: "quote.opening", snippet: "> {{caret}}"),
        MarkdownBlock(
            category: "Structure",
            title: "Callout: Note",
            symbol: "note.text",
            snippet: "> [!NOTE]\n> {{caret}}"
        ),
        MarkdownBlock(
            category: "Structure",
            title: "Callout: Tip",
            symbol: "lightbulb",
            snippet: "> [!TIP]\n> {{caret}}"
        ),
        MarkdownBlock(
            category: "Structure",
            title: "Callout: Warning",
            symbol: "exclamationmark.triangle",
            snippet: "> [!WARNING]\n> {{caret}}"
        ),
        MarkdownBlock(category: "Structure", title: "Divider", symbol: "minus", snippet: "---\n{{caret}}"),
        MarkdownBlock(
            category: "Data",
            title: "Table",
            symbol: "tablecells",
            snippet: "| Column | Column |\n| --- | --- |\n| {{caret}} | |"
        ),
        MarkdownBlock(
            category: "Data",
            title: "Decision Table",
            symbol: "tablecells.badge.ellipsis",
            snippet: "| Option | Pros | Cons | Decision |\n| --- | --- | --- | --- |\n| {{caret}} | | | |"
        ),
        MarkdownBlock(category: "Code", title: "Code Block", symbol: "curlybraces", snippet: "```\n{{caret}}\n```"),
        MarkdownBlock(
            category: "Code",
            title: "Swift Code Block",
            symbol: "swift",
            snippet: "```swift\n{{caret}}\n```"
        ),
        MarkdownBlock(category: "Media", title: "Link", symbol: "link", snippet: "[{{caret}}](https://)"),
        MarkdownBlock(category: "Media", title: "Image", symbol: "photo", snippet: "![{{caret}}](image.png)"),
        MarkdownBlock(
            category: "References",
            title: "Footnote",
            symbol: "text.badge.plus",
            snippet: "[^1]\n\n[^1]: {{caret}}"
        ),
        MarkdownBlock(
            category: "References",
            title: "Details",
            symbol: "disclosure.triangle",
            snippet: "<details>\n<summary>{{caret}}</summary>\n\n\n</details>"
        ),
        MarkdownBlock(
            category: "References",
            title: "HTML Comment",
            symbol: "text.bubble",
            snippet: "<!-- {{caret}} -->"
        )
    ]
}

extension MarkdownTextView {
    /// Called after an edit; opens the slash menu when the user just typed "/" at the start
    /// of an empty line.
    func handleSlashTrigger() {
        guard let storage = textStorage else { return }
        let sel = selectedRange()
        guard sel.length == 0, sel.location > 0, sel.location <= storage.length else { return }
        let nsString = storage.string as NSString
        guard nsString.substring(with: NSRange(location: sel.location - 1, length: 1)) == "/" else { return }

        // Only trigger when everything before the "/" on this line is whitespace.
        let lineRange = nsString.lineRange(for: NSRange(location: sel.location - 1, length: 0))
        let prefixLen = (sel.location - 1) - lineRange.location
        let prefix = nsString.substring(with: NSRange(location: lineRange.location, length: prefixLen))
        guard prefix.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        presentSlashMenu(triggerLocation: sel.location - 1)
    }

    private func presentSlashMenu(triggerLocation: Int) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        var previousCategory: String?
        for (index, block) in MarkdownBlock.essentials.enumerated() {
            if let previousCategory, previousCategory != block.category {
                menu.addItem(.separator())
            }
            if previousCategory != block.category {
                let header = NSMenuItem(title: block.category.uppercased(), action: nil, keyEquivalent: "")
                header.isEnabled = false
                header.attributedTitle = NSAttributedString(
                    string: block.category.uppercased(),
                    attributes: [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
                menu.addItem(header)
            }
            previousCategory = block.category
            let item = NSMenuItem(title: block.title, action: #selector(insertSlashBlock(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.image = NSImage(systemSymbolName: block.symbol, accessibilityDescription: nil)
            menu.addItem(item)
        }

        // Remember where the trigger "/" is so the action can replace it.
        slashTriggerLocation = triggerLocation

        guard let layoutManager, let textContainer else { return }
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: triggerLocation, length: 1),
            actualCharacterRange: nil
        )
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        let point = NSPoint(x: rect.minX, y: rect.maxY + 4)
        menu.popUp(positioning: nil, at: point, in: self)
    }

    @objc private func insertSlashBlock(_ sender: NSMenuItem) {
        guard sender.tag >= 0, sender.tag < MarkdownBlock.essentials.count else { return }
        let block = MarkdownBlock.essentials[sender.tag]
        let trigger = slashTriggerLocation
        guard trigger != NSNotFound, let storage = textStorage, trigger < storage.length else { return }

        // Replace from the "/" to the current caret (covers the "/" plus anything typed after).
        let caret = selectedRange().location
        let replaceLength = max(1, caret - trigger)
        let replaceRange = NSRange(location: trigger, length: min(replaceLength, storage.length - trigger))

        var snippet = block.snippet
        var caretOffset = snippet.count
        if let caretRange = snippet.range(of: MarkdownBlock.caretToken) {
            caretOffset = snippet.distance(from: snippet.startIndex, to: caretRange.lowerBound)
            snippet.removeSubrange(caretRange)
        }

        if shouldChangeText(in: replaceRange, replacementString: snippet) {
            textStorage?.replaceCharacters(in: replaceRange, with: snippet)
            didChangeText()
            setSelectedRange(NSRange(location: trigger + caretOffset, length: 0))
        }
        slashTriggerLocation = NSNotFound
    }
}
