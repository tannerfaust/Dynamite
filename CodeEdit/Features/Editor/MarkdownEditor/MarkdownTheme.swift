//
//  MarkdownTheme.swift
//  CodeEdit
//
//  Visual styling values for the live markdown (WYSIWYG) editor. Derived from the
//  active editor theme + base font so the rendered markdown matches the rest of the app.
//

import AppKit

/// Colors and fonts used to render markdown in the live editor.
struct MarkdownTheme: Equatable {
    var baseFont: NSFont
    var textColor: NSColor
    /// Dimmed color for markers that remain visible (list bullets, quote bars).
    var secondaryColor: NSColor
    /// Accent used for links and heading marks.
    var accentColor: NSColor
    var codeForeground: NSColor
    var codeBackground: NSColor
    var quoteColor: NSColor
    var quoteBackground: NSColor
    var dividerColor: NSColor
    var tableHeaderBackground: NSColor
    var tableBorderColor: NSColor
    var highlightBackground: NSColor
    var syntaxColor: NSColor

    var codeFont: NSFont {
        let size = baseFont.pointSize
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    var lineHeightMultiple: CGFloat {
        1.35
    }

    var paragraphSpacing: CGFloat {
        max(4, baseFont.pointSize * 0.35)
    }

    var baseParagraphStyle: NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = lineHeightMultiple
        paragraph.paragraphSpacing = paragraphSpacing
        return paragraph
    }

    /// Font for an ATX heading of the given level (1...6).
    func headingFont(level: Int) -> NSFont {
        let scale: CGFloat
        switch level {
        case 1: scale = 1.9
        case 2: scale = 1.55
        case 3: scale = 1.3
        case 4: scale = 1.15
        case 5: scale = 1.05
        default: scale = 1.0
        }
        let size = (baseFont.pointSize * scale).rounded()
        let bold = NSFont.boldSystemFont(ofSize: size)
        return bold
    }

    func bold(of font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
    }

    func italic(of font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }

    /// Builds a theme from the app's current editor colors and the editor's base font.
    static func from(editor: Theme.EditorColors, baseFont: NSFont) -> MarkdownTheme {
        let text = editor.text.nsColor
        return MarkdownTheme(
            baseFont: baseFont,
            textColor: text,
            secondaryColor: text.withAlphaComponent(0.45),
            accentColor: editor.keywords.nsColor,
            codeForeground: editor.strings.nsColor,
            codeBackground: text.withAlphaComponent(0.08),
            quoteColor: text.withAlphaComponent(0.6),
            quoteBackground: text.withAlphaComponent(0.045),
            dividerColor: text.withAlphaComponent(0.25),
            tableHeaderBackground: text.withAlphaComponent(0.06),
            tableBorderColor: text.withAlphaComponent(0.18),
            highlightBackground: NSColor.systemYellow.withAlphaComponent(0.32),
            syntaxColor: text.withAlphaComponent(0.28)
        )
    }
}
