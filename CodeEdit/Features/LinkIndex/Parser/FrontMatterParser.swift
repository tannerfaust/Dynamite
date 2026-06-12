// swiftlint:disable cyclomatic_complexity function_body_length identifier_name missing_docs
import Foundation

public enum FrontMatterParser {
    public static func parse(contents: String) -> ParsedFrontMatter {
        var parsed = ParsedFrontMatter()

        let lines = contents.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return parsed
        }

        var frontMatterLines: [String] = []
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                break
            }
            frontMatterLines.append(line)
        }

        var i = 0
        while i < frontMatterLines.count {
            let line = frontMatterLines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { i += 1; continue }

            let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { i += 1; continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let valueStr = String(parts[1]).trimmingCharacters(in: .whitespaces)

            if key == "links" || key == "code" {
                i += 1
                while i < frontMatterLines.count {
                    let arrLine = frontMatterLines[i].trimmingCharacters(in: .whitespaces)
                    if arrLine.hasPrefix("-") {
                        if key == "links" {
                            if let link = parseFlowMappingLink(arrLine) {
                                parsed.links.append(link)
                            }
                        } else {
                            if let codeLink = parseFlowMappingCodeLink(arrLine) {
                                parsed.codeLinks.append(codeLink)
                            }
                        }
                        i += 1
                    } else if arrLine.isEmpty || arrLine.hasPrefix("#") {
                        i += 1
                    } else {
                        break
                    }
                }
                continue
            }

            let value = removeQuotes(valueStr)
            switch key {
            case "id": parsed.id = value
            case "kind": parsed.kind = value
            case "status": parsed.status = value
            case "title": parsed.title = value
            case "created": parsed.created = value
            case "updated": parsed.updated = value
            case "tags":
                parsed.tags = parseFlowArray(valueStr)
            default:
                parsed.extraKeys[key] = value
            }
            i += 1
        }

        return parsed
    }

    private static func removeQuotes(_ str: String) -> String {
        var res = str
        if (res.hasPrefix("\"") && res.hasSuffix("\"")) || (res.hasPrefix("'") && res.hasSuffix("'")) {
            res.removeFirst()
            res.removeLast()
        }
        return res
    }

    private static func parseFlowArray(_ str: String) -> [String] {
        var s = str
        if s.hasPrefix("[") { s.removeFirst() }
        if s.hasSuffix("]") { s.removeLast() }
        return s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func parseFlowMappingLink(_ str: String) -> ParsedFrontMatter.ParsedLink? {
        let dict = parseFlowMapping(str)
        guard let rel = dict["rel"], let to = dict["to"] else { return nil }
        return ParsedFrontMatter.ParsedLink(rel: rel, to: to, label: dict["label"])
    }

    private static func parseFlowMappingCodeLink(_ str: String) -> ParsedFrontMatter.ParsedCodeLink? {
        let dict = parseFlowMapping(str)
        guard let path = dict["path"], let anchor = dict["anchor"] else { return nil }
        return ParsedFrontMatter.ParsedCodeLink(path: path, symbol: dict["symbol"], anchor: anchor)
    }

    private static func parseFlowMapping(_ str: String) -> [String: String] {
        var s = str
        if s.hasPrefix("-") { s.removeFirst() }
        s = s.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("{") { s.removeFirst() }
        if s.hasSuffix("}") { s.removeLast() }

        var dict: [String: String] = [:]

        let pattern = #"(?<key>[a-zA-Z0-9_-]+)\s*:\s*(?:"(?<val1>[^"]*)"|'(?<val2>[^']*)'|(?<val3>[^,}]*))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return dict }

        let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
        for match in matches {
            let keyRange = match.range(withName: "key")
            guard let key = substring(of: s, with: keyRange) else { continue }

            let val1Range = match.range(withName: "val1")
            let val2Range = match.range(withName: "val2")
            let val3Range = match.range(withName: "val3")

            var val: String?
            if val1Range.location != NSNotFound {
                val = substring(of: s, with: val1Range)
            } else if val2Range.location != NSNotFound {
                val = substring(of: s, with: val2Range)
            } else if val3Range.location != NSNotFound {
                val = substring(of: s, with: val3Range)?.trimmingCharacters(in: .whitespaces)
            }

            if let val { dict[key] = val }
        }

        return dict
    }

    private static func substring(of string: String, with range: NSRange) -> String? {
        guard let r = Range(range, in: string) else { return nil }
        return String(string[r])
    }
}
