//
//  FrontMatterEditor.swift
//  CodeEdit
//

import Foundation

/// Parses and re-serializes product artifact front-matter with round-trip safety.
///
/// The read path (`parse`) extracts known fields while preserving unknown ones in
/// `extraFields`. The write path (`serialize`) produces the canonical format defined
/// in ADR-0001 §1, atomically preserving extra fields verbatim — Dynamite never
/// auto-corrects content it doesn't own.
enum FrontMatterEditor {

    // MARK: - Parsed model

    struct Parsed {
        var id: String
        var kind: String
        var status: String
        var title: String
        var tags: [String]
        var links: [ParsedLink]
        var created: String
        var updated: String
        /// Unknown front-matter fields preserved in declaration order (e.g. `subject`, `horizon`).
        var extraFields: [(key: String, value: String)]
        /// Markdown body — everything after the closing `---`.
        var body: String

        struct ParsedLink: Identifiable {
            let id: UUID
            var rel: String
            // swiftlint:disable:next identifier_name
            var to: String
            var label: String?

            // swiftlint:disable:next identifier_name
            init(id: UUID = UUID(), rel: String, to: String, label: String?) {
                self.id = id; self.rel = rel; self.to = to; self.label = label
            }
        }
    }

    // MARK: - Parse

    /// Returns nil if the file does not start with `---` (not a front-matter document).
    static func parse(fileContents: String) -> Parsed? {
        let lines = fileContents.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var closeIdx: Int?
        for idx in 1..<lines.count where lines[idx].trimmingCharacters(in: .whitespaces) == "---" {
            closeIdx = idx; break
        }
        guard let closeIdx else { return nil }

        let fmLines = Array(lines[1..<closeIdx])
        let bodyLines = closeIdx + 1 < lines.count ? Array(lines[(closeIdx + 1)...]) : []
        // Drop the leading blank line that conventionally separates --- from body.
        let body = bodyLines.first?.isEmpty == true
            ? bodyLines.dropFirst().joined(separator: "\n")
            : bodyLines.joined(separator: "\n")

        var result = Parsed(
            id: "", kind: "", status: "draft", title: "",
            tags: [], links: [], created: "", updated: "",
            extraFields: [], body: body
        )

        var lineIdx = 0
        while lineIdx < fmLines.count {
            let trimmed = fmLines[lineIdx].trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let colonPos = trimmed.firstIndex(of: ":") else { lineIdx += 1; continue }

            let key = String(trimmed[trimmed.startIndex..<colonPos]).trimmingCharacters(in: .whitespaces)
            let rawVal = String(trimmed[trimmed.index(after: colonPos)...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "id", "kind", "status", "title", "created", "updated", "tags":
                applyScalarField(key: key, value: rawVal, into: &result)
            case "v":
                break  // schema version — not user-editable
            case "links":
                lineIdx += 1
                lineIdx = parseListEntries(lines: fmLines, from: lineIdx, into: &result.links, parser: parseLink)
                continue
            case "code":
                lineIdx += 1
                lineIdx = skipListEntries(lines: fmLines, from: lineIdx)
                continue
            default:
                result.extraFields.append((key: key, value: unquote(rawVal)))
            }
            lineIdx += 1
        }
        return result
    }

    // MARK: - Serialize

    /// Writes back a `Parsed` value to the canonical front-matter format.
    /// Pass `today` to update the `updated:` field; otherwise the stored value is kept.
    static func serialize(_ parsed: Parsed, today: String? = nil) -> String {
        var out: [String] = ["---"]
        out.append("id: \(parsed.id)")
        out.append("kind: \(parsed.kind)")
        out.append("status: \(parsed.status)")
        out.append("created: \(parsed.created)")
        out.append("updated: \(today ?? parsed.updated)")
        out.append("v: 1")
        if !parsed.title.isEmpty { out.append("title: \(parsed.title)") }
        out.append(parsed.tags.isEmpty ? "tags: []" : "tags: [\(parsed.tags.joined(separator: ", "))]")
        for extra in parsed.extraFields { out.append("\(extra.key): \(extra.value)") }
        if parsed.links.isEmpty {
            out.append("links: []")
        } else {
            out.append("links:")
            for link in parsed.links {
                var line = "  - { rel: \(link.rel), to: \(link.to)"
                if let label = link.label, !label.isEmpty {
                    let escaped = label.replacingOccurrences(of: "\"", with: "\\\"")
                    line += ", label: \"\(escaped)\""
                }
                line += " }"
                out.append(line)
            }
        }
        out.append("---")
        out.append("")
        if !parsed.body.isEmpty { out.append(parsed.body) }
        return out.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private static func applyScalarField(key: String, value: String, into result: inout Parsed) {
        switch key {
        case "id":      result.id = unquote(value)
        case "kind":    result.kind = unquote(value)
        case "status":  result.status = unquote(value)
        case "title":   result.title = unquote(value)
        case "created": result.created = unquote(value)
        case "updated": result.updated = unquote(value)
        case "tags":    result.tags = parseFlowArray(value)
        default: break
        }
    }

    private static func parseListEntries(
        lines: [String],
        from startIdx: Int,
        into collection: inout [Parsed.ParsedLink],
        parser: (String) -> Parsed.ParsedLink?
    ) -> Int {
        var idx = startIdx
        while idx < lines.count {
            let arr = lines[idx].trimmingCharacters(in: .whitespaces)
            if arr.hasPrefix("-") {
                if let link = parser(arr) { collection.append(link) }
                idx += 1
            } else if arr.isEmpty || arr.hasPrefix("#") {
                idx += 1
            } else {
                break
            }
        }
        return idx
    }

    private static func skipListEntries(lines: [String], from startIdx: Int) -> Int {
        var idx = startIdx
        while idx < lines.count {
            let arr = lines[idx].trimmingCharacters(in: .whitespaces)
            if arr.hasPrefix("-") || arr.isEmpty || arr.hasPrefix("#") {
                idx += 1
            } else {
                break
            }
        }
        return idx
    }

    private static func unquote(_ str: String) -> String {
        var result = str
        if result.count >= 2,
           (result.hasPrefix("\"") && result.hasSuffix("\"")) ||
           (result.hasPrefix("'") && result.hasSuffix("'")) {
            result.removeFirst(); result.removeLast()
        }
        return result
    }

    private static func parseFlowArray(_ str: String) -> [String] {
        var raw = str
        if raw.hasPrefix("[") { raw.removeFirst() }
        if raw.hasSuffix("]") { raw.removeLast() }
        return raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func parseLink(_ raw: String) -> Parsed.ParsedLink? {
        let dict = parseFlowMapping(raw)
        guard let rel = dict["rel"], let target = dict["to"] else { return nil }
        return Parsed.ParsedLink(rel: rel, to: target, label: dict["label"])
    }

    private static func parseFlowMapping(_ raw: String) -> [String: String] {
        var str = raw.trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("-") { str = String(str.dropFirst()).trimmingCharacters(in: .whitespaces) }
        if str.hasPrefix("{") { str.removeFirst() }
        if str.hasSuffix("}") { str.removeLast() }
        var result: [String: String] = [:]
        for part in str.split(separator: ",") {
            let halves = part.split(separator: ":", maxSplits: 1)
            guard halves.count == 2 else { continue }
            let key = String(halves[0]).trimmingCharacters(in: .whitespaces)
            var val = String(halves[1]).trimmingCharacters(in: .whitespaces)
            if val.count >= 2,
               (val.hasPrefix("\"") && val.hasSuffix("\"")) ||
               (val.hasPrefix("'") && val.hasSuffix("'")) {
                val.removeFirst(); val.removeLast()
            }
            result[key] = val
        }
        return result
    }
}
