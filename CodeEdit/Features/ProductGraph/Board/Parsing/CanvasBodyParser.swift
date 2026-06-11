//
//  CanvasBodyParser.swift
//  CodeEdit
//

import Foundation

/// Parses and serializes canvas artifact bodies (H2 blocks, cards, nested OST trees).
///
/// Card links are stored as indented link lines under the card bullet:
/// ```
/// - Card text
///   - { rel: relates-to, to: prb-abc, label: "Core problem" }
/// ```
enum CanvasBodyParser {

    // MARK: - Parse

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parse(_ body: String) -> CanvasDocument {
        let lines = body.components(separatedBy: .newlines)
        var title = ""
        var sections: [CanvasSection] = []
        var currentSection: CanvasSection?
        var currentSubsection: CanvasSubsection?
        var pendingGuidanceTarget: GuidanceTarget?

        func flushSubsection() {
            guard var section = currentSection, let subsection = currentSubsection else { return }
            section.subsections.append(subsection)
            currentSection = section
            currentSubsection = nil
        }

        func flushSection() {
            flushSubsection()
            if let section = currentSection {
                sections.append(section)
            }
            currentSection = nil
        }

        for rawLine in lines {
            let line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("<!--") { continue }

            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if trimmed.hasPrefix("## ") {
                flushSection()
                let heading = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentSection = CanvasSection(heading: heading)
                pendingGuidanceTarget = .section
                continue
            }

            if trimmed.hasPrefix("### ") {
                flushSubsection()
                let heading = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                currentSubsection = CanvasSubsection(heading: heading)
                pendingGuidanceTarget = .subsection
                continue
            }

            if let guidance = parseGuidance(trimmed) {
                switch pendingGuidanceTarget {
                case .section:
                    currentSection?.guidance = guidance
                case .subsection:
                    currentSubsection?.guidance = guidance
                case .none:
                    break
                }
                pendingGuidanceTarget = nil
                continue
            }

            pendingGuidanceTarget = nil

            if let link = parseLinkBullet(trimmed), line.hasPrefix("  ") || line.hasPrefix("\t") {
                appendLink(link, to: &currentSection, subsection: &currentSubsection)
                continue
            }

            if trimmed.hasPrefix("- ") {
                let text = String(trimmed.dropFirst(2))
                let card = CanvasCard(text: text)
                if currentSubsection != nil {
                    currentSubsection?.cards.append(card)
                } else if currentSection != nil {
                    currentSection?.cards.append(card)
                } else {
                    currentSection = CanvasSection(heading: "Notes", cards: [card])
                }
                continue
            }
        }

        flushSection()
        return CanvasDocument(title: title, sections: sections)
    }

    /// Parses nested bullet lists into a tree (OST).
    static func parseTree(_ body: String) -> [CanvasTreeNode] {
        struct LineInfo {
            let indent: Int
            let text: String
            var links: [ProductArtifact.ArtifactLink]
        }

        var infos: [LineInfo] = []
        for rawLine in body.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("<!--") { continue }
            if trimmed.hasPrefix("#") { continue }
            if parseGuidance(trimmed) != nil { continue }

            let indent = rawLine.prefix(while: { $0 == " " }).count
            if trimmed.hasPrefix("- ") {
                let payload = String(trimmed.dropFirst(2))
                if let link = parseLinkMapping(payload), indent >= 2, !infos.isEmpty {
                    infos[infos.count - 1].links.append(link)
                    continue
                }
                infos.append(LineInfo(indent: indent, text: payload, links: []))
            }
        }

