//
//  StudioRootView.swift
//  CodeEdit
//

import SwiftUI

/// Root layout for the Product Studio Cockpit surface.
struct StudioRootView: View {
    @StateObject var viewModel: StudioViewModel

    init(workspaceURL: URL, linkIndexManager: LinkIndexManager? = nil) {
        _viewModel = StateObject(
            wrappedValue: StudioViewModel(workspaceURL: workspaceURL, linkIndexManager: linkIndexManager)
        )
    }

    var body: some View {
        // A plain HSplitView (not a nested NavigationSplitView) so this surface lives cleanly
        // inside the Cockpit's split view. Nesting two NavigationSplitViews made SwiftUI fight
        // over columns and pushed the editor off-screen. Roadmap mode goes full-width — its
        // board is the content, so no list rail is needed.
        Group {
            if viewModel.displayMode == .roadmap {
                VStack(spacing: 0) {
                    studioModePicker
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    Divider()
                    RoadmapBoardView(viewModel: viewModel)
                }
            } else {
                HSplitView {
                    VStack(spacing: 0) {
                        studioModePicker
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        Divider()
                        ArtifactListView(viewModel: viewModel)
                    }
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 340)

                    detailContent
                        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .background(.windowBackground)
    }

    @ViewBuilder private var detailContent: some View {
        if let artifact = viewModel.selectedArtifact {
            ArtifactEditorView(viewModel: viewModel, artifact: artifact)
                .id(artifact.id)
        } else {
            emptyDetail
        }
    }

    private var studioModePicker: some View {
        Picker("Studio Mode", selection: $viewModel.displayMode) {
            ForEach(StudioDisplayMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("Select an artifact to view or edit it.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("New Artifact") { viewModel.showingNewArtifactSheet = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }
}
