// swiftlint:disable function_body_length line_length pattern_matching_keywords
//
//  RenderedMarkdownView.swift
//  CodeEdit
//

import SwiftUI
import AppKit

struct RenderedMarkdownView: View {
    let document: RenderedMarkdownDocument
    let theme: MarkdownTheme

    init(markdown: String, theme: MarkdownTheme) {
        self.document = RenderedMarkdownParser().parse(markdown)
        self.theme = theme
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(document.blocks.indices, id: \.self) { index in
                    blockView(document.blocks[index])
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textSelection(.enabled)
    }

    private func blockView(_ block: RenderedMarkdownBlock) -> AnyView {
        switch block {
        case .heading(let level, let inlines):
            AnyView(inlineText(inlines)
                .font(Font(theme.headingFont(level: level)))
                .foregroundStyle(Color(nsColor: theme.textColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level <= 2 ? 8 : 4)
                .padding(.bottom, level <= 2 ? 2 : 0))

        case .paragraph(let inlines):
            if case .image(let alt, let source) = inlines.only {
                AnyView(RenderedMarkdownImageView(alt: alt, source: source, theme: theme))
            } else {
                AnyView(inlineText(inlines)
                    .font(Font(theme.baseFont))
                    .lineSpacing(3)
                    .foregroundStyle(Color(nsColor: theme.textColor))
                    .frame(maxWidth: .infinity, alignment: .leading))
            }

        case .blockquote(let blocks):
            AnyView(VStack(alignment: .leading, spacing: 8) {
                ForEach(blocks.indices, id: \.self) { index in
                    blockView(blocks[index])
                }
            }
            .padding(.leading, 14)
            .padding(.vertical, 8)
            .padding(.trailing, 10)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color(nsColor: theme.accentColor).opacity(0.55))
                    .frame(width: 3)
            }
            .background(Color(nsColor: theme.quoteBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6)))

        case .codeBlock(let language, let code):
            AnyView(VStack(alignment: .leading, spacing: 6) {
                if let language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: theme.secondaryColor))
                }
                ScrollView(.horizontal) {
                    Text(code.isEmpty ? " " : code)
                        .font(.system(size: theme.baseFont.pointSize, design: .monospaced))
                        .foregroundStyle(Color(nsColor: theme.codeForeground))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: theme.codeBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6)))

        case .horizontalRule:
            AnyView(Rectangle()
                .fill(Color(nsColor: theme.dividerColor))
                .frame(height: 1)
                .padding(.vertical, 8))

        case .unorderedList(let items):
            AnyView(listView(items: items, orderedStart: nil))

        case .orderedList(let start, let items):
            AnyView(listView(items: items, orderedStart: start))

        case .table(let table):
            AnyView(tableView(table))
        }
    }

    private func listView(
        items: [RenderedMarkdownListItem],
        orderedStart: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    markerView(item: item, index: index, orderedStart: orderedStart)
                        .frame(width: orderedStart == nil ? 18 : 30, alignment: .trailing)

                    inlineText(item.inlines)
                        .font(Font(theme.baseFont))
                        .foregroundStyle(Color(nsColor: item.taskState == .checked ? theme.secondaryColor : theme.textColor))
                        .strikethrough(item.taskState == .checked)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func markerView(
        item: RenderedMarkdownListItem,
        index: Int,
        orderedStart: Int?
    ) -> some View {
        if item.taskState == .checked {
            Image(systemName: "checkmark.square.fill")
                .foregroundStyle(Color(nsColor: theme.accentColor))
        } else if item.taskState == .unchecked {
            Image(systemName: "square")
                .foregroundStyle(Color(nsColor: theme.secondaryColor))
        } else if let orderedStart {
            Text("\(orderedStart + index).")
                .font(Font(theme.baseFont))
                .foregroundStyle(Color(nsColor: theme.secondaryColor))
        } else {
            Text("•")
                .font(Font(theme.baseFont))
                .foregroundStyle(Color(nsColor: theme.secondaryColor))
        }
    }

    private func tableView(_ table: RenderedMarkdownTable) -> some View {
        VStack(spacing: 0) {
            tableRow(table.header, alignments: table.alignments, isHeader: true)

            ForEach(table.rows.indices, id: \.self) { index in
                tableRow(table.rows[index], alignments: table.alignments, isHeader: false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: theme.tableBorderColor), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tableRow(
        _ row: RenderedMarkdownTableRow,
        alignments: [RenderedMarkdownColumnAlignment],
        isHeader: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(row.cells.indices, id: \.self) { index in
                tableCell(
                    row.cells[index],
                    alignment: alignments[safe: index] ?? .leading,
                    isHeader: isHeader,
                    isLast: index == row.cells.count - 1
                )
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: theme.tableBorderColor))
                .frame(height: 1)
        }
    }

    private func tableCell(
        _ cell: [RenderedMarkdownInline],
        alignment: RenderedMarkdownColumnAlignment,
        isHeader: Bool,
        isLast: Bool
    ) -> some View {
        inlineText(cell)
            .font(isHeader ? Font(theme.bold(of: theme.baseFont)) : Font(theme.baseFont))
            .foregroundStyle(Color(nsColor: theme.textColor))
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: swiftUIAlignment(alignment))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isHeader ? Color(nsColor: theme.tableHeaderBackground) : Color.clear)
            .overlay(alignment: .trailing) {
                if !isLast {
                    Rectangle()
                        .fill(Color(nsColor: theme.tableBorderColor))
                        .frame(width: 1)
                }
            }
    }

    private func inlineText(_ inlines: [RenderedMarkdownInline]) -> Text {
        inlines.reduce(Text("")) { partial, inline in
            partial + text(for: inline)
        }
    }

    private func text(for inline: RenderedMarkdownInline) -> Text {
        switch inline {
        case .text(let string):
            return Text(string)
        case .emphasis(let children):
            return inlineText(children).italic()
        case .strong(let children):
            return inlineText(children).bold()
        case .strongEmphasis(let children):
            return inlineText(children).bold().italic()
        case .strikethrough(let children):
            return inlineText(children).strikethrough()
        case .code(let string):
            return Text(string)
                .font(.system(size: theme.baseFont.pointSize, design: .monospaced))
                .foregroundStyle(Color(nsColor: theme.codeForeground))
        case .link(let label, _):
            return inlineText(label)
                .foregroundStyle(Color(nsColor: theme.accentColor))
                .underline()
        case .image(let alt, _):
            return Text(alt.isEmpty ? "Image" : alt)
                .italic()
                .foregroundStyle(Color(nsColor: theme.secondaryColor))
        }
    }

    private func swiftUIAlignment(_ alignment: RenderedMarkdownColumnAlignment) -> Alignment {
        switch alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

private struct RenderedMarkdownImageView: View {
    let alt: String
    let source: String
    let theme: MarkdownTheme

    var body: some View {
        Group {
            if let url = URL(string: source), ["http", "https"].contains(url.scheme?.lowercased()) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        imageView(image)
                    case .failure:
                        fallback
                    case .empty:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else if let image = NSImage(contentsOfFile: NSString(string: source).expandingTildeInPath) {
                imageView(Image(nsImage: image))
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func imageView(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var fallback: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo")
            Text(alt.isEmpty ? source : alt)
        }
        .font(Font(theme.baseFont))
        .foregroundStyle(Color(nsColor: theme.secondaryColor))
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }

    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
