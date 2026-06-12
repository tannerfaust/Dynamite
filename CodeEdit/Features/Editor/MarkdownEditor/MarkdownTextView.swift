//
//  MarkdownTextView.swift
//  CodeEdit
//
//  An editable NSTextView (TextKit 1) that applies markdown-aware styling while keeping the
//  raw source text editable. Character edits are reported back so the owning document stays
//  in sync.
//

import AppKit

final class MarkdownTextView: NSTextView {
    private let styler: MarkdownSyntaxStyler

    /// Called when the user edits text. Provides the edited range (in the new string), the
    /// length delta, and the replacement substring so the owner can mirror the change.
    var onEdit: ((_ editedRange: NSRange, _ delta: Int, _ replacement: String) -> Void)?

    /// True while the styler is mutating attributes, so we don't treat that as a user edit
    /// or re-enter styling.
    private var isStyling = false

    /// Location of a pending "/" slash-menu trigger, or `NSNotFound`.
    var slashTriggerLocation: Int = NSNotFound

    init(theme: MarkdownTheme, initialText: String, width: CGFloat) {
        self.styler = MarkdownSyntaxStyler(theme: theme)

        // Build an explicit TextKit 1 stack so styling and layout stay deterministic.
        let storage = NSTextStorage(string: initialText)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0), textContainer: container)

        isEditable = true
        isSelectable = true
        isRichText = false
        allowsUndo = true
        usesFindBar = true
        drawsBackground = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isIncrementalSearchingEnabled = true
        font = theme.baseFont
        textColor = theme.textColor
        insertionPointColor = theme.textColor

        isVerticallyResizable = true
        isHorizontallyResizable = false
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        minSize = NSSize(width: 0, height: 0)
        autoresizingMask = [.width]
        textContainerInset = NSSize(width: 18, height: 16)

        storage.delegate = self
        applyStyling()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Replace the entire contents (e.g. when the underlying file changed externally), keeping
    /// the caret position stable where possible.
    func replaceContents(_ string: String) {
        guard let storage = textStorage, storage.string != string else { return }
        let selected = selectedRange()
        isStyling = true
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: string)
        isStyling = false
        let clamped = NSRange(location: min(selected.location, storage.length), length: 0)
        setSelectedRange(clamped)
        applyStyling()
    }

    func updateTheme(_ theme: MarkdownTheme) {
        styler.theme = theme
        font = theme.baseFont
        textColor = theme.textColor
        insertionPointColor = theme.textColor
        applyStyling()
    }

    private var fullRange: NSRange {
        NSRange(location: 0, length: textStorage?.length ?? 0)
    }

    /// Re-applies markdown styling to the whole document.
    /// Used for initial load, theme changes, and external content replacement.
    private func applyStyling() {
        guard let storage = textStorage else { return }
        isStyling = true
        styler.applyStyles(to: storage, revealedParagraph: nil)
        isStyling = false
        invalidateRestyledRange(fullRange)
    }

    /// Incrementally restyles only the given character range (expanded to paragraphs internally).
    private func applyIncrementalStyling(editedRange: NSRange) {
        guard let storage = textStorage else { return }
        isStyling = true
        styler.applyStyles(to: storage, in: editedRange, revealedParagraph: nil)
        isStyling = false
        // Invalidate the edited paragraph range (expanded to paragraph boundaries by the styler).
        let nsString = storage.string as NSString
        guard nsString.length > 0 else { return }
        let location = min(max(editedRange.location, 0), nsString.length - 1)
        let clamped = NSRange(
            location: location,
            length: min(editedRange.length, nsString.length - location)
        )
        let paragraphRange = nsString.paragraphRange(for: clamped)
        invalidateRestyledRange(paragraphRange)
    }

    /// Properly paired glyph + layout invalidation on only the restyled range.
    private func invalidateRestyledRange(_ range: NSRange) {
        guard range.length > 0 else { return }
        layoutManager?.invalidateGlyphs(forCharacterRange: range, changeInLength: 0, actualCharacterRange: nil)
        layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        needsDisplay = true
    }

    override func didChangeText() {
        super.didChangeText()
        // Use incremental restyling on the edited range instead of full-document.
        if let storage = textStorage {
            let editedRange = storage.editedRange
            if editedRange.location != NSNotFound, editedRange.length >= 0 {
                // Check if a fence marker was edited — if so, restyle the whole document
                // because fenced code block context changes affect everything below.
                let nsString = storage.string as NSString
                let paraLocation = min(max(editedRange.location, 0), max(nsString.length - 1, 0))
                let paraRange: NSRange
                if nsString.length > 0 {
                    paraRange = nsString.paragraphRange(for: NSRange(location: paraLocation, length: 0))
                } else {
                    paraRange = NSRange(location: 0, length: 0)
                }
                let paraText = nsString.substring(with: paraRange)
                let local = NSRange(location: 0, length: (paraText as NSString).length)
                let fenceEdited = MarkdownTextView.fenceCheckRegex.firstMatch(in: paraText, range: local) != nil
                if fenceEdited {
                    applyStyling()
                } else {
                    applyIncrementalStyling(editedRange: editedRange)
                }
            } else {
                applyStyling()
            }
        } else {
            applyStyling()
        }
        // Open the slash menu after the edit settles (it pops a modal menu).
        DispatchQueue.main.async { [weak self] in
            self?.handleSlashTrigger()
        }
    }

    // swiftlint:disable:next force_try
    private static let fenceCheckRegex = try! NSRegularExpression(pattern: "^[ \\t]*(```|~~~)", options: [])

}

extension MarkdownTextView: NSTextStorageDelegate {
    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard !isStyling, editedMask.contains(.editedCharacters) else { return }
        let replacement = (textStorage.string as NSString).substring(with: editedRange)
        // Mirror synchronously so the source document never lags our buffer (a lag would let a
        // SwiftUI refresh momentarily revert the edit). Editing a separate storage from within
        // this one's processing pass is safe.
        onEdit?(editedRange, delta, replacement)
    }
}
