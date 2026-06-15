//
//  MarkdownEngineEditorView.swift
//  CodeEdit
//
//  Adapter for nodes-app/swift-markdown-engine. The package owns the TextKit 2
//  markdown editing surface; Dynamite only binds text, theme, and editor chrome
//  insets into the engine configuration.
//

import AppKit
import MarkdownEngine
import SwiftUI

struct MarkdownEngineEditorView: View {
    @Binding var text: String

    var theme: MarkdownTheme
    var font: NSFont
    var documentId: String
    var contentInsets: EdgeInsets = .init()
    var overscrollPercent: CGFloat = 0.5
    var isEditable = true

    var body: some View {
        NativeTextViewWrapper(
            text: editorText,
            configuration: configuration,
            fontName: engineFontName,
            fontSize: font.pointSize,
            documentId: documentId,
            isEditable: isEditable
        )
        .background(MarkdownEngineAppKitBridge(
            slashMenuEnabled: isEditable
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editorText: Binding<String> {
        Binding {
            text
        } set: { newText in
            guard text != newText else { return }
            text = newText
        }
    }

    private var engineFontName: String {
        font.fontName.hasPrefix(".AppleSystem") ? "SF Pro" : font.fontName
    }

    private var configuration: MarkdownEditorConfiguration {
        var configuration = MarkdownEditorConfiguration.default
        configuration.theme = MarkdownEditorTheme(
            bodyText: theme.textColor,
            mutedText: theme.secondaryColor,
            disabledText: theme.secondaryColor.withAlphaComponent(0.75),
            headingMarker: theme.accentColor,
            link: theme.accentColor,
            incompleteLink: theme.secondaryColor,
            findMatchHighlight: theme.highlightBackground,
            findCurrentMatchHighlight: theme.highlightBackground,
            latexLightModeText: theme.textColor,
            latexDarkModeText: theme.textColor,
            strikethroughColor: theme.dividerColor
        )
        configuration.services = MarkdownEditorServices(
            syntaxHighlighter: DynamiteSyntaxHighlighter(codeBackground: theme.codeBackground)
        )
        configuration.safeAreaInsets = SafeAreaInsets(
            top: contentInsets.top,
            leading: contentInsets.leading,
            trailing: contentInsets.trailing,
            bottom: contentInsets.bottom
        )
        configuration.overscroll = OverscrollPolicy(percent: overscrollPercent)
        configuration.textInsets = TextInsets(horizontal: 18, vertical: 16)
        configuration.codeBlock = CodeBlockStyle(fontSizeScale: 1.0)
        configuration.inlineCode = InlineCodeStyle(fontSizeScale: 1.0)
        configuration.headings = HeadingStyle(
            fontMultipliers: [1.9, 1.55, 1.3, 1.15, 1.05, 1.0]
        )
        configuration.paragraph = ParagraphStyle(
            spacingFactor: 0.35,
            lineHeightExtraSpacing: max(1, font.pointSize * 0.15)
        )
        return configuration
    }
}

private struct DynamiteSyntaxHighlighter: SyntaxHighlighter, @unchecked Sendable {
    let codeBackground: NSColor

    func codeFont(size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func backgroundColor() -> NSColor {
        codeBackground
    }

    func highlight(code: String, language: String?) -> NSAttributedString? {
        nil
    }

    var appearanceDidChangeNotification: Notification.Name? {
        nil
    }
}
