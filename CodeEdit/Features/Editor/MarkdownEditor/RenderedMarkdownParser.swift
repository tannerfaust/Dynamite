//
//  RenderedMarkdownParser.swift
//  CodeEdit
//

import Foundation

struct RenderedMarkdownParser {
    func parse(_ markdown: String) -> RenderedMarkdownDocument {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [RenderedMarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            if let block = parseFencedCode(lines: lines, index: &index) {
                blocks.append(block)
            } else if let block = parseTable(lines: lines, index: &index) {
                blocks.append(block)
            } else if let block = parseHeading(lines: lines, index: &index) {
                blocks.append(block)
            } else if let block = parseBlockquote(lines: lines, index: &index) {
                blocks.append(block)
            } else if let block = parseList(lines: lines, index: &index) {
                blocks.append(block)
            } else if isHorizontalRule(line) {
                blocks.append(.horizontalRule)
                index += 1
            } else {
                blocks.append(parseParagraph(lines: lines, index: &index))
            }
        }

        return RenderedMarkdownDocument(blocks: blocks)
    }

    // MARK: - Blocks

    private func parseFencedCode(lines: [String], index: inout Int) -> RenderedMarkdownBlock? {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        guard let fence = fenceMarker(in: line) else { return nil }

        let language = line.dropFirst(fence.count)
            .trimmingCharacters(in: .whitespaces)
            .nilIfEmpty
        index += 1

        var codeLines: [String] = []
        while index < lines.count {
            let candidate = lines[index].trimmingCharacters(in: .whitespaces)
            if candidate.hasPrefix(fence) {
                index += 1
                break
            }
            codeLines.append(lines[index])
            index += 1
        }

        return .codeBlock(language: language, code: codeLines.joined(separator: "\n"))
    }

    private func parseTable(lines: [String], index: inout Int) -> RenderedMarkdownBlock? {
        guard index + 1 < lines.count,
              lines[index].contains("|"),
              let alignments = parseTableSeparator(lines[index + 1]) else {
            return nil
        }

        let headerCells = splitTableCells(lines[index])
        guard headerCells.count == alignments.count else { return nil }

        index += 2
        var rows: [RenderedMarkdownTableRow] = []

        while index < lines.count {
            let line = lines[index]
            guard line.contains("|"),
                  !line.trimmingCharacters(in: .whitespaces).isEmpty,
                  parseTableSeparator(line) == nil else {
                break
            }
            let cells = normalizedTableCells(splitTableCells(line), columnCount: alignments.count)
            rows.append(RenderedMarkdownTableRow(cells: cells.map(parseInlines)))
            index += 1
        }

        return .table(RenderedMarkdownTable(
            header: RenderedMarkdownTableRow(cells: headerCells.map(parseInlines)),
            alignments: alignments,
            rows: rows
        ))
    }

