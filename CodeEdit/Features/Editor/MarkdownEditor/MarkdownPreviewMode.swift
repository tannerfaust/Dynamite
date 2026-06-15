//
//  MarkdownPreviewMode.swift
//  CodeEdit
//

import Foundation

enum MarkdownPreviewMode: String, CaseIterable, Hashable, Identifiable {
    case source
    case preview

    var id: Self { self }

    var displayName: String {
        switch self {
        case .source:
            "Source"
        case .preview:
            "Preview"
        }
    }

    var next: MarkdownPreviewMode {
        switch self {
        case .source:
            .preview
        case .preview:
            .source
        }
    }

    var isPreview: Bool {
        self == .preview
    }
}

extension MarkdownPreviewMode: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.source.rawValue:
            self = .source
        case Self.preview.rawValue,
            "swiftMarkdownEngine",
            "dynamiteNative":
            self = .preview
        default:
            self = .source
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
