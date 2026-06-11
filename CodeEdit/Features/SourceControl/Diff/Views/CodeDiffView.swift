//
//  CodeDiffView.swift
//  CodeEdit
//
//  Created for Dynamite — T0.4 Doc Review Parity
//

import SwiftUI

// MARK: - Top-level router

struct CodeDiffView: View {
    let hunks: [DiffHunk]
    let mode: DiffViewModel.DisplayMode

    var body: some View {
        ForEach(hunks) { hunk in
            CodeDiffHunkView(hunk: hunk, mode: mode)
        }
    }
}

// MARK: - Single hunk

private struct CodeDiffHunkView: View {
    let hunk: DiffHunk
    let mode: DiffViewModel.DisplayMode

    var body: some View {
        VStack(spacing: 0) {
            HunkHeaderRow(header: hunk.header)
            if mode == .inline {
                ForEach(hunk.lines) { line in
                    InlineRow(line: line, showLineNumbers: true)
                }
            } else {
                ForEach(sideBySideRows(hunk.lines), id: \.id) { row in
                    SideBySideRow(row: row)
                }
            }
        }
    }

    // MARK: - Side-by-side line pairing

    private struct PairedRow: Identifiable {
        let id = UUID()
        let left: DiffLine?
        let right: DiffLine?
    }

    private func sideBySideRows(_ lines: [DiffLine]) -> [PairedRow] {
        var rows: [PairedRow] = []
        var removedBuf: [DiffLine] = []
        var addedBuf: [DiffLine] = []

        func flush() {
            let count = max(removedBuf.count, addedBuf.count)
            for idx in 0..<count {
                rows.append(PairedRow(
                    left: idx < removedBuf.count ? removedBuf[idx] : nil,
                    right: idx < addedBuf.count ? addedBuf[idx] : nil
                ))
            }
            removedBuf = []
            addedBuf = []
        }

        for line in lines {
            switch line.kind {
            case .context:
                flush()
                rows.append(PairedRow(left: line, right: line))
            case .removed:
                if !addedBuf.isEmpty { flush() }
                removedBuf.append(line)
            case .added:
                addedBuf.append(line)
            }
        }
        flush()
        return rows
    }

    // MARK: - Side-by-side row view

    private struct SideBySideRow: View {
        let row: PairedRow

        var body: some View {
            HStack(spacing: 0) {
                halfCell(line: row.left, kind: .removed)
                Divider()
                halfCell(line: row.right, kind: .added)
            }
        }

        @ViewBuilder
        private func halfCell(line: DiffLine?, kind: DiffLine.Kind) -> some View {
            let bg: Color = {
                switch line?.kind {
                case .removed: return .red.opacity(0.10)
                case .added: return .green.opacity(0.10)
                default: return Color(nsColor: .textBackgroundColor)
                }
            }()

            HStack(spacing: 0) {
                // Line number
                Text(line.flatMap { lineNumber($0, side: kind) } ?? "")
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
                    .padding(.trailing, 8)
                    .font(.system(size: 11, design: .monospaced))

                // Sigil
                Text(sigil(for: line?.kind))
                    .foregroundStyle(sigilColor(for: line?.kind))
                    .frame(width: 12)

                // Content
                Text(line?.content ?? "")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
            .padding(.vertical, 1)
            .background(bg)
            .frame(maxWidth: .infinity)
        }

        private func lineNumber(_ line: DiffLine, side: DiffLine.Kind) -> String? {
            let num = side == .removed ? line.oldNumber : line.newNumber
            return num.map { String($0) }
        }

        private func sigil(for kind: DiffLine.Kind?) -> String {
            switch kind {
            case .removed: return "-"
            case .added: return "+"
            default: return " "
            }
        }

        private func sigilColor(for kind: DiffLine.Kind?) -> Color {
            switch kind {
            case .removed: return .red.opacity(0.8)
            case .added: return .green.opacity(0.8)
            default: return .secondary
            }
        }
    }
}

// MARK: - Shared sub-views

struct HunkHeaderRow: View {
    let header: String

    var body: some View {
        Text(header)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct InlineRow: View {
    let line: DiffLine
    let showLineNumbers: Bool

    private var background: Color {
        switch line.kind {
        case .added: return .green.opacity(0.10)
        case .removed: return .red.opacity(0.10)
        case .context: return Color(nsColor: .textBackgroundColor)
        }
    }

    private var sigil: String {
        switch line.kind {
        case .added: return "+"
        case .removed: return "-"
        case .context: return " "
        }
    }

    private var sigilColor: Color {
        switch line.kind {
        case .added: return .green.opacity(0.8)
        case .removed: return .red.opacity(0.8)
        case .context: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumbers {
                // Old line number
                Text(line.oldNumber.map(String.init) ?? "")
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
                    .padding(.trailing, 4)

                // New line number
                Text(line.newNumber.map(String.init) ?? "")
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            // Sigil
            Text(sigil)
                .foregroundStyle(sigilColor)
                .frame(width: 12, alignment: .center)

            // Content
            Text(line.content)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        }
        .padding(.vertical, 1)
        .font(.system(size: 12, design: .monospaced))
        .background(background)
    }
}