    private func parseHeading(lines: [String], index: inout Int) -> RenderedMarkdownBlock? {
        let line = lines[index]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#") {
            let level = trimmed.prefix { $0 == "#" }.count
            guard (1...6).contains(level),
                  trimmed.count > level,
                  trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)] == " " else {
                return nil
            }
            var content = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            while content.hasSuffix("#") {
                content.removeLast()
            }
            index += 1
            return .heading(level: level, inlines: parseInlines(content.trimmingCharacters(in: .whitespaces)))
        }

        if index + 1 < lines.count,
           !trimmed.isEmpty,
           !trimmed.hasPrefix("|"),
           let level = setextHeadingLevel(lines[index + 1]) {
            index += 2
            return .heading(level: level, inlines: parseInlines(trimmed))
        }

        return nil
    }

    private func parseBlockquote(lines: [String], index: inout Int) -> RenderedMarkdownBlock? {
        guard let first = strippedBlockquoteLine(lines[index]) else { return nil }

        var quoteLines = [first]
        index += 1
        while index < lines.count, let stripped = strippedBlockquoteLine(lines[index]) {
            quoteLines.append(stripped)
            index += 1
        }

        return .blockquote(parse(quoteLines.joined(separator: "\n")).blocks)
    }

    private func parseList(lines: [String], index: inout Int) -> RenderedMarkdownBlock? {
        guard let marker = listMarker(in: lines[index]) else { return nil }
        var items: [RenderedMarkdownListItem] = []
        let ordered = marker.kind == .ordered
        let start = marker.number ?? 1

        while index < lines.count,
              let nextMarker = listMarker(in: lines[index]),
              (nextMarker.kind == .ordered) == ordered {
            items.append(RenderedMarkdownListItem(
                taskState: nextMarker.taskState,
                inlines: parseInlines(nextMarker.content)
            ))
            index += 1
        }

        return ordered ? .orderedList(start: start, items: items) : .unorderedList(items)
    }

    private func parseParagraph(lines: [String], index: inout Int) -> RenderedMarkdownBlock {
        var paragraphLines: [String] = []

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty || isBlockStart(lines: lines, index: index) {
                break
            }
            paragraphLines.append(line.trimmingCharacters(in: .whitespaces))
            index += 1
        }

        if paragraphLines.isEmpty, index < lines.count {
            paragraphLines.append(lines[index].trimmingCharacters(in: .whitespaces))
            index += 1
        }

        return .paragraph(parseInlines(paragraphLines.joined(separator: " ")))
    }

    // MARK: - Inline

    func parseInlines(_ text: String) -> [RenderedMarkdownInline] {
        parseInlines(text, start: text.startIndex, end: text.endIndex)
    }

    private func parseInlines(
        _ text: String,
        start: String.Index,
        end: String.Index
    ) -> [RenderedMarkdownInline] {
        var result: [RenderedMarkdownInline] = []
        var buffer = ""
        var index = start

        func flush() {
            guard !buffer.isEmpty else { return }
            result.append(.text(buffer))
            buffer = ""
        }

        while index < end {
            if text[index] == "`",
               let close = text[index...].dropFirst().firstIndex(of: "`") {
                flush()
                result.append(.code(String(text[text.index(after: index)..<close])))
                index = text.index(after: close)
                continue
            }

            if text[index...].hasPrefix("!["),
               let parsed = parseLinkLike(text, from: index, end: end, image: true) {
                flush()
                result.append(.image(alt: parsed.label, source: parsed.destination))
                index = parsed.end
                continue
            }

            if text[index] == "[",
               let parsed = parseLinkLike(text, from: index, end: end, image: false) {
                flush()
                result.append(.link(
                    label: parseInlines(parsed.label),
                    destination: parsed.destination
                ))
                index = parsed.end
                continue
            }

            if text[index] == "<",
               let close = text[index...].firstIndex(of: ">") {
                let labelStart = text.index(after: index)
                let label = String(text[labelStart..<close])
                if label.hasPrefix("http://") || label.hasPrefix("https://") || label.hasPrefix("mailto:") {
                    flush()
                    result.append(.link(label: [.text(label)], destination: label))
                    index = text.index(after: close)
                    continue
                }
            }

            if text[index...].hasPrefix("***"),
               let close = findClosing("***", in: text, after: text.index(index, offsetBy: 3), end: end) {
                flush()
                let innerStart = text.index(index, offsetBy: 3)
                result.append(.strongEmphasis(parseInlines(text, start: innerStart, end: close)))
                index = text.index(close, offsetBy: 3)
                continue
            }

            if text[index...].hasPrefix("**"),
               let close = findClosing("**", in: text, after: text.index(index, offsetBy: 2), end: end) {
                flush()
                let innerStart = text.index(index, offsetBy: 2)
                result.append(.strong(parseInlines(text, start: innerStart, end: close)))
                index = text.index(close, offsetBy: 2)
                continue
            }

            if text[index...].hasPrefix("__"),
               let close = findClosing("__", in: text, after: text.index(index, offsetBy: 2), end: end) {
                flush()
                let innerStart = text.index(index, offsetBy: 2)
                result.append(.strong(parseInlines(text, start: innerStart, end: close)))
                index = text.index(close, offsetBy: 2)
                continue
            }

            if text[index...].hasPrefix("~~"),
               let close = findClosing("~~", in: text, after: text.index(index, offsetBy: 2), end: end) {
                flush()
                let innerStart = text.index(index, offsetBy: 2)
                result.append(.strikethrough(parseInlines(text, start: innerStart, end: close)))
                index = text.index(close, offsetBy: 2)
                continue
            }

            if text[index] == "*",
               let close = findClosing("*", in: text, after: text.index(after: index), end: end) {
                flush()
                result.append(.emphasis(parseInlines(text, start: text.index(after: index), end: close)))
                index = text.index(after: close)
                continue
            }

            if text[index] == "_",
               let close = findClosing("_", in: text, after: text.index(after: index), end: end) {
                flush()
                result.append(.emphasis(parseInlines(text, start: text.index(after: index), end: close)))
                index = text.index(after: close)
                continue
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }

        flush()
        return result
    }

    // MARK: - Helpers

    private func isBlockStart(lines: [String], index: Int) -> Bool {
        parseFencedCodeStart(lines[index])
            || (index + 1 < lines.count && parseTableSeparator(lines[index + 1]) != nil && lines[index].contains("|"))
            || parseHeadingStart(lines: lines, index: index)
            || strippedBlockquoteLine(lines[index]) != nil
            || listMarker(in: lines[index]) != nil
            || isHorizontalRule(lines[index])
    }

    private func parseFencedCodeStart(_ line: String) -> Bool {
        fenceMarker(in: line.trimmingCharacters(in: .whitespaces)) != nil
    }

    private func fenceMarker(in line: String) -> String? {
        if line.hasPrefix("```") { return "```" }
        if line.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    private func parseHeadingStart(lines: [String], index: Int) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            let level = trimmed.prefix { $0 == "#" }.count
            return (1...6).contains(level)
                && trimmed.count > level
                && trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)] == " "
        }
        return index + 1 < lines.count
            && !trimmed.isEmpty
            && !trimmed.hasPrefix("|")
            && setextHeadingLevel(lines[index + 1]) != nil
    }

    private func setextHeadingLevel(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.allSatisfy({ $0 == "=" }) { return 1 }
        if trimmed.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        let compact = trimmed.filter { !$0.isWhitespace }
        guard let first = compact.first, ["-", "*", "_"].contains(first) else { return false }
        return compact.count >= 3 && compact.allSatisfy { $0 == first }
    }

    private func strippedBlockquoteLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }
        let afterMarker = trimmed.dropFirst()
        return String(afterMarker.drop(while: { $0 == " " || $0 == "\t" }))
    }

    private enum ListKind {
        case unordered
        case ordered
    }

    private struct ListMarker {
        var kind: ListKind
        var number: Int?
        var taskState: RenderedMarkdownTaskState?
        var content: String
    }

    private func listMarker(in line: String) -> ListMarker? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let first = trimmed.first, ["-", "*", "+"].contains(first) {
            let afterMarker = trimmed.dropFirst()
            guard afterMarker.first?.isWhitespace == true else { return nil }
            return unorderedMarker(content: String(afterMarker.drop(while: \.isWhitespace)))
        }

        let digits = trimmed.prefix(while: \.isNumber)
        guard !digits.isEmpty,
              let marker = trimmed.dropFirst(digits.count).first,
              marker == "." || marker == ")" else {
            return nil
        }
        let afterMarker = trimmed.dropFirst(digits.count + 1)
        guard afterMarker.first?.isWhitespace == true else { return nil }
        return ListMarker(
            kind: .ordered,
            number: Int(digits),
            taskState: nil,
            content: String(afterMarker.drop(while: \.isWhitespace))
        )
    }

    private func unorderedMarker(content: String) -> ListMarker {
        if content.hasPrefix("[ ] ") {
            return ListMarker(kind: .unordered, number: nil, taskState: .unchecked, content: String(content.dropFirst(4)))
        }
        if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
            return ListMarker(kind: .unordered, number: nil, taskState: .checked, content: String(content.dropFirst(4)))
        }
        return ListMarker(kind: .unordered, number: nil, taskState: nil, content: content)
    }

    private func parseTableSeparator(_ line: String) -> [RenderedMarkdownColumnAlignment]? {
        let cells = splitTableCells(line)
        guard cells.count >= 2 else { return nil }

        var alignments: [RenderedMarkdownColumnAlignment] = []
        for cell in cells {
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let core = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard core.count >= 3, core.allSatisfy({ $0 == "-" }) else { return nil }

            if trimmed.hasPrefix(":") && trimmed.hasSuffix(":") {
                alignments.append(.center)
            } else if trimmed.hasSuffix(":") {
                alignments.append(.trailing)
            } else {
                alignments.append(.leading)
            }
        }
        return alignments
    }

    private func splitTableCells(_ line: String) -> [String] {
        var content = line.trimmingCharacters(in: .whitespaces)
        if content.hasPrefix("|") { content.removeFirst() }
        if content.hasSuffix("|") { content.removeLast() }

        var cells: [String] = []
        var current = ""
        var escaped = false

        for character in content {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private func normalizedTableCells(_ cells: [String], columnCount: Int) -> [String] {
        if cells.count >= columnCount {
            return Array(cells.prefix(columnCount))
        }
        return cells + Array(repeating: "", count: columnCount - cells.count)
    }

    private func parseLinkLike(
        _ text: String,
        from start: String.Index,
        end: String.Index,
        image: Bool
    ) -> (label: String, destination: String, end: String.Index)? {
        let labelStart = image ? text.index(start, offsetBy: 2) : text.index(after: start)
        guard labelStart <= end,
              let labelEnd = text[labelStart..<end].firstIndex(of: "]"),
              text.index(after: labelEnd) < end,
              text[text.index(after: labelEnd)] == "(",
              let destinationEnd = text[text.index(labelEnd, offsetBy: 2)..<end].firstIndex(of: ")") else {
            return nil
        }

        let destinationStart = text.index(labelEnd, offsetBy: 2)
        return (
            String(text[labelStart..<labelEnd]),
            String(text[destinationStart..<destinationEnd]),
            text.index(after: destinationEnd)
        )
    }

    private func findClosing(
        _ marker: String,
        in text: String,
        after start: String.Index,
        end: String.Index
    ) -> String.Index? {
        var index = start
        while index < end {
            if text[index...].hasPrefix(marker) {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
