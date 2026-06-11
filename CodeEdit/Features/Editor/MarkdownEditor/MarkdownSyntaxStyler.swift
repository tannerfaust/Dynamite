//
//  MarkdownSyntaxStyler.swift
//  CodeEdit
//
//  Applies live "rendered" styling to a markdown NSTextStorage: headings grow, emphasis
//  renders, code is monospaced, links/quotes/lists are styled, and the raw syntax markers
//  (`#`, `**`, backticks, link URLs) are flagged for concealment so the text reads like the
//  formatted document. The paragraph containing the cursor keeps its markers visible so it
//  can be edited unambiguously.
//
//  The styler is intentionally line-oriented and dependency-free (no full AST) so it stays
//  fast and predictable. It covers the essentials used in instructions / specs / concept docs.
//

import AppKit

final class MarkdownSyntaxStyler {
    var theme: MarkdownTheme

    init(theme: MarkdownTheme) {
        self.theme = theme
    }

    // MARK: - Compiled patterns

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are compile-time constants; a failure is a programmer error.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [])
    }

    private static let headingRegex = regex("^(#{1,6})[ \\t]+(.*)$")
    private static let fenceRegex = regex("^[ \\t]*(```|~~~)")
    private static let blockquoteRegex = regex("^[ \\t]*((?:>[ \\t]?)+)")
    private static let unorderedRegex = regex("^([ \\t]*)([-*+])[ \\t]+")
    private static let orderedRegex = regex("^([ \\t]*)(\\d+[.)])[ \\t]+")
    private static let taskRegex = regex("^[ \\t]*[-*+][ \\t]+\\[([ xX])\\][ \\t]+")
    private static let dividerRegex = regex("^[ \\t]*([-*_])(?:[ \\t]*\\1){2,}[ \\t]*$")

    private static let inlineCodeRegex = regex("`([^`\\n]+)`")
    private static let linkRegex = regex("(!?)\\[([^\\]\\n]*)\\]\\(([^)\\n]+)\\)")
    private static let boldItalicRegex = regex("(\\*\\*\\*)(.+?)(\\*\\*\\*)")
    private static let boldRegex = regex("(\\*\\*|__)(.+?)(\\1)")
    private static let italicRegex = regex("(?<![\\*_])(\\*|_)(?![ \\*_])(.+?)(?<![ \\*_])(\\1)(?![\\*_])")
    private static let strikeRegex = regex("(~~)(.+?)(~~)")

    // MARK: - Apply

    /// Re-applies all markdown styling to the storage.
    /// - Parameters:
    ///   - textStorage: The storage to style. Styled in place inside a begin/endEditing pass.
    ///   - revealedParagraph: A paragraph range (typically the cursor's line) whose markers
    ///     should stay visible. Pass `nil` to conceal everywhere (e.g. read-only preview).
    func applyStyles(to textStorage: NSTextStorage, revealedParagraph: NSRange?) {
        let nsString = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        textStorage.beginEditing()

        // Reset to base. `setAttributes` clears prior styling AND any concealment flags.
        textStorage.setAttributes(
            [.font: theme.baseFont, .foregroundColor: theme.textColor],
            range: fullRange
        )

        var inFencedCode = false

        nsString.enumerateSubstrings(in: fullRange, options: [.byLines]) { _, lineRange, _, _ in
            let lineText = nsString.substring(with: lineRange)

            // Fenced code blocks: toggle on ``` / ~~~ fences, style everything inside as code.
            if Self.fenceRegex.firstMatch(in: lineText, range: NSRange(location: 0, length: (lineText as NSString).length)) != nil {
                self.applyCodeBlock(line: lineRange, to: textStorage)
                self.conceal(lineRange, in: textStorage, revealed: revealedParagraph)
                inFencedCode.toggle()
                return
            }
            if inFencedCode {
                self.applyCodeBlock(line: lineRange, to: textStorage)
                return
            }

            self.styleLine(lineText: lineText, lineRange: lineRange, to: textStorage, revealed: revealedParagraph)
        }

        textStorage.endEditing()
    }

    // MARK: - Line styling

    private func styleLine(lineText: String, lineRange: NSRange, to textStorage: NSTextStorage, revealed: NSRange?) {
        let lineNS = lineText as NSString
        let local = NSRange(location: 0, length: lineNS.length)

        // Divider (---, ***, ___ on their own line)
        if Self.dividerRegex.firstMatch(in: lineText, range: local) != nil {
            textStorage.addAttribute(.foregroundColor, value: theme.dividerColor, range: lineRange)
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: lineRange)
            textStorage.addAttribute(.strikethroughColor, value: theme.dividerColor, range: lineRange)
            return
        }

        // ATX heading
        if let match = Self.headingRegex.firstMatch(in: lineText, range: local) {
            let hashes = match.range(at: 1)
            let level = hashes.length
            let font = theme.headingFont(level: level)
            textStorage.addAttribute(.font, value: font, range: lineRange)
            // Conceal the `### ` prefix (hashes + the following whitespace up to the content).
            let content = match.range(at: 2)
            let prefixLen = content.location // start of content within the line == length of "### "
            let prefixRange = NSRange(location: lineRange.location, length: prefixLen)
            conceal(prefixRange, in: textStorage, revealed: revealed)
            styleInline(lineText: lineText, lineRange: lineRange, to: textStorage, revealed: revealed)
            return
        }

        // Blockquote
        if let match = Self.blockquoteRegex.firstMatch(in: lineText, range: local) {
            textStorage.addAttribute(.foregroundColor, value: theme.quoteColor, range: lineRange)
            let para = NSMutableParagraphStyle()
            para.firstLineHeadIndent = 12
            para.headIndent = 12
            textStorage.addAttribute(.paragraphStyle, value: para, range: lineRange)
            // Dim the `>` markers but keep them (they read as a quote bar).
            let markers = NSRange(location: lineRange.location, length: match.range(at: 1).length)
            textStorage.addAttribute(.foregroundColor, value: theme.secondaryColor, range: markers)
            styleInline(lineText: lineText, lineRange: lineRange, to: textStorage, revealed: revealed)
            return
        }

        // Task list item (checkbox)
        if let match = Self.taskRegex.firstMatch(in: lineText, range: local) {
            let stateRange = match.range(at: 1)
            let checked = lineNS.substring(with: stateRange).lowercased() == "x"
            // Color the marker area as accent; keep text readable.
            let markerEnd = match.range.location + match.range.length
            let markerRange = NSRange(location: lineRange.location, length: markerEnd)
            textStorage.addAttribute(.foregroundColor, value: theme.accentColor, range: markerRange)
            if checked {
                let contentStart = lineRange.location + markerEnd
                let contentRange = NSRange(location: contentStart, length: lineRange.length - markerEnd)
                if contentRange.length > 0 {
                    textStorage.addAttribute(.foregroundColor, value: theme.secondaryColor, range: contentRange)
                    textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                }
            }
            styleInline(lineText: lineText, lineRange: lineRange, to: textStorage, revealed: revealed)
            return
        }

        // Unordered / ordered list markers: tint the marker, keep it visible.
        if let match = Self.unorderedRegex.firstMatch(in: lineText, range: local) {
            let marker = match.range(at: 2)
            let markerRange = NSRange(location: lineRange.location + marker.location, length: marker.length)
            textStorage.addAttribute(.foregroundColor, value: theme.accentColor, range: markerRange)
        } else if let match = Self.orderedRegex.firstMatch(in: lineText, range: local) {
            let marker = match.range(at: 2)
            let markerRange = NSRange(location: lineRange.location + marker.location, length: marker.length)
            textStorage.addAttribute(.foregroundColor, value: theme.accentColor, range: markerRange)
        }

        styleInline(lineText: lineText, lineRange: lineRange, to: textStorage, revealed: revealed)
    }

    // MARK: - Inline styling

    /// Tracks character ranges already consumed by a higher-priority inline element
    /// (code, links) so lower-priority emphasis doesn't double-style their contents.
    private func styleInline(lineText: String, lineRange: NSRange, to textStorage: NSTextStorage, revealed: NSRange?) {
        let lineNS = lineText as NSString
        let local = NSRange(location: 0, length: lineNS.length)
        var consumed: [NSRange] = []

        func toDocument(_ r: NSRange) -> NSRange {
            NSRange(location: lineRange.location + r.location, length: r.length)
        }
        func overlapsConsumed(_ r: NSRange) -> Bool {
            consumed.contains { NSIntersectionRange($0, r).length > 0 }
        }

        // Inline code
        for match in Self.inlineCodeRegex.matches(in: lineText, range: local) {
            let whole = match.range
            let content = match.range(at: 1)
            textStorage.addAttribute(.font, value: theme.codeFont, range: toDocument(content))
            textStorage.addAttribute(.foregroundColor, value: theme.codeForeground, range: toDocument(content))
            textStorage.addAttribute(.backgroundColor, value: theme.codeBackground, range: toDocument(whole))
            // Conceal the surrounding backticks.
            conceal(toDocument(NSRange(location: whole.location, length: 1)), in: textStorage, revealed: revealed)
            conceal(toDocument(NSRange(location: whole.location + whole.length - 1, length: 1)), in: textStorage, revealed: revealed)
            consumed.append(whole)
        }

        // Links: [text](url)  and images ![alt](url)
        for match in Self.linkRegex.matches(in: lineText, range: local) {
            let whole = match.range
            if overlapsConsumed(whole) { continue }
            let textRange = match.range(at: 2)
            textStorage.addAttribute(.foregroundColor, value: theme.accentColor, range: toDocument(textRange))
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: toDocument(textRange))
            // Conceal everything except the visible text: `![`/`[`, `]`, and `(url)`.
            let leadLen = textRange.location - whole.location // "![" or "["
            conceal(toDocument(NSRange(location: whole.location, length: leadLen)), in: textStorage, revealed: revealed)
            let afterText = textRange.location + textRange.length
            let tailLen = whole.location + whole.length - afterText // "](url)"
            conceal(toDocument(NSRange(location: afterText, length: tailLen)), in: textStorage, revealed: revealed)
            consumed.append(whole)
        }

        applyEmphasis(Self.boldItalicRegex, in: lineText, local: local, textStorage: textStorage,
                      toDocument: toDocument, overlaps: overlapsConsumed, consumed: &consumed,
                      revealed: revealed) { font in self.theme.italic(of: self.theme.bold(of: font)) }

        applyEmphasis(Self.boldRegex, in: lineText, local: local, textStorage: textStorage,
                      toDocument: toDocument, overlaps: overlapsConsumed, consumed: &consumed,
                      revealed: revealed) { font in self.theme.bold(of: font) }

        applyEmphasis(Self.italicRegex, in: lineText, local: local, textStorage: textStorage,
                      toDocument: toDocument, overlaps: overlapsConsumed, consumed: &consumed,
                      revealed: revealed) { font in self.theme.italic(of: font) }

        for match in Self.strikeRegex.matches(in: lineText, range: local) {
            let whole = match.range
            if overlapsConsumed(whole) { continue }
            let content = match.range(at: 2)
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: toDocument(content))
            conceal(toDocument(NSRange(location: whole.location, length: 2)), in: textStorage, revealed: revealed)
            conceal(toDocument(NSRange(location: whole.location + whole.length - 2, length: 2)), in: textStorage, revealed: revealed)
            consumed.append(whole)
        }
    }

    private func applyEmphasis(
        _ regex: NSRegularExpression,
        in lineText: String,
        local: NSRange,
        textStorage: NSTextStorage,
        toDocument: (NSRange) -> NSRange,
        overlaps: (NSRange) -> Bool,
        consumed: inout [NSRange],
        revealed: NSRange?,
        font transform: (NSFont) -> NSFont
    ) {
        for match in regex.matches(in: lineText, range: local) {
            let whole = match.range
            if overlaps(whole) { continue }
            let open = match.range(at: 1)
            let content = match.range(at: 2)
            let close = match.range(at: 3)
            let docContent = toDocument(content)
            // Preserve any font already applied (e.g. heading) by transforming it.
            let existing = (textStorage.attribute(.font, at: docContent.location, effectiveRange: nil) as? NSFont) ?? theme.baseFont
            textStorage.addAttribute(.font, value: transform(existing), range: docContent)
            conceal(toDocument(open), in: textStorage, revealed: revealed)
            conceal(toDocument(close), in: textStorage, revealed: revealed)
            consumed.append(whole)
        }
    }

    // MARK: - Helpers

    private func applyCodeBlock(line: NSRange, to textStorage: NSTextStorage) {
        guard line.length > 0 else { return }
        textStorage.addAttribute(.font, value: theme.codeFont, range: line)
        textStorage.addAttribute(.foregroundColor, value: theme.codeForeground, range: line)
        textStorage.addAttribute(.backgroundColor, value: theme.codeBackground, range: line)
    }

    /// Flags a range for concealment unless it lies on the revealed (cursor) paragraph.
    private func conceal(_ range: NSRange, in textStorage: NSTextStorage, revealed: NSRange?) {
        guard range.length > 0 else { return }
        if let revealed, NSIntersectionRange(range, revealed).length > 0 {
            return
        }
        textStorage.addAttribute(.markdownConceal, value: true, range: range)
    }
}
