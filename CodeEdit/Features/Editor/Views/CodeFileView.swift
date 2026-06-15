// swiftlint:disable attributes line_length
//
//  CodeFileView.swift
//  CodeEditModules/CodeFile
//
//  Created by Marco Carnevali on 17/03/22.
//

import Foundation
import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import Combine

/// CodeFileView is just a wrapper of the `CodeEditor` dependency
struct CodeFileView: View {
    @ObservedObject private var editorInstance: EditorInstance
    @ObservedObject private var codeFile: CodeFileDocument

    @State private var treeSitterClient: TreeSitterClient = TreeSitterClient()

    /// Any coordinators passed to the view.
    private var textViewCoordinators: [TextViewCoordinator]
    private var highlightProviders: [any HighlightProviding] = []

    @AppSettings(\.textEditing.defaultTabWidth)
    var defaultTabWidth
    @AppSettings(\.textEditing.indentOption)
    var indentOption
    @AppSettings(\.textEditing.lineHeightMultiple)
    var lineHeightMultiple
    @AppSettings(\.textEditing.wrapLinesToEditorWidth)
    var wrapLinesToEditorWidth
    @AppSettings(\.textEditing.overscroll)
    var overscroll
    @AppSettings(\.textEditing.font)
    var settingsFont
    @AppSettings(\.textEditing.markdownPreviewFont)
    var markdownPreviewFont
    @AppSettings(\.textEditing.markdownPreviewMode)
    var markdownPreviewMode
    @AppSettings(\.theme.useThemeBackground)
    var useThemeBackground
    @AppSettings(\.theme.matchAppearance)
    var matchAppearance
    @AppSettings(\.textEditing.letterSpacing)
    var letterSpacing
    @AppSettings(\.textEditing.bracketEmphasis)
    var bracketEmphasis
    @AppSettings(\.textEditing.useSystemCursor)
    var useSystemCursor
    @AppSettings(\.textEditing.showGutter)
    var showGutter
    @AppSettings(\.textEditing.showMinimap)
    var showMinimap
    @AppSettings(\.textEditing.showFoldingRibbon)
    var showFoldingRibbon
    @AppSettings(\.textEditing.reformatAtColumn)
    var reformatAtColumn
    @AppSettings(\.textEditing.showReformattingGuide)
    var showReformattingGuide
    @AppSettings(\.textEditing.invisibleCharacters)
    var invisibleCharactersConfiguration
    @AppSettings(\.textEditing.warningCharacters)
    var warningCharacters

    @EnvironmentObject var undoRegistration: UndoManagerRegistration

    @ObservedObject private var themeModel: ThemeModel = .shared

    private var cancellables = Set<AnyCancellable>()

    private let isEditable: Bool
    private let showMinimapOverride: Bool?

    init(
        editorInstance: EditorInstance,
        codeFile: CodeFileDocument,
        textViewCoordinators: [TextViewCoordinator] = [],
        isEditable: Bool = true,
        showMinimapOverride: Bool? = nil
    ) {
        self._editorInstance = .init(wrappedValue: editorInstance)
        self._codeFile = .init(wrappedValue: codeFile)

        self.textViewCoordinators = textViewCoordinators
            + [editorInstance.rangeTranslator]
            + [codeFile.contentCoordinator]
            + [codeFile.languageServerObjects.textCoordinator]
        self.isEditable = isEditable
        self.showMinimapOverride = showMinimapOverride

        if let openOptions = codeFile.openOptions {
            codeFile.openOptions = nil
            editorInstance.cursorPositions = openOptions.cursorPositions
        }

        highlightProviders = [codeFile.languageServerObjects.highlightProvider] + [treeSitterClient]

        codeFile
            .contentCoordinator
            .textUpdatePublisher
            .sink { [weak codeFile] _ in
                codeFile?.updateChangeCount(.changeDone)
            }
            .store(in: &cancellables)
    }

    private var currentTheme: Theme {
        themeModel.selectedTheme ?? themeModel.themes.first!
    }

    @State private var font: NSFont = Settings[\.textEditing].font.current
    @State private var markdownFont: NSFont = Settings[\.textEditing].markdownPreviewFont.current

    @Environment(\.edgeInsets)
    private var edgeInsets

    private var markdownTheme: MarkdownTheme {
        MarkdownTheme.from(editor: currentTheme.editor, baseFont: markdownFont)
    }

    private var effectiveMarkdownPreviewMode: MarkdownPreviewMode {
        codeFile.markdownPreviewMode ?? markdownPreviewMode
    }

    private var markdownDocumentId: String {
        codeFile.fileURL?.absoluteString ?? String(ObjectIdentifier(codeFile).hashValue)
    }

    private var markdownDocumentText: Binding<String> {
        Binding {
            codeFile.content?.string ?? ""
        } set: { newText in
            replaceDocumentText(newText)
        }
    }

    @ViewBuilder
    var body: some View {
        Group {
            if codeFile.isMarkdown {
                markdownEditor
            } else {
                sourceEditor
            }
        }
        // This view needs to refresh when the codefile changes. The file URL is too stable.
        .id(ObjectIdentifier(codeFile))
        .background(useThemeBackground ? Color(hex: currentTheme.editor.background.color) : Color(NSColor.textBackgroundColor))
        .colorScheme(currentTheme.appearance == .dark ? .dark : .light)
        // minHeight zero fixes a bug where the app would freeze if the contents of the file are empty.
        .frame(minHeight: .zero, maxHeight: .infinity)
        .onChange(of: settingsFont) { _, newFontSetting in
            font = newFontSetting.current
        }
        .onChange(of: markdownPreviewFont) { _, newFontSetting in
            markdownFont = newFontSetting.current
        }
    }

