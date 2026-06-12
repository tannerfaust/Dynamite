//
//  ArtifactMarkdownEditorView.swift
//  CodeEdit
//

import SwiftUI
import AppKit

/// SwiftUI bridge for `MarkdownTextView` using a `@Binding<String>` for the body text.
///
/// Unlike `MarkdownPreviewView` (which requires `CodeFileDocument`), this view is
/// self-contained — appropriate for the Cockpit artifact editor where no IDE panes exist.
/// Uses the same live WYSIWYG `MarkdownTextView` component under the hood.
struct ArtifactMarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    var theme: MarkdownTheme

    func makeCoordinator() -> Coordinator { Coordinator(binding: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true

        let textView = MarkdownTextView(theme: theme, initialText: text, width: 700)
        textView.onEdit = { [weak coord = context.coordinator] _, _, _ in
            coord?.handleEdit(textView: textView)
        }
        context.coordinator.textView = textView
        context.coordinator.appliedTheme = theme
        scroll.documentView = textView

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

        if context.coordinator.appliedTheme != theme {
            context.coordinator.appliedTheme = theme
            textView.updateTheme(theme)
        }

        // Reflect external content changes (e.g. save-triggered reload) without disturbing
        // the user's cursor position while they're actively typing.
        if !context.coordinator.isSyncing, text != textView.string {
            textView.replaceContents(text)
        }
    }

    // MARK: - Coordinator

    final class Coordinator {
        var binding: Binding<String>
        weak var textView: MarkdownTextView?
        var appliedTheme: MarkdownTheme?
        var frameObserver: NSObjectProtocol?
        var isSyncing = false

        init(binding: Binding<String>) { self.binding = binding }

        deinit {
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
            }
        }

        func handleEdit(textView: MarkdownTextView) {
            isSyncing = true
            binding.wrappedValue = textView.string
            isSyncing = false
        }
    }
}
