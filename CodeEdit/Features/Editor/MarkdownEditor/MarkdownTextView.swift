//
//  MarkdownTextView.swift
//  CodeEdit
//
//  An editable NSTextView (TextKit 1) that renders markdown live: the styler applies
//  "rendered" attributes and flags syntax markers, and the conceal delegate hides those
//  markers unless the cursor is on their line. Character edits are reported back so the
//  owning document stays in sync.
//

import AppKit

final class MarkdownTextView: NSTextView {
    private let styler: MarkdownSyntaxStyler
    private let concealDelegate = MarkdownConcealLayoutDelegate()

    /// Called when the user edits text. Provides the edited range (in the new string), the
    /// length delta, and the replacement substring so the owner can mirror the change.
    var onEdit: ((_ editedRange: NSRange, _ delta: Int, _ replacement: String) -> Void)?

    private var lastRevealedParagraph: NSRange?
    /// True while the styler is mutating attributes, so we don't treat that as a user edit
    /// or re-enter styling.
    private var isStyling = false

    /// Location of a pending "/" slash-menu trigger, or `NSNotFound`.
    var slashTriggerLocation: Int = NSNotFound

    init(theme: MarkdownTheme, initialText: String, width: CGFloat) {
        self.styler = MarkdownSyntaxStyler(theme: theme)

        // Build an explicit TextKit 1 stack so glyph concealment is available and deterministic.
        let storage = NSTextStorage(string: initialText)
        let layoutManager = NSLayoutManager()
        layoutManager.delegate = concealDelegate
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

    private func currentParagraphRange() -> NSRange {
        guard let nsString = textStorage?.string as NSString? else {
            return NSRange(location: 0, length: 0)
        }
        let selected = selectedRange()
        let safe = NSRange(location: min(selected.location, nsString.length), length: 0)
        return nsString.paragraphRange(for: safe)
    }

    /// Re-applies markdown styling to the whole document and recomputes concealment.
    private func applyStyling() {
        guard let storage = textStorage else { return }
        isStyling = true
        let revealed = currentParagraphRange()
        styler.applyStyles(to: storage, revealedParagraph: revealed)
        lastRevealedParagraph = revealed
        isStyling = false
        // Re-run the conceal delegate so marker visibility is current. Glyph invalidation is
        // lazy — only the visible region re-lays-out — so this stays cheap even on large files.
        layoutManager?.invalidateGlyphs(forCharacterRange: fullRange, changeInLength: 0, actualCharacterRange: nil)
        needsDisplay = true
    }

    override func didChangeText() {
        super.didChangeText()
        applyStyling()
        // Open the slash menu after the edit settles (it pops a modal menu).
        DispatchQueue.main.async { [weak self] in
            self?.handleSlashTrigger()
        }
    }

    override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting: Bool
    ) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        guard !isStyling, !stillSelecting else { return }
        let para = currentParagraphRange()
        if lastRevealedParagraph == nil || !NSEqualRanges(para, lastRevealedParagraph!) {
            applyStyling()
        }
    }
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
