// swiftlint:disable attributes
//
//  DiffPaneView.swift
//  CodeEdit
//
//  Created for Dynamite — T0.4 Doc Review Parity
//

import SwiftUI

/// Sheet-presented diff pane. Present via `.sheet(item:)` passing a `DiffViewModel.Source`.
struct DiffPaneView: View {
    @StateObject private var viewModel: DiffViewModel
    @Environment(\.dismiss) private var dismiss

    init(source: DiffViewModel.Source, gitClient: GitClient) {
        _viewModel = StateObject(wrappedValue: DiffViewModel(source: source, gitClient: gitClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 700, minHeight: 480)
        .task { await viewModel.load() }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close")

            Image(systemName: viewModel.isMarkdown ? "doc.text" : "doc.plaintext")
                .foregroundStyle(.secondary)

            Text(viewModel.fileName)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            Picker("Display Mode", selection: $viewModel.displayMode) {
                ForEach(DiffViewModel.DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading diff…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let msg = viewModel.errorMessage {
            CEContentUnavailableView("Could Not Load Diff", description: msg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.hunks.isEmpty {
            CEContentUnavailableView(
                "No Changes",
                description: "This file has no differences to display.",
                systemImage: "checkmark.circle"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isMarkdown {
                        MarkdownDiffView(hunks: viewModel.hunks, mode: viewModel.displayMode)
                    } else {
                        CodeDiffView(hunks: viewModel.hunks, mode: viewModel.displayMode)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
            }
        }
    }
}

// MARK: - Convenience wrapper for sheet(item:)

/// A thin Identifiable wrapper so callers can use `.sheet(item: $diffSource)`.
struct DiffSource: Identifiable {
    let id = UUID()
    let source: DiffViewModel.Source
    let gitClient: GitClient
}
