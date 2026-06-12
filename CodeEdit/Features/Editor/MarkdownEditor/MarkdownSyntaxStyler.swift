// swiftlint:disable cyclomatic_complexity file_length function_body_length
// swiftlint:disable function_parameter_count identifier_name multiline_arguments_brackets
// swiftlint:disable type_body_length
//
//  MarkdownSyntaxStyler.swift
//  CodeEdit
//
//  Applies markdown-aware styling to an editable markdown NSTextStorage: headings grow,
//  emphasis renders, code is monospaced, links/quotes/lists are styled, and raw syntax
//  markers are de-emphasized without changing glyph width or hit-testing.
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
    private static let setextHeadingRegex = regex("^[ \\t]*(=+|-+)[ \\t]*$")
    private static let fenceRegex = regex("^[ \\t]*(```|~~~)")
    private static let blockquoteRegex = regex("^[ \\t]*((?:>[ \\t]?)+)")
    private static let calloutRegex = regex("^[ \\t]*(>[ \\t]*)(\\[!)([A-Za-z]+)(\\])")
    private static let unorderedRegex = regex("^([ \\t]*)([-*+])[ \\t]+")
    private static let orderedRegex = regex("^([ \\t]*)(\\d+[.)])[ \\t]+")
    private static let taskRegex = regex("^[ \\t]*[-*+][ \\t]+\\[([ xX])\\][ \\t]+")
    private static let dividerRegex = regex("^[ \\t]*([-*_])(?:[ \\t]*\\1){2,}[ \\t]*$")
    private static let tableSeparatorRegex = regex(
        "^[ \\t]*\\|?[ \\t]*:?-{3,}:?[ \\t]*(\\|[ \\t]*:?-{3,}:?[ \\t]*)+\\|?[ \\t]*$"
    )

    private static let inlineCodeRegex = regex("`([^`\\n]+)`")
    private static let linkRegex = regex("(!?)\\[([^\\]\\n]*)\\]\\(([^)\\n]+)\\)")
    private static let autolinkRegex = regex("<(https?://[^>\\s]+|mailto:[^>\\s]+)>")
    private static let bareURLRegex = regex("(?<![\\]\\(])(https?://[^\\s<>()]+)")
    private static let boldItalicRegex = regex("(\\*\\*\\*)(.+?)(\\*\\*\\*)")
    private static let boldRegex = regex("(\\*\\*|__)(.+?)(\\1)")
    private static let italicRegex = regex("(?<![\\*_])(\\*|_)(?![ \\*_])(.+?)(?<![ \\*_])(\\1)(?![\\*_])")
    private static let strikeRegex = regex("(~~)(.+?)(~~)")
    private static let highlightRegex = regex("(==)(.+?)(==)")
    private static let htmlTagRegex = regex("(</?[A-Za-z][^>\\n]*>)")

    private struct MarkdownLine {
        var text: String
        var range: NSRange
    }

    // MARK: - Apply

    /// Re-applies all markdown styling to the entire storage.
    /// Used for initial load, theme changes, and `replaceContents`.
    /// - Parameters:
    ///   - textStorage: The storage to style. Styled in place inside a begin/endEditing pass.
    ///   - revealedParagraph: Reserved for source/reveal behavior; preview concealment currently
    ///     hides syntax markers everywhere to keep the rendered surface consistent.
    func applyStyles(to textStorage: NSTextStorage, revealedParagraph: NSRange?) {
        let nsString = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        applyStylesInRange(to: textStorage, range: fullRange, revealedParagraph: revealedParagraph)
    }

    /// Incrementally re-applies markdown styling to a specific range of the storage.
    /// The range is expanded to paragraph boundaries to ensure correct styling. Used for
    /// per-keystroke edits and caret-paragraph changes to avoid O(document) work.
    /// - Parameters:
    ///   - textStorage: The storage to style.
    ///   - range: The character range to restyle (will be expanded to paragraph boundaries).
    ///   - revealedParagraph: Reserved for source/reveal behavior; currently ignored.
    func applyStyles(to textStorage: NSTextStorage, in range: NSRange, revealedParagraph: NSRange?) {
        let nsString = textStorage.string as NSString
        guard nsString.length > 0 else { return }

        // Expand the requested range to paragraph boundaries.
        let location = min(max(range.location, 0), nsString.length - 1)
        let clampedRange = NSRange(
            location: location,
            length: min(range.length, nsString.length - location)
        )
        let paragraphRange = nsString.paragraphRange(for: clampedRange)
        applyStylesInRange(to: textStorage, range: paragraphRange, revealedParagraph: revealedParagraph)
    }

    /// Core styling implementation that operates on a given range.
    /// If the range covers the full document, resets all attributes first.
    /// Otherwise, resets only the target range and determines fenced-code-block context
    /// by scanning from the document start.
    private func applyStylesInRange(
        to textStorage: NSTextStorage,
        range targetRange: NSRange,
        revealedParagraph: NSRange?
    ) {
        let nsString = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let isFullDocument = targetRange.location == 0 && targetRange.length == fullRange.length

        textStorage.beginEditing()

        // Reset base attributes on the target range.
        if targetRange.length > 0 {
            textStorage.setAttributes(
                [
                    .font: theme.baseFont,
                    .foregroundColor: theme.textColor,
                    .paragraphStyle: theme.baseParagraphStyle
                ],
                range: targetRange
            )
        }

        // For incremental passes, determine whether the target range starts inside a
        // fenced code block by scanning all lines before it for unmatched fence markers.
        var inFencedCode = false
        if !isFullDocument && targetRange.location > 0 {
            let prefixRange = NSRange(location: 0, length: targetRange.location)
            let prefixLines = markdownLines(in: nsString, fullRange: prefixRange)
            for prefixLine in prefixLines {
                let local = NSRange(location: 0, length: (prefixLine.text as NSString).length)
                if Self.fenceRegex.firstMatch(in: prefixLine.text, range: local) != nil {
                    inFencedCode.toggle()
                }
            }
        }

        let lines = markdownLines(in: nsString, fullRange: targetRange)
        var consumedLineIndexes = Set<Int>()

        for index in lines.indices {
            guard !consumedLineIndexes.contains(index) else { continue }
            let line = lines[index]
            let lineText = line.text
            let lineRange = line.range
            let local = NSRange(location: 0, length: (lineText as NSString).length)

            // Fenced code blocks: toggle on ``` / ~~~ fences, style everything inside as code.
            if Self.fenceRegex.firstMatch(in: lineText, range: local) != nil {
                self.applyCodeBlock(line: lineRange, to: textStorage)
                self.conceal(lineRange, in: textStorage, revealed: revealedParagraph)
                inFencedCode.toggle()
                continue
            }
            if inFencedCode {
                self.applyCodeBlock(line: lineRange, to: textStorage)
                continue
            }

            if index + 1 < lines.count,
               isSetextHeadingBody(lineText),
               let underline = Self.setextHeadingRegex.firstMatch(
                    in: lines[index + 1].text,
                    range: NSRange(location: 0, length: (lines[index + 1].text as NSString).length)
               ) {
                let marker = (lines[index + 1].text as NSString).substring(with: underline.range(at: 1))
                let level = marker.hasPrefix("=") ? 1 : 2
                styleSetextHeading(
                    body: lineRange,
                    underline: lines[index + 1].range,
                    level: level,
                    in: textStorage,
                    revealed: revealedParagraph
                )
                styleInline(lineText: lineText, lineRange: lineRange, to: textStorage, revealed: revealedParagraph)
                consumedLineIndexes.insert(index + 1)
                continue
            }

            if isTableLine(at: index, lines: lines) {
                styleTableLine(lineText: lineText, lineRange: lineRange, index: index, lines: lines, to: textStorage)
                styleInline(lineText: lineText, lineRange: lineRange, to: textStorage, revealed: revealedParagraph)
                continue
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
            textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: lineRange)
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: lineRange)
            textStorage.addAttribute(.strikethroughColor, value: theme.dividerColor, range: lineRange)
            textStorage.addAttribute(.paragraphStyle, value: dividerParagraphStyle(), range: lineRange)
            return
        }

        // ATX heading
        if let match = Self.headingRegex.firstMatch(in: lineText, range: local) {
            let hashes = match.range(at: 1)
            let level = hashes.length
            let font = theme.headingFont(level: level)
            textStorage.addAttribute(.font, value: font, range: lineRange)
            textStorage.addAttribute(.paragraphStyle, value: headingParagraphStyle(level: level), range: lineRange)
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
            textStorage.addAttribute(.backgroundColor, value: theme.quoteBackground, range: lineRange)
            textStorage.addAttribute(.paragraphStyle, value: quoteParagraphStyle(), range: lineRange)

            if let callout = Self.calloutRegex.firstMatch(in: lineText, range: local) {
                conceal(documentRange(for: callout.range(at: 1), in: lineRange), in: textStorage, revealed: revealed)
                conceal(documentRange(for: callout.range(at: 2), in: lineRange), in: textStorage, revealed: revealed)
                conceal(documentRange(for: callout.range(at: 4), in: lineRange), in: textStorage, revealed: revealed)
                let labelRange = documentRange(for: callout.range(at: 3), in: lineRange)
                textStorage.addAttribute(.font, value: theme.bold(of: theme.baseFont), range: labelRange)
                textStorage.addAttribute(.foregroundColor, value: theme.accentColor, range: labelRange)
            } else {
                let markers = NSRange(location: lineRange.location, length: match.range(at: 1).length)
                conceal(markers, in: textStorage, revealed: revealed)
            }
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
            conceal(markerRange, in: textStorage, revealed: revealed)
            if checked {
                let contentStart = lineRange.location + markerEnd
                let contentRange = NSRange(location: contentStart, length: lineRange.length - markerEnd)
                if contentRange.length > 0 {
                    textStorage.addAttribute(.foregroundColor, value: theme.secondaryColor, range: contentRange)
                    textStorage.addAttribute(
                        .strikethroughStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: contentRange
                    )
                }
            }
            styleInline(lineText: lineText, lineRange: lineRange, to: textStorage, revealed: revealed)
            return
        }

        applyListParagraphStyle(lineText: lineText, lineRange: lineRange, to: textStorage)

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

    private func styleSetextHeading(
        body: NSRange,
        underline: NSRange,
        level: Int,
        in textStorage: NSTextStorage,
        revealed: NSRange?
    ) {
        textStorage.addAttribute(.font, value: theme.headingFont(level: level), range: body)
        textStorage.addAttribute(.paragraphStyle, value: headingParagraphStyle(level: level), range: body)
        conceal(underline, in: textStorage, revealed: revealed)
    }

    private func styleTableLine(
        lineText: String,
        lineRange: NSRange,
        index: Int,
        lines: [MarkdownLine],
        to textStorage: NSTextStorage
    ) {
        guard lineRange.length > 0 else { return }

        let local = NSRange(location: 0, length: (lineText as NSString).length)
        let isSeparator = Self.tableSeparatorRegex.firstMatch(in: lineText, range: local) != nil
        let isHeader = index + 1 < lines.count && isTableSeparator(lines[index + 1].text)

        textStorage.addAttribute(.font, value: theme.codeFont, range: lineRange)
        textStorage.addAttribute(.paragraphStyle, value: tableParagraphStyle(), range: lineRange)
        textStorage.addAttribute(
            .backgroundColor,
            value: isHeader ? theme.tableHeaderBackground : NSColor.clear,
            range: lineRange
        )

        if isHeader {
            textStorage.addAttribute(.font, value: theme.bold(of: theme.codeFont), range: lineRange)
        }

        if isSeparator {
            conceal(lineRange, in: textStorage, revealed: nil)
            return
        }

        for characterIndex in 0..<local.length {
            let characterRange = NSRange(location: characterIndex, length: 1)
            guard (lineText as NSString).substring(with: characterRange) == "|" else {
                continue
            }
            let pipeRange = NSRange(location: lineRange.location + characterIndex, length: 1)
            conceal(pipeRange, in: textStorage, revealed: nil)
        }
    }

    private func markdownLines(in nsString: NSString, fullRange: NSRange) -> [MarkdownLine] {
        var lines: [MarkdownLine] = []
        nsString.enumerateSubstrings(in: fullRange, options: [.byLines]) { substring, lineRange, _, _ in
            lines.append(MarkdownLine(text: substring ?? "", range: lineRange))
        }
        return lines
    }

    private func isSetextHeadingBody(_ lineText: String) -> Bool {
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !trimmed.hasPrefix("|") && !trimmed.hasPrefix("#")
    }

    private func isTableLine(at index: Int, lines: [MarkdownLine]) -> Bool {
        let line = lines[index].text
        guard line.contains("|") else { return false }
        if isTableSeparator(line) { return true }
        if index > 0, isTableSeparator(lines[index - 1].text) { return true }
        if index + 1 < lines.count, isTableSeparator(lines[index + 1].text) { return true }
        return false
    }

    private func isTableSeparator(_ lineText: String) -> Bool {
        let local = NSRange(location: 0, length: (lineText as NSString).length)
        return Self.tableSeparatorRegex.firstMatch(in: lineText, range: local) != nil
    }

    private func headingParagraphStyle(level: Int) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.15
        paragraph.paragraphSpacingBefore = level <= 2 ? 12 : 8
        paragraph.paragraphSpacing = level <= 2 ? 8 : 5
        return paragraph
    }

    private func quoteParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = theme.lineHeightMultiple
        paragraph.firstLineHeadIndent = 18
        paragraph.headIndent = 18
        paragraph.tailIndent = -12
        paragraph.paragraphSpacing = theme.paragraphSpacing
        return paragraph
    }

    private func tableParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.2
        paragraph.paragraphSpacing = 1
        return paragraph
    }

    private func dividerParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 0.75
        paragraph.paragraphSpacingBefore = 8
        paragraph.paragraphSpacing = 8
        return paragraph
    }

    private func applyListParagraphStyle(lineText: String, lineRange: NSRange, to textStorage: NSTextStorage) {
        let local = NSRange(location: 0, length: (lineText as NSString).length)
        let match = Self.taskRegex.firstMatch(in: lineText, range: local)
            ?? Self.unorderedRegex.firstMatch(in: lineText, range: local)
            ?? Self.orderedRegex.firstMatch(in: lineText, range: local)

        guard let match else { return }

        let leadingWhitespace = lineText.prefix { $0 == " " || $0 == "\t" }
        let indentLevel = leadingWhitespace.reduce(0) { partial, char in
            partial + (char == "\t" ? 2 : 1)
        } / 2
        let baseIndent = CGFloat(22 + indentLevel * 18)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = theme.lineHeightMultiple
        paragraph.firstLineHeadIndent = 0
        paragraph.headIndent = baseIndent
        paragraph.paragraphSpacing = 2
        textStorage.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)

        let markerRange = NSRange(location: lineRange.location, length: match.range.length)
        conceal(markerRange, in: textStorage, revealed: nil)
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

        // Inline code
        for match in Self.inlineCodeRegex.matches(in: lineText, range: local) {
            let whole = match.range
            let content = match.range(at: 1)
            textStorage.addAttribute(.font, value: theme.codeFont, range: toDocument(content))
            textStorage.addAttribute(.foregroundColor, value: theme.codeForeground, range: toDocument(content))
            textStorage.addAttribute(.backgroundColor, value: theme.codeBackground, range: toDocument(whole))
            // Conceal the surrounding backticks.
            conceal(toDocument(NSRange(location: whole.location, length: 1)), in: textStorage, revealed: revealed)
            conceal(
                toDocument(NSRange(location: whole.location + whole.length - 1, length: 1)),
                in: textStorage,
                revealed: revealed
            )
            consumed.append(whole)
        }

        // Links: [text](url)  and images ![alt](url)
        for match in Self.linkRegex.matches(in: lineText, range: local) {
            let whole = match.range
            if Self.overlapsConsumed(whole, consumed: consumed) { continue }
            let imageMarker = match.range(at: 1)
            let textRange = match.range(at: 2)
            textStorage.addAttribute(.foregroundColor, value: theme.accentColor, range: toDocument(textRange))
            textStorage.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: toDocument(textRange)
            )
            if imageMarker.length > 0 {
                textStorage.addAttribute(.font, value: theme.italic(of: theme.baseFont), range: toDocument(textRange))
            }
            // Conceal everything except the visible text: `![`/`[`, `]`, and `(url)`.
            let leadLen = textRange.location - whole.location // "![" or "["
            conceal(toDocument(NSRange(location: whole.location, length: leadLen)), in: textStorage, revealed: revealed)
            let afterText = textRange.location + textRange.length
            let tailLen = whole.location + whole.length - afterText // "](url)"
            conceal(toDocument(NSRange(location: afterText, length: tailLen)), in: textStorage, revealed: revealed)
            consumed.append(whole)
        }

        for match in Self.autolinkRegex.matches(in: lineText, range: local) {
            let whole = match.range
            if Self.overlapsConsumed(whole, consumed: consumed) { continue }
            let content = match.range(at: 1)
            textStorage.addAttribute(.foregroundColor, value: theme.accentColor, range: toDocument(content))
            textStorage.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: toDocument(content)
            )
            conceal(toDocument(NSRange(location: whole.location, length: 1)), in: textStorage, revealed: revealed)
            conceal(
                toDocument(NSRange(location: whole.location + whole.length - 1, length: 1)),
                in: textStorage,
                revealed: revealed
            )
            consumed.append(whole)
        }

        for match in Self.bareURLRegex.matches(in: lineText, range: local) {
            let whole = match.range
            if Self.overlapsConsumed(whole, consumed: consumed) { continue }
            textStorage.addAttribute(.foregroundColor, value: theme.accentColor, range: toDocument(whole))
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: toDocument(whole))
            consumed.append(whole)
        }

        for match in Self.highlightRegex.matches(in: lineText, range: local) {
            let whole = match.range
            if Self.overlapsConsumed(whole, consumed: consumed) { continue }
            let content = match.range(at: 2)
            textStorage.addAttribute(.backgroundColor, value: theme.highlightBackground, range: toDocument(content))
            conceal(toDocument(match.range(at: 1)), in: textStorage, revealed: revealed)
            conceal(toDocument(match.range(at: 3)), in: textStorage, revealed: revealed)
            consumed.append(whole)
        }

        applyEmphasis(Self.boldItalicRegex, in: lineText, local: local, textStorage: textStorage,
                      toDocument: toDocument, consumed: &consumed, revealed: revealed) { font in
            self.theme.italic(of: self.theme.bold(of: font))
        }

        applyEmphasis(Self.boldRegex, in: lineText, local: local, textStorage: textStorage,
                      toDocument: toDocument, consumed: &consumed, revealed: revealed) { font in
            self.theme.bold(of: font)
        }

        applyEmphasis(Self.italicRegex, in: lineText, local: local, textStorage: textStorage,
                      toDocument: toDocument, consumed: &consumed, revealed: revealed) { font in
            self.theme.italic(of: font)
        }

        for match in Self.strikeRegex.matches(in: lineText, range: local) {
            let whole = match.range
            if Self.overlapsConsumed(whole, consumed: consumed) { continue }
            let content = match.range(at: 2)
            textStorage.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: toDocument(content)
            )
            conceal(toDocument(NSRange(location: whole.location, length: 2)), in: textStorage, revealed: revealed)
            conceal(
                toDocument(NSRange(location: whole.location + whole.length - 2, length: 2)),
                in: textStorage,
                revealed: revealed
            )
            consumed.append(whole)
        }

        for match in Self.htmlTagRegex.matches(in: lineText, range: local) {
            let whole = match.range
            if Self.overlapsConsumed(whole, consumed: consumed) { continue }
            textStorage.addAttribute(.foregroundColor, value: theme.syntaxColor, range: toDocument(whole))
            textStorage.addAttribute(.font, value: theme.codeFont, range: toDocument(whole))
            consumed.append(whole)
        }
    }

    private func applyEmphasis(
        _ regex: NSRegularExpression,
        in lineText: String,
        local: NSRange,
        textStorage: NSTextStorage,
        toDocument: (NSRange) -> NSRange,
        consumed: inout [NSRange],
        revealed: NSRange?,
        font transform: (NSFont) -> NSFont
    ) {
        for match in regex.matches(in: lineText, range: local) {
            let whole = match.range
            if Self.overlapsConsumed(whole, consumed: consumed) {
                continue
            }
            let open = match.range(at: 1)
            let content = match.range(at: 2)
            let close = match.range(at: 3)
            let docContent = toDocument(content)
            // Preserve any font already applied (e.g. heading) by transforming it.
            let existing = (textStorage.attribute(.font, at: docContent.location, effectiveRange: nil) as? NSFont)
                ?? theme.baseFont
            textStorage.addAttribute(.font, value: transform(existing), range: docContent)
            conceal(toDocument(open), in: textStorage, revealed: revealed)
            conceal(toDocument(close), in: textStorage, revealed: revealed)
            consumed.append(whole)
        }
    }

    // MARK: - Helpers

    private static func overlapsConsumed(_ range: NSRange, consumed: [NSRange]) -> Bool {
        consumed.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private func documentRange(for localRange: NSRange, in lineRange: NSRange) -> NSRange {
        NSRange(location: lineRange.location + localRange.location, length: localRange.length)
    }

    private func applyCodeBlock(line: NSRange, to textStorage: NSTextStorage) {
        guard line.length > 0 else { return }
        textStorage.addAttribute(.font, value: theme.codeFont, range: line)
        textStorage.addAttribute(.foregroundColor, value: theme.codeForeground, range: line)
        textStorage.addAttribute(.backgroundColor, value: theme.codeBackground, range: line)
        textStorage.addAttribute(.paragraphStyle, value: codeParagraphStyle(), range: line)
    }

    private func codeParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.2
        paragraph.firstLineHeadIndent = 12
        paragraph.headIndent = 12
        paragraph.tailIndent = -12
        paragraph.paragraphSpacing = 0
        return paragraph
    }

    /// Hides Markdown syntax markers visually while keeping their glyph width.
    ///
    /// Do not use TextKit null glyphs here: zero-width concealment changes line geometry
    /// and makes clicks land unpredictably. Transparent syntax keeps hit-testing stable
    /// while making preview mode read like rendered Markdown.
    private func conceal(_ range: NSRange, in textStorage: NSTextStorage, revealed _: NSRange?) {
        guard range.length > 0 else { return }
        textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
    }
}
