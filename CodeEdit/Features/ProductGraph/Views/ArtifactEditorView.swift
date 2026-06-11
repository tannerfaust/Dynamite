//
//  ArtifactEditorView.swift
//  CodeEdit
//

import SwiftUI

private enum ArtifactEditorMode: String, CaseIterable, Identifiable {
    case board
    case source

    var id: String { rawValue }

    var title: String {
        switch self {
        case .board:   return "Board"
        case .source:  return "Source"
        }
    }
}

/// Full artifact editor: `FrontMatterHeaderView` + board or markdown body editor.
///
/// Canvas kinds default to the native board view; other kinds use markdown only.
struct ArtifactEditorView: View {
    @ObservedObject var viewModel: StudioViewModel
    let artifact: ProductArtifact

    @State private var draft: ProductArtifact
    @State private var saveDebounce: Task<Void, Never>?
    @State private var editorMode: ArtifactEditorMode = .board
    @StateObject private var assistViewModel: AIAssistViewModel

    init(viewModel: StudioViewModel, artifact: ProductArtifact) {
        self.viewModel = viewModel
        self.artifact = artifact
        _draft = State(initialValue: artifact)
        let supportsBoard = artifact.kind?.supportsBoardView == true
        _editorMode = State(initialValue: supportsBoard ? .board : .source)
        _assistViewModel = StateObject(wrappedValue: viewModel.makeAssistViewModel())
    }

    private var theme: MarkdownTheme {
        MarkdownTheme(
            baseFont: .systemFont(ofSize: 14),
            textColor: .labelColor,
            secondaryColor: .secondaryLabelColor,
            accentColor: .controlAccentColor,
            codeForeground: .systemBlue,
            codeBackground: .quaternaryLabelColor.withAlphaComponent(0.08),
            quoteColor: .secondaryLabelColor,
            dividerColor: .separatorColor
        )
    }

    private var supportsBoard: Bool {
        draft.kind?.supportsBoardView == true
    }

    var body: some View {
        VStack(spacing: 0) {
            FrontMatterHeaderView(artifact: $draft, onSave: flush)
            AIAssistToolbarView(
                viewModel: assistViewModel,
                artifact: draft,
                currentSelection: { "" }  // TODO: wire real selection from MarkdownTextView
            )
            editorToolbar
            Divider()
            editorContent
        }
        .background(.windowBackground)
        .sheet(isPresented: $assistViewModel.showingResult) {
            AIAssistResultView(
                viewModel: assistViewModel,
                artifact: draft,
                onAccept: { text in
                    draft.body = text
                    scheduleSave()
                },
                onNavigateToNode: { nodeID in
                    viewModel.navigateToNode(nodeID)
                }
            )
        }
    }

    private var editorToolbar: some View {
        HStack {
            if supportsBoard {
                Picker("Editor", selection: $editorMode) {
                    ForEach(ArtifactEditorMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var editorContent: some View {
        if supportsBoard, editorMode == .board {
            ArtifactBoardView(
                artifact: $draft,
                onCommit: flush,
                onNavigateLink: { link in
                    guard !link.to.isEmpty else { return }
                    viewModel.navigateToNode(link.to)
                }
            )
        } else {
            ArtifactMarkdownEditorView(text: $draft.body, theme: theme)
                .onChange(of: draft.body) { _, _ in scheduleSave() }
        }
    }

    // MARK: - Save helpers

    private func flush() {
        saveDebounce?.cancel()
        viewModel.save(draft)
    }

    private func scheduleSave() {
        saveDebounce?.cancel()
        saveDebounce = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { viewModel.save(draft) }
        }
    }
}