        guard !infos.isEmpty else { return [] }
        let baseIndent = infos.map(\.indent).min() ?? 0
        let flat = infos.map {
            FlatTreeLine(indent: $0.indent, text: $0.text, links: $0.links)
        }
        var index = 0
        return buildTree(flat: flat, index: &index, minIndent: baseIndent)
    }

    private struct FlatTreeLine {
        let indent: Int
        let text: String
        let links: [ProductArtifact.ArtifactLink]
    }

    private static func buildTree(
        flat: [FlatTreeLine],
        index: inout Int,
        minIndent: Int
    ) -> [CanvasTreeNode] {
        var nodes: [CanvasTreeNode] = []
        while index < flat.count {
            let item = flat[index]
            if item.indent < minIndent { break }
            guard item.indent == minIndent else { break }
            var node = CanvasTreeNode(text: item.text, links: item.links)
            index += 1
            if index < flat.count, flat[index].indent > minIndent {
                node.children = buildTree(flat: flat, index: &index, minIndent: minIndent + 2)
            }
            nodes.append(node)
        }
        return nodes
    }

    // MARK: - Serialize

    static func serialize(_ document: CanvasDocument) -> String {
        var lines: [String] = []
        if !document.title.isEmpty {
            lines.append("# \(document.title)")
            lines.append("")
        }
        for section in document.sections {
            lines.append("## \(section.heading)")
            if !section.guidance.isEmpty {
                lines.append("*\(section.guidance)*")
            }
            lines += serializeCards(section.cards)
            for subsection in section.subsections {
                lines.append("")
                lines.append("### \(subsection.heading)")
                if !subsection.guidance.isEmpty {
                    lines.append("*\(subsection.guidance)*")
                }
                lines += serializeCards(subsection.cards)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func serializeTree(_ nodes: [CanvasTreeNode], title: String) -> String {
        var lines: [String] = []
        if !title.isEmpty {
            lines.append("# \(title)")
            lines.append("")
        }
        lines.append("## Opportunity Solution Tree")
        lines.append("")
        serializeTreeNodes(nodes, indent: 0, into: &lines)
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private enum GuidanceTarget {
        case section
        case subsection
    }

    private static func parseGuidance(_ line: String) -> String? {
        guard line.hasPrefix("*"), line.hasSuffix("*"), line.count >= 2 else { return nil }
        let inner = String(line.dropFirst().dropLast())
        return inner.isEmpty ? nil : inner
    }

    private static func parseLinkBullet(_ trimmed: String) -> ProductArtifact.ArtifactLink? {
        guard trimmed.hasPrefix("- ") else { return nil }
        let payload = String(trimmed.dropFirst(2))
        return parseLinkMapping(payload)
    }

    private static func parseLinkMapping(_ raw: String) -> ProductArtifact.ArtifactLink? {
        var str = raw.trimmingCharacters(in: .whitespaces)
        guard str.hasPrefix("{"), str.hasSuffix("}") else { return nil }
        str.removeFirst(); str.removeLast()
        var dict: [String: String] = [:]
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
            dict[key] = val
        }
        guard let rel = dict["rel"], let target = dict["to"] else { return nil }
        return ProductArtifact.ArtifactLink(rel: rel, to: target, label: dict["label"])
    }

    private static func appendLink(
        _ link: ProductArtifact.ArtifactLink,
        to section: inout CanvasSection?,
        subsection: inout CanvasSubsection?
    ) {
        if var sub = subsection, !sub.cards.isEmpty {
            sub.cards[sub.cards.count - 1].links.append(link)
            subsection = sub
        } else if var sec = section, !sec.cards.isEmpty {
            sec.cards[sec.cards.count - 1].links.append(link)
            section = sec
        }
    }

    private static func serializeCards(_ cards: [CanvasCard]) -> [String] {
        var lines: [String] = []
        for card in cards {
            lines.append("- \(card.text)")
            for link in card.links {
                var line = "  - { rel: \(link.rel), to: \(link.to)"
                if let label = link.label, !label.isEmpty {
                    let escaped = label.replacingOccurrences(of: "\"", with: "\\\"")
                    line += ", label: \"\(escaped)\""
                }
                line += " }"
                lines.append(line)
            }
        }
        return lines
    }

    private static func serializeTreeNodes(_ nodes: [CanvasTreeNode], indent: Int, into lines: inout [String]) {
        let prefix = String(repeating: "  ", count: indent)
        for node in nodes {
            lines.append("\(prefix)- \(node.text)")
            for link in node.links {
                var line = "\(prefix)  - { rel: \(link.rel), to: \(link.to)"
                if let label = link.label, !label.isEmpty {
                    let escaped = label.replacingOccurrences(of: "\"", with: "\\\"")
                    line += ", label: \"\(escaped)\""
                }
                line += " }"
                lines.append(line)
            }
            serializeTreeNodes(node.children, indent: indent + 1, into: &lines)
        }
    }
}
