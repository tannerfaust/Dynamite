//
//  CanvasModels.swift
//  CodeEdit
//

import Foundation

/// Parsed markdown body for canvas-style artifacts (ADR-0001 §canvas kinds).
struct CanvasDocument: Equatable {
    var title: String
    var sections: [CanvasSection]

    init(title: String = "", sections: [CanvasSection] = []) {
        self.title = title
        self.sections = sections
    }
}

/// An H2 block in a canvas document (VPC block, journey stage, story-map activity).
struct CanvasSection: Identifiable, Equatable {
    let id: UUID
    var heading: String
    var guidance: String
    var cards: [CanvasCard]
    var subsections: [CanvasSubsection]

    init(
        id: UUID = UUID(),
        heading: String,
        guidance: String = "",
        cards: [CanvasCard] = [],
        subsections: [CanvasSubsection] = []
    ) {
        self.id = id
        self.heading = heading
        self.guidance = guidance
        self.cards = cards
        self.subsections = subsections
    }
}

/// An H3 lane inside a story-map activity.
struct CanvasSubsection: Identifiable, Equatable {
    let id: UUID
    var heading: String
    var guidance: String
    var cards: [CanvasCard]

    init(id: UUID = UUID(), heading: String, guidance: String = "", cards: [CanvasCard] = []) {
        self.id = id
        self.heading = heading
        self.guidance = guidance
        self.cards = cards
    }
}

/// A bullet card. Nested `  - { rel: … }` lines attach typed links to the card.
struct CanvasCard: Identifiable, Equatable {
    let id: UUID
    var text: String
    var links: [ProductArtifact.ArtifactLink]

    init(id: UUID = UUID(), text: String, links: [ProductArtifact.ArtifactLink] = []) {
        self.id = id
        self.text = text
        self.links = links
    }
}

/// Nested outline node for opportunity solution trees.
struct CanvasTreeNode: Identifiable, Equatable {
    let id: UUID
    var text: String
    var links: [ProductArtifact.ArtifactLink]
    var children: [CanvasTreeNode]

    init(
        id: UUID = UUID(),
        text: String,
        links: [ProductArtifact.ArtifactLink] = [],
        children: [CanvasTreeNode] = []
    ) {
        self.id = id
        self.text = text
        self.links = links
        self.children = children
    }

}

/// A roadmap column backed by `roadmap-item` artifacts.
struct RoadmapColumn: Identifiable, Equatable {
    let horizon: String
    var items: [ProductArtifact]

    var id: String { horizon }

    var title: String {
        switch horizon {
        case "now":   return "Now"
        case "next":  return "Next"
        case "later": return "Later"
        default:      return horizon.capitalized
        }
    }
}
