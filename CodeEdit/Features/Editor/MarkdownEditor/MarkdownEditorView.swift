//
//  MarkdownEditorView.swift
//  CodeEdit
//
//  SwiftUI bridge that hosts the live markdown (WYSIWYG) editor for `.md` files. Edits are
//  mirrored back into the shared ``CodeFileDocument`` text storage so the raw editor and
//  autosave stay in sync, and external changes are reflected back into the rendered view.
//

import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @ObservedObject var codeFile: CodeFileDocument
    var theme: MarkdownTheme

    func makeCoordinator() -> Coordinator {
        Coordinator(codeFile: codeFile)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let initialText = codeFile.content?.string ?? ""
        let textView = MarkdownTextView(theme: theme, initialText: initialText, width: 600)
        textView.onEdit = { [weak coordinator = context.coordinator] editedRange, delta, replacement in
            coordinator?.mirrorEdit(editedRange: editedRange, delta: delta, replacement: replacement)
        }
        context.coordinator.textView = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }

        if context.coordinator.appliedTheme != theme {
            context.coordinator.appliedTheme = theme
            textView.updateTheme(theme)
        }

        // Reflect external content changes (file reverted, edited elsewhere) into the rendered
        // view — but never while we're the ones writing the change.
        if !context.coordinator.isSyncing,
           let content = codeFile.content?.string,
           content != textView.string {
            textView.replaceContents(content)
        }
    }

    @MainActor
    final class Coordinator {
        let codeFile: CodeFileDocument
        weak var textView: MarkdownTextView?
        var appliedTheme: MarkdownTheme?
        /// True while we are mirroring an edit into the document, so ``updateNSView`` won't
        /// treat the resulting document change as "external" and revert the buffer.
        var isSyncing = false

        init(codeFile: CodeFileDocument) {
            self.codeFile = codeFile
        }

        func mirrorEdit(editedRange: NSRange, delta: Int, replacement: String) {
            guard let content = codeFile.content else { return }
            let oldLength = editedRange.length - delta
            let oldRange = NSRange(location: editedRange.location, length: max(0, oldLength))
            guard oldRange.location >= 0,
                  oldRange.location + oldRange.length <= content.length else {
                return
            }
            isSyncing = true
            content.replaceCharacters(in: oldRange, with: replacement)
            codeFile.updateChangeCount(.changeDone)
            isSyncing = false
        }
    }
}