    @ViewBuilder
    private var markdownEditor: some View {
        switch effectiveMarkdownPreviewMode {
        case .source:
            sourceEditor
        case .preview:
            MarkdownEngineEditorView(
                text: markdownDocumentText,
                theme: markdownTheme,
                font: markdownFont,
                documentId: markdownDocumentId,
                contentInsets: edgeInsets,
                overscrollPercent: overscroll.overscrollPercentage,
                isEditable: isEditable
            )
        }
    }

    private func replaceDocumentText(_ newText: String) {
        guard let storage = codeFile.content else {
            codeFile.content = NSTextStorage(string: newText)
            codeFile.updateChangeCount(.changeDone)
            return
        }
        guard storage.string != newText else { return }
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: newText)
        codeFile.updateChangeCount(.changeDone)
    }

    private var sourceEditor: some View {
        let effectiveWrapLines = codeFile.wrapLines ?? wrapLinesToEditorWidth
        let effectiveShowMinimap = showMinimapOverride ?? showMinimap

        return SourceEditor(
            codeFile.content ?? NSTextStorage(),
            language: codeFile.getLanguage(),
            configuration: SourceEditorConfiguration(
                appearance: .init(
                    theme: currentTheme.editor.editorTheme,
                    useThemeBackground: useThemeBackground,
                    font: font,
                    lineHeightMultiple: lineHeightMultiple,
                    letterSpacing: letterSpacing,
                    wrapLines: effectiveWrapLines,
                    useSystemCursor: useSystemCursor,
                    tabWidth: defaultTabWidth,
                    bracketPairEmphasis: getBracketPairEmphasis()
                ),
                behavior: .init(
                    isEditable: isEditable,
                    indentOption: indentOption.textViewOption(),
                    reformatAtColumn: reformatAtColumn
                ),
                layout: .init(
                    editorOverscroll: overscroll.overscrollPercentage,
                    contentInsets: edgeInsets.nsEdgeInsets,
                    additionalTextInsets: NSEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
                ),
                peripherals: .init(
                    showGutter: showGutter,
                    showMinimap: effectiveShowMinimap,
                    showReformattingGuide: showReformattingGuide,
                    showFoldingRibbon: showFoldingRibbon,
                    invisibleCharactersConfiguration: invisibleCharactersConfiguration.textViewOption(),
                    warningCharacters: Set(warningCharacters.characters.keys)
                )
            ),
            state: Binding(
                get: {
                    SourceEditorState(
                        cursorPositions: editorInstance.cursorPositions,
                        scrollPosition: editorInstance.scrollPosition,
                        findText: editorInstance.findText,
                        replaceText: editorInstance.replaceText
                    )
                },
                set: { newState in
                    editorInstance.cursorPositions = newState.cursorPositions ?? []
                    editorInstance.scrollPosition = newState.scrollPosition
                    editorInstance.findText = newState.findText
                    editorInstance.findTextSubject.send(newState.findText)
                    editorInstance.replaceText = newState.replaceText
                    editorInstance.replaceTextSubject.send(newState.replaceText)
                }
            ),
            highlightProviders: highlightProviders,
            undoManager: undoRegistration.manager(forFile: editorInstance.file),
            coordinators: textViewCoordinators
        )
    }

    /// Determines the style of bracket emphasis based on the `bracketEmphasis` setting and the current theme.
    /// - Returns: The emphasis style to use for bracket pair emphasis.
    private func getBracketPairEmphasis() -> BracketPairEmphasis? {
        let color = if Settings[\.textEditing].bracketEmphasis.useCustomColor {
            Settings[\.textEditing].bracketEmphasis.color.nsColor
        } else {
            currentTheme.editor.text.nsColor.withAlphaComponent(0.8)
        }

        switch Settings[\.textEditing].bracketEmphasis.highlightType {
        case .disabled:
            return nil
        case .flash:
            return .flash
        case .bordered:
            return .bordered(color: color)
        case .underline:
            return .underline(color: color)
        }
    }
}

// This extension is kept here because it should not be used elsewhere in the app and may cause confusion
// due to the similar type name from the CETV module.
private extension SettingsData.TextEditingSettings.IndentOption {
    func textViewOption() -> IndentOption {
        switch self.indentType {
        case .spaces:
            return IndentOption.spaces(count: spaceCount)
        case .tab:
            return IndentOption.tab
        }
    }
}

private extension SettingsData.TextEditingSettings.InvisibleCharactersConfig {
    func textViewOption() -> InvisibleCharactersConfiguration {
        guard self.enabled else { return .empty }
        var config = InvisibleCharactersConfiguration(
            showSpaces: self.showSpaces,
            showTabs: self.showTabs,
            showLineEndings: self.showLineEndings
        )

        config.spaceReplacement = self.spaceReplacement
        config.tabReplacement = self.tabReplacement
        config.carriageReturnReplacement = self.carriageReturnReplacement
        config.lineFeedReplacement = self.lineFeedReplacement
        config.paragraphSeparatorReplacement = self.paragraphSeparatorReplacement
        config.lineSeparatorReplacement = self.lineSeparatorReplacement

        return config
    }
}
