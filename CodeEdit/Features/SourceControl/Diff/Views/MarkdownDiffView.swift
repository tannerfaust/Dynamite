//
//  MarkdownDiffView.swift
//  CodeEdit
//
//  Created for Dynamite — T0.4 Doc Review Parity
//
//  Renders markdown diffs with:
//  - Word-level inline highlights on prose lines (LCS-based)
//  - Front-matter changes as a readable key/value table
//  - Side-by-side mode for parallel comparison

import SwiftUI

// MARK: - Router

struct MarkdownDiffView: View {
    let hunks: [DiffHunk]
    let mode: DiffViewModel.DisplayMode

    var body: some View {
        ForEach(hunks) { hunk in
            if isFrontMatterHunk(hunk) {
                FrontMatterDiffView(hunk: hunk)
            } else {
                MarkdownDiffHunkView(hunk: hunk, mode: mode)
            }
        }
    }

    // A hunk is front-matter if it starts at the very beginning of the file
    // and its lines include YAML-style `key: value` entries or `---` delimiters.
    private func isFrontMatterHunk(_ hunk: DiffHunk) -> Bool {
        guard min(hunk.oldStart, hunk.newStart) <= 2 else { return false }
        let frontMatterLinePattern = #"^[a-z][a-z0-9_-]*:\s+\S"#
        let regex = try? NSRegularExpression(pattern: frontMatterLinePattern)
        return hunk.lines.contains { line in
            let content = line.content.trimmingCharacters(in: .whitespaces)
            if content == "---" { return true }
            let range = NSRange(content.startIndex..., in: content)
            return regex?.firstMatch(in: content, range: range) != nil
        }
    }
}

// MARK: - Front-matter diff table

struct FrontMatterDiffView: View {
    let hunk: DiffHunk

    private var oldValues: [String: String] {
        parseFrontMatter(hunk.lines.filter { $0.kind != .added }.map(\.content))
    }

    private var newValues: [String: String] {
        parseFrontMatter(hunk.lines.filter { $0.kind != .removed }.map(\.content))
    }

    private var allKeys: [String] {
        let combined = Set(oldValues.keys).union(newValues.keys)
        return combined.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HunkHeaderRow(header: hunk.header)

            // Table header
            HStack(spacing: 0) {
                cell(Text("Key").bold(), width: 140, bg: Color(nsColor: .controlBackgroundColor))
                Divider()
                cell(Text("Before").bold(), bg: Color(nsColor: .controlBackgroundColor))
                Divider()
                cell(Text("After").bold(), bg: Color(nsColor: .controlBackgroundColor))
            }
            .font(.system(size: 11))
            .frame(height: 22)

            Divider()

            // Rows
            ForEach(allKeys, id: \.self) { key in
                let oldVal = oldValues[key]
                let newVal = newValues[key]
                let changed = oldVal != newVal
                let rowBg: Color = changed
                    ? (newVal == nil ? .red.opacity(0.08) : .green.opacity(0.08))
                    : Color(nsColor: .textBackgroundColor)

                HStack(spacing: 0) {
                    cell(Text(key).foregroundStyle(.primary), width: 140, bg: rowBg)
                    Divider()
                    cell(
                        Text(oldVal ?? "—")
                            .foregroundStyle(oldVal == nil ? .tertiary : .primary)
                            .strikethrough(changed && oldVal != nil),
                        bg: changed && newVal != nil ? .red.opacity(0.10) : rowBg
                    )
                    Divider()
                    cell(
                        Text(newVal ?? "—")
                            .foregroundStyle(newVal == nil ? .tertiary : .primary),
                        bg: changed && newVal != nil ? .green.opacity(0.10) : rowBg
                    )
                }
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 22)

                Divider()
            }
        }
    }

    @ViewBuilder
    private func cell(
        _ content: some View,
        width: CGFloat? = nil,
        bg: Color
    ) -> some View {
        content
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .frame(width: width)
    }

    private func parseFrontMatter(_ lines: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed != "---", !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !key.isEmpty { result[key] = value }
        }
        return result
    }
}

// MARK: - Prose hunk (word-level highlights)

private struct MarkdownDiffHunkView: View {
    let hunk: DiffHunk
    let mode: DiffViewModel.DisplayMode

