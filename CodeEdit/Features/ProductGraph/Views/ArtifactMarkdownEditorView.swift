//
//  ArtifactMarkdownEditorView.swift
//  CodeEdit
//

import AppKit
import SwiftUI

/// Product Studio markdown editor backed by the shared MarkdownEngine adapter.
struct ArtifactMarkdownEditorView: View {
    @Binding var text: String
    var theme: MarkdownTheme
    var documentId: String

    var body: some View {
        MarkdownEngineEditorView(
            text: $text,
            theme: theme,
            font: theme.baseFont,
            documentId: documentId
        )
    }
}
