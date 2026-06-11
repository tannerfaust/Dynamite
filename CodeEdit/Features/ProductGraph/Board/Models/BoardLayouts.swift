//
//  BoardLayouts.swift
//  CodeEdit
//

import Foundation

extension ArtifactKind {
    /// Kinds that render a native board view instead of (or alongside) raw markdown.
    var supportsBoardView: Bool {
        switch self {
        case .vpc, .bmc, .leanCanvas, .journey, .storyMap, .ost:
            return true
        default:
            return false
        }
    }

    /// Canonical H2 headings for fixed-layout canvas blocks (nil = dynamic from document).
    var boardBlockHeadings: [String]? {
        switch self {
        case .vpc:
            return [
                "Customer Jobs", "Pains", "Gains",
                "Products & Services", "Pain Relievers", "Gain Creators"
            ]
        case .bmc:
            return [
                "Customer Segments", "Value Propositions", "Channels",
                "Customer Relationships", "Revenue Streams", "Key Resources",
                "Key Activities", "Key Partners", "Cost Structure"
            ]
        case .leanCanvas:
            return [
                "Problem", "Customer Segments", "Unique Value Proposition",
                "Solution", "Channels", "Revenue Streams",
                "Cost Structure", "Key Metrics", "Unfair Advantage"
            ]
        default:
            return nil
        }
    }

    /// Ensures a parsed document contains all expected blocks for fixed-layout canvases.
    func normalizedCanvasDocument(from document: CanvasDocument) -> CanvasDocument {
        guard let headings = boardBlockHeadings else { return document }
        var merged = document
        var byHeading = Dictionary(uniqueKeysWithValues: merged.sections.map { ($0.heading, $0) })
        merged.sections = headings.map { heading in
            byHeading[heading] ?? CanvasSection(heading: heading)
        }
        return merged
    }
}