    var body: some View {
        VStack(spacing: 0) {
            HunkHeaderRow(header: hunk.header)

            if mode == .inline {
                ForEach(inlineProsePairs(hunk.lines), id: \.id) { pair in
                    ProseInlineRowView(pair: pair)
                }
            } else {
                ForEach(sideBySidePairs(hunk.lines), id: \.id) { pair in
                    ProseSideBySideRowView(pair: pair)
                }
            }
        }
    }

    // MARK: - Pairing for word-level diff

    struct ProsePair: Identifiable {
        let id = UUID()
        let removed: DiffLine?
        let added: DiffLine?
        /// nil means the whole line is the change (no word-diff computed)
        let removedWordRanges: [Range<String.Index>]
        let addedWordRanges: [Range<String.Index>]
    }

    /// Groups adjacent removed/added blocks and computes word diffs per pair.
    private func inlineProsePairs(_ lines: [DiffLine]) -> [ProsePair] {
        var pairs: [ProsePair] = []
        var removedBuf: [DiffLine] = []
        var addedBuf: [DiffLine] = []

        func flush() {
            let count = max(removedBuf.count, addedBuf.count)
            for idx in 0..<count {
                let rem = idx < removedBuf.count ? removedBuf[idx] : nil
                let add = idx < addedBuf.count ? addedBuf[idx] : nil
                let (remRanges, addRanges): ([Range<String.Index>], [Range<String.Index>])
                if let r = rem, let a = add {
                    (remRanges, addRanges) = WordDiff.compute(old: r.content, new: a.content)
                } else {
                    (remRanges, addRanges) = ([], [])
                }
                pairs.append(ProsePair(
                    removed: rem,
                    added: add,
                    removedWordRanges: remRanges,
                    addedWordRanges: addRanges
                ))
            }
            removedBuf = []
            addedBuf = []
        }

        for line in lines {
            switch line.kind {
            case .context:
                flush()
                pairs.append(ProsePair(removed: nil, added: line, removedWordRanges: [], addedWordRanges: []))
            case .removed:
                if !addedBuf.isEmpty { flush() }
                removedBuf.append(line)
            case .added:
                addedBuf.append(line)
            }
        }
        flush()
        return pairs
    }

    /// Same pairing but for side-by-side layout — includes lone removed/added lines.
    private func sideBySidePairs(_ lines: [DiffLine]) -> [ProsePair] {
        // Reuse inline logic — the same pairs work for side-by-side
        inlineProsePairs(lines)
    }
}

// MARK: - Inline prose row

private struct ProseInlineRowView: View {
    let pair: MarkdownDiffHunkView.ProsePair

