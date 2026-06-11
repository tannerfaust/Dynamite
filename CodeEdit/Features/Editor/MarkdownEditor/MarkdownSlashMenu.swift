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
    let title: String
    let symbol: String
    /// Markdown text inserted in place of the trigger. `|` marks the desired caret position
    /// (removed before insertion); if absent, the caret goes to the end.
    let snippet: String

    static let essentials: [MarkdownBlock] = [
        MarkdownBlock(title: "Heading 1", symbol: "1.square", snippet: "# |"),
        MarkdownBlock(title: "Heading 2", symbol: "2.square", snippet: "## |"),
        MarkdownBlock(title: "Heading 3", symbol: "3.square", snippet: "### |"),
        MarkdownBlock(title: "Bullet List", symbol: "list.bullet", snippet: "- |"),
        MarkdownBlock(title: "Numbered List", symbol: "list.number", snippet: "1. |"),
        MarkdownBlock(title: "Checklist", symbol: "checklist", snippet: "- [ ] |"),
        MarkdownBlock(title: "Quote", symbol: "quote.opening", snippet: "> |"),
        MarkdownBlock(title: "Code Block", symbol: "curlybraces", snippet: "```\n|\n```"),
        MarkdownBlock(title: "Divider", symbol: "minus", snippet: "---\n|")
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
        for (index, block) in MarkdownBlock.essentials.enumerated() {
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
        if let caretMarker = snippet.firstIndex(of: "|") {
            caretOffset = snippet.distance(from: snippet.startIndex, to: caretMarker)
            snippet.remove(at: caretMarker)
        }

        if shouldChangeText(in: replaceRange, replacementString: snippet) {
            textStorage?.replaceCharacters(in: replaceRange, with: snippet)
            didChangeText()
            setSelectedRange(NSRange(location: trigger + caretOffset, length: 0))
        }
        slashTriggerLocation = NSNotFound
    }
}
