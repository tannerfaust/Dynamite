//
//  DocsListView.swift
//  CodeEdit
//
//  The Docs surface — the typed-artifact workspace, de-IDE'd. Replaces the old
//  HSplitView + file-tree-style `ArtifactListView` + segmented picker with a clean,
//  category-grouped doc list and the existing `ArtifactEditorView` on the right.
//

import SwiftUI

struct DocsListView: View {
    @ObservedObject var viewModel: StudioViewModel

    @State private var query: String = ""

    var body: some View {
        HStack(spacing: 0) {
            docList
                .frame(width: 270)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            StudioTopBar(horizontalPadding: 20, verticalPadding: 13) { header }
        }
        .sheet(isPresented: $viewModel.showingNewArtifactSheet) {
            NewArtifactSheet { kind, title in
                viewModel.createArtifact(kind: kind, title: title)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("Docs")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)
            Text("\(viewModel.store.artifacts.count) artifacts")
                .font(.system(size: 12))
                .foregroundStyle(StudioTheme.textTertiary)
            Spacer()
            StudioPillButton(title: "New doc") { viewModel.showingNewArtifactSheet = true }
        }
    }

    // MARK: - List

    private var docList: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(ArtifactCategory.allCases) { category in
                        let items = artifacts(in: category)
                        if !items.isEmpty {
                            StudioSectionLabel(text: category.displayName)
                                .padding(.horizontal, 14)
                                .padding(.top, 14)
                                .padding(.bottom, 4)
                            ForEach(items) { artifact in
                                DocListRow(
                                    artifact: artifact,
                                    isSelected: artifact.id == viewModel.selectedArtifactID
                                ) {
                                    viewModel.selectedArtifactID = artifact.id
                                }
                            }
                        }
                    }
                    if filteredArtifacts.isEmpty { emptyList }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
        }
        .frame(maxHeight: .infinity)
        .background(StudioTheme.windowBackground)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(StudioTheme.textTertiary)
            TextField("Filter docs…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                .fill(StudioTheme.hover)
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                        .strokeBorder(StudioTheme.hairline, lineWidth: 1)
                )
        )
    }

    private var filteredArtifacts: [ProductArtifact] {
        let all = viewModel.store.artifacts
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.displayTitle.localizedCaseInsensitiveContains(trimmed) }
    }

    private func artifacts(in category: ArtifactCategory) -> [ProductArtifact] {
        filteredArtifacts
            .filter { $0.kind?.category == category }
            .sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
    }

    private var emptyList: some View {
        VStack(spacing: 6) {
            Text(query.isEmpty ? "No docs yet" : "No matches")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(StudioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Detail

    @ViewBuilder private var detail: some View {
        if let artifact = viewModel.selectedArtifact {
            ArtifactEditorView(viewModel: viewModel, artifact: artifact)
                .id(artifact.id)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 34, weight: .thin))
                    .foregroundStyle(StudioTheme.textTertiary)
                Text("Select a doc to view or edit it.")
                    .font(.system(size: 14))
                    .foregroundStyle(StudioTheme.textSecondary)
                Button("New doc") { viewModel.showingNewArtifactSheet = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(StudioTheme.windowBackground)
        }
    }
}

// MARK: - Doc list row

private struct DocListRow: View {
    let artifact: ProductArtifact
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: artifact.kind?.systemImage ?? "doc")
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? StudioTheme.accent : StudioTheme.textSecondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(artifact.displayTitle)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .lineLimit(1)
                    if !artifact.status.isEmpty {
                        Text(artifact.status)
                            .font(.system(size: 10.5))
                            .foregroundStyle(StudioTheme.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                    .fill(isSelected ? StudioTheme.selection : (hovering ? StudioTheme.hover : .clear))
            )
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Open doc \(artifact.displayTitle)")
        .onHover { hover in withAnimation(StudioMotion.hover) { hovering = hover } }
    }
}