    var body: some View {
        VStack(spacing: 0) {
            // Context line (stored in `added` when `removed` is nil and kind==.context)
            if pair.removed == nil, let ctx = pair.added, ctx.kind == .context {
                proseRow(text: ctx.content, wordRanges: [], bg: Color(nsColor: .textBackgroundColor), sigil: " ", sigilColor: .secondary)
            } else {
                if let rem = pair.removed {
                    proseRow(
                        text: rem.content,
                        wordRanges: pair.removedWordRanges,
                        bg: .red.opacity(0.10),
                        sigil: "-",
                        sigilColor: .red.opacity(0.8),
                        highlightColor: Color(nsColor: .systemRed)
                    )
                }
                if let add = pair.added {
                    proseRow(
                        text: add.content,
                        wordRanges: pair.addedWordRanges,
                        bg: .green.opacity(0.10),
                        sigil: "+",
                        sigilColor: .green.opacity(0.8),
                        highlightColor: Color(nsColor: .systemGreen)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func proseRow(
        text: String,
        wordRanges: [Range<String.Index>],
        bg: Color,
        sigil: String,
        sigilColor: Color,
        highlightColor: Color = .clear
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(sigil)
                .foregroundStyle(sigilColor)
                .frame(width: 16, alignment: .center)
                .padding(.top, 3)

            buildHighlightedText(text: text, ranges: wordRanges, color: highlightColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
                .padding(.vertical, 3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
        .background(bg)
    }
}

// MARK: - Side-by-side prose row

private struct ProseSideBySideRowView: View {
    let pair: MarkdownDiffHunkView.ProsePair

    var body: some View {
        HStack(spacing: 0) {
            halfPane(
                line: pair.removed ?? (pair.added?.kind == .context ? pair.added : nil),
                ranges: pair.removedWordRanges,
                bg: pair.removed != nil ? .red.opacity(0.10) : Color(nsColor: .textBackgroundColor),
                highlightColor: Color(nsColor: .systemRed)
            )
            Divider()
            halfPane(
                line: pair.added,
                ranges: pair.addedWordRanges,
                bg: pair.added != nil && pair.added?.kind == .added
                    ? .green.opacity(0.10)
                    : Color(nsColor: .textBackgroundColor),
                highlightColor: Color(nsColor: .systemGreen)
            )
        }
    }

    @ViewBuilder
    private func halfPane(
        line: DiffLine?,
        ranges: [Range<String.Index>],
        bg: Color,
        highlightColor: Color
    ) -> some View {
        Group {
            if let line {
                buildHighlightedText(text: line.content, ranges: ranges, color: highlightColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Color(nsColor: .controlBackgroundColor)
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 13))
        .background(bg)
    }
}

// MARK: - Highlighted Text builder (shared)

/// Builds a concatenated `Text` with word-level highlights using foreground color + bold.
/// (`.background()` on `Text` returns `some View`, breaking `+` concatenation — so we use
/// `.foregroundStyle()` + `.bold()` which both return `Text` and compose cleanly.)
func buildHighlightedText(
    text: String,
    ranges: [Range<String.Index>],
    color: Color
) -> Text {
    guard !ranges.isEmpty else { return Text(text) }

    let sorted = ranges
        .filter { $0.lowerBound < text.endIndex && $0.upperBound <= text.endIndex }
        .sorted { $0.lowerBound < $1.lowerBound }

    var result = Text("")
    var pos = text.startIndex

    for range in sorted {
        guard range.lowerBound >= pos else { continue }
        if range.lowerBound > pos {
            result = result + Text(String(text[pos..<range.lowerBound]))
        }
        // foregroundStyle + bold both return Text, so + stays valid
        result = result + Text(String(text[range])).foregroundStyle(color).bold()
        pos = range.upperBound
    }
    if pos < text.endIndex {
        result = result + Text(String(text[pos...]))
    }
    return result
}

// MARK: - Word-level LCS diff

enum WordDiff {
    struct Token {
        let text: String
        let range: Range<String.Index>
    }

    /// Returns ranges in `old` that changed (to remove) and ranges in `new` that changed (to add).
    /// Falls back to empty ranges (whole-line highlight) when either string is excessively long.
    static func compute(
        old: String,
        new: String
    ) -> (removedRanges: [Range<String.Index>], addedRanges: [Range<String.Index>]) {
        let oldTokens = tokenize(old)
        let newTokens = tokenize(new)

        // Guard against pathologically long lines
        guard oldTokens.count <= 200, newTokens.count <= 200 else {
            return ([], [])
        }

        let m = oldTokens.count
        let n = newTokens.count

        guard m > 0, n > 0 else {
            return ([], [])
        }

        // DP LCS table
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if oldTokens[i - 1].text == newTokens[j - 1].text {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to find changed token indices
        var removedIdx: [Int] = []
        var addedIdx: [Int] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldTokens[i - 1].text == newTokens[j - 1].text {
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                addedIdx.insert(j - 1, at: 0)
                j -= 1
            } else {
                removedIdx.insert(i - 1, at: 0)
                i -= 1
            }
        }

        // Skip whitespace-only tokens — they create too much noise in prose
        let removedRanges = removedIdx
            .map { oldTokens[$0] }
            .filter { !$0.text.allSatisfy(\.isWhitespace) }
            .map(\.range)
        let addedRanges = addedIdx
            .map { newTokens[$0] }
            .filter { !$0.text.allSatisfy(\.isWhitespace) }
            .map(\.range)

        return (removedRanges, addedRanges)
    }

    /// Splits text into alternating word / whitespace tokens, preserving ranges.
    static func tokenize(_ text: String) -> [Token] {
        guard !text.isEmpty else { return [] }
        var tokens: [Token] = []
        var start = text.startIndex
        var inWord = !text[start].isWhitespace

        var idx = text.index(after: text.startIndex)
        while idx < text.endIndex {
            let charIsWord = !text[idx].isWhitespace
            if charIsWord != inWord {
                tokens.append(Token(text: String(text[start..<idx]), range: start..<idx))
                start = idx
                inWord = charIsWord
            }
            idx = text.index(after: idx)
        }
        tokens.append(Token(text: String(text[start...]), range: start..<text.endIndex))
        return tokens
    }
}
