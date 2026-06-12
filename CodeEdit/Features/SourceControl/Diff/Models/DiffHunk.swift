//
//  DiffHunk.swift
//  CodeEdit
//
//  Created for Dynamite — T0.4 Doc Review Parity
//

import Foundation

struct DiffHunk: Identifiable {
    let id = UUID()
    /// Raw "@@ -a,b +c,d @@ context" header line.
    let header: String
    let oldStart: Int
    let newStart: Int
    var lines: [DiffLine]
}
