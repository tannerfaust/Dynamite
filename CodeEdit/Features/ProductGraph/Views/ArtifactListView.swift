//
//  ArtifactListView.swift
//  CodeEdit
//

import SwiftUI

/// Sidebar list of product artifacts with category filter chips and kind/status badges.
struct ArtifactListView: View {
    @ObservedObject var viewModel: StudioViewModel

    var body: some View {
        VStack(spacing: 0) {
            listHeader
            Divider()
            filterBar
            artifactList
        }
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack {
            Text("\(viewModel.filteredArtifacts.count) artifact\(viewModel.filteredArtifacts.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button { viewModel.showingNewArtifactSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("New artifact (⌥N)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Category filter chips

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "All", selected: viewModel.categoryFilter == nil) {
                    viewModel.categoryFilter = nil
                }
                ForEach(ArtifactCategory.allCases) { cat in
                    // Show only the first word (e.g. "Discovery" instead of "Discovery & Strategy")
                    let label = cat.displayName.components(separatedBy: " ").first ?? cat.displayName
                    FilterChip(label: label, selected: viewModel.categoryFilter == cat) {
                        viewModel.categoryFilter = cat
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Artifact list

    @ViewBuilder private var artifactList: some View {
        if viewModel.store.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredArtifacts.isEmpty {
            emptyState
        } else {
            List(viewModel.filteredArtifacts, selection: $viewModel.selectedArtifactID) { artifact in
                ArtifactRow(artifact: artifact)
                    .tag(artifact.id)
            }
            .listStyle(.sidebar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.tertiary)
            Text(viewModel.categoryFilter == nil ? "No artifacts yet" : "None in this category")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("New Artifact") { viewModel.showingNewArtifactSheet = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct ArtifactRow: View {
    let artifact: ProductArtifact

    var body: some View {
        HStack(spacing: 8) {
            KindBadge(kind: artifact.kind, kindString: artifact.kindString, size: .regular)
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.displayTitle)
                    .font(.system(size: 12))
                    .lineLimit(1)
                StatusBadge(status: artifact.status)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.accentColor : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(selected ? Color.accentColor.opacity(0.12) : Color.clear)
                        .overlay(
                            Capsule().strokeBorder(
                                selected ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.25),
                                lineWidth: 0.5
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
