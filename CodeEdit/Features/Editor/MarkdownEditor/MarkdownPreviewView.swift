//
//  MarkdownPreviewView.swift
//  CodeEdit
//
//  Live editable WYSIWYG markdown surface for `.md` files. Wraps `MarkdownTextView`
//  (an NSTextView subclass with Obsidian-style concealment) in an NSScrollView via
//  NSViewRepresentable. Edits sync back to the owning `CodeFileDocument` so save,
//  git diff, and agents all see plain markdown source.
//

import SwiftUI
import AppKit

struct MarkdownPreviewView: NSViewRepresentable {
    @ObservedObject var codeFile: CodeFileDocument
    var theme: MarkdownTheme

    func makeCoordinator() -> Coordinator { Coordinator(codeFile: codeFile) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        scroll.contentView.autoresizesSubviews = true

        let initialText = codeFile.content?.string ?? ""
        let clipWidth = max(scroll.contentView.bounds.width, 400)
        let textView = MarkdownTextView(theme: theme, initialText: initialText, width: clipWidth)

        textView.onEdit = { [weak coordinator = context.coordinator] _, _, _ in
            coordinator?.handleEdit(textView: textView)
        }

        context.coordinator.textView = textView
        context.coordinator.appliedTheme = theme
        scroll.documentView = textView

        // Track clip-view width so the text view fills the scroll area and re-wraps correctly.
        context.coordinator.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scroll.contentView,
            queue: .main
        ) { [weak textView] _ in
            guard let textView, let clipView = textView.enclosingScrollView?.contentView else { return }
            let newWidth = clipView.bounds.width
            if abs(textView.frame.width - newWidth) > 1 {
                textView.frame.size.width = newWidth
                textView.textContainer?.size = NSSize(
                    width: newWidth,
                    height: CGFloat.greatestFiniteMagnitude
                )
            }
        }
        scroll.contentView.postsFrameChangedNotifications = true

        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? MarkdownTextView else { return }

        // Propagate theme changes.
        if context.coordinator.appliedTheme != theme {
            context.coordinator.appliedTheme = theme
            textView.updateTheme(theme)
        }

        // Reflect external content changes (e.g. git checkout, agent edit, save-triggered reload)
        // without disturbing the user's cursor while they are actively typing.
        if !context.coordinator.isSyncing {
            let documentText = codeFile.content?.string ?? ""
            if documentText != textView.string {
                textView.replaceContents(documentText)
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator {
        weak var codeFile: CodeFileDocument?
        weak var textView: MarkdownTextView?
        var appliedTheme: MarkdownTheme?
        var frameObserver: NSObjectProtocol?
        /// True while we are pushing an edit from the text view into the document, so
        /// `updateNSView` doesn't treat our own write as an external change.
        var isSyncing = false

        init(codeFile: CodeFileDocument) { self.codeFile = codeFile }

        deinit {
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
            }
        }

        func handleEdit(textView: MarkdownTextView) {
            guard let codeFile else { return }
            guard let docStorage = codeFile.content else { return }

            isSyncing = true
            // Mirror the full string into the document storage. The document's
            // NSTextStorage is the single source of truth for save / git / agents.
            let newText = textView.string
            if docStorage.string != newText {
                docStorage.replaceCharacters(
                    in: NSRange(location: 0, length: docStorage.length),
                    with: newText
                )
            }
            codeFile.updateChangeCount(.changeDone)
            isSyncing = false
        }
    }
}
