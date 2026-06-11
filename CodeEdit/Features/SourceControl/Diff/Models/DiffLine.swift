//
//  DiffLine.swift
//  CodeEdit
//
//  Created for Dynamite — T0.4 Doc Review Parity
//

import Foundation

struct DiffLine: Identifiable {
    enum Kind {
        case context
        case added
        case removed
    }

    let id = UUID()
    let kind: Kind
    /// Line content without the leading +/- /space sigil.
    let content: String
    /// 1-based line number in the old file; nil for added lines.
    let oldNumber: Int?
    /// 1-based line number in the new file; nil for removed lines.
    let newNumber: Int?
}
