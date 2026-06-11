//
//  MarkdownConcealLayoutDelegate.swift
//  CodeEdit
//
//  Hides markdown syntax markers in the live editor by giving their glyphs the `.null`
//  layout property — they take zero width and are not drawn, while the underlying
//  characters remain in the text storage (so editing, selection, and undo are unaffected).
//
//  This is the standard, reliable TextKit 1 technique for concealing text: we intercept
//  glyph generation and mark concealed character ranges as null control glyphs.
//

import AppKit

final class MarkdownConcealLayoutDelegate: NSObject, NSLayoutManagerDelegate {
    /// When false, nothing is concealed (the styler can still flag ranges, but we ignore them).
    var concealmentEnabled: Bool = true

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard concealmentEnabled, let textStorage = layoutManager.textStorage else {
            // Returning 0 tells TextKit we didn't modify anything and to use the defaults.
            return 0
        }

        let length = textStorage.length
        var modifiedProps = [NSLayoutManager.GlyphProperty](repeating: .init(rawValue: 0), count: glyphRange.length)
        var didModify = false

        for index in 0..<glyphRange.length {
            var property = props[index]
            let charIndex = charIndexes[index]
            if charIndex < length,
               textStorage.attribute(.markdownConceal, at: charIndex, effectiveRange: nil) != nil {
                property = .null
                didModify = true
            }
            modifiedProps[index] = property
        }

        guard didModify else { return 0 }

        layoutManager.setGlyphs(
            glyphs,
            properties: &modifiedProps,
            characterIndexes: charIndexes,
            font: font,
            forGlyphRange: glyphRange
        )
        return glyphRange.length
    }
}
