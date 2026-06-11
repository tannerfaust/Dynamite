//
//  ProductArtifact.swift
//  CodeEdit
//

import Foundation

/// In-memory representation of a parsed product artifact `.md` file.
///
/// The plain `.md` file is always authoritative (ADR-0001 §Constraints). This struct
/// is a view-model–friendly snapshot; `ArtifactStore.save(_:)` writes it back.
struct ProductArtifact: Identifiable, Equatable {
    /// The `id:` field from front-matter — immutable per ADR-0001 §1.
    let id: String
    /// Typed kind; nil if the `kind:` string is not a recognized catalog slug.
    var kind: ArtifactKind?
    /// Raw `kind:` string from front-matter (preserved for round-trip).
    var kindString: String
    var status: String
    var title: String
    var tags: [String]
    var links: [ArtifactLink]
    var created: String
    var updated: String
    /// Unknown front-matter fields preserved verbatim for round-trip safety.
    var extraFields: [String: String]
    /// Markdown body (everything after the closing `---`).
    var body: String
    /// Absolute file URL on disk.
    let url: URL

    var displayTitle: String {
        title.isEmpty ? url.deletingPathExtension().lastPathComponent : title
    }

    /// A typed link edge stored in the source file's front-matter (ADR-0001 §2).
    struct ArtifactLink: Identifiable, Equatable {
        let id: UUID
        var rel: String
        // swiftlint:disable:next identifier_name
        var to: String
        var label: String?

        // swiftlint:disable:next identifier_name
        init(id: UUID = UUID(), rel: String, to: String, label: String? = nil) {
            self.id = id; self.rel = rel; self.to = to; self.label = label
        }
    }
}
