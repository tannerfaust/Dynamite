//
//  SourceControlNavigatorChangesList.swift
//  CodeEdit
//
//  Created by Austin Condiff on 11/18/23.
//

import AppKit
import SwiftUI

struct SourceControlNavigatorChangesList: View {
    @EnvironmentObject var workspace: WorkspaceDocument
    @EnvironmentObject var sourceControlManager: SourceControlManager

    @State var selection = Set<GitChangedFile>()
    @State private var diffSource: DiffSource?

    var body: some View {
        List($sourceControlManager.changedFiles, selection: $selection) { $file in
            GitChangedFileListView(changedFile: $file)
                .listRowSeparator(.hidden)
                .padding(.vertical, -1)
                .tag($file.wrappedValue)
        }
        .environment(\.defaultMinListRowHeight, 22)
        .contextMenu(
            forSelectionType: GitChangedFile.self,
            menu: { selectedFiles in
                if selectedFiles.count == 1,
                   let file = selectedFiles.first {
                    Group {
                        Button("View Diff") {
                            openDiff(file)
                        }
                        Divider()
                        Button("View in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([file.fileURL.absoluteURL])
                        }
                        Button("Reveal in Project Navigator") {}
                            .disabled(true) // TODO: Implementation Needed
                        Divider()
                    }
                    Group {
                        Button("Open in New Tab") {
                            openGitFile(file)
                        }
                        Button("Open in New Window") {}
                            .disabled(true) // TODO: Implementation Needed
                    }
                    if file.anyStatus() != .none {
                        Group {
                            Divider()
                            Button("Discard Changes in \(file.fileURL.lastPathComponent)...") {
                                sourceControlManager.discardChanges(for: file.fileURL)
                            }
                            Divider()
                        }
                    }
                } else {
                    EmptyView()
                }
            },
            // double-click opens diff
            primaryAction: { selectedFiles in
                if selectedFiles.count == 1,
                   let file = selectedFiles.first {
                    openDiff(file)
                }
            }
        )
        .onChange(of: selection) { _, newSelection in
            if newSelection.count == 1,
               let file = newSelection.first {
                openGitFile(file)
            }
        }
        .sheet(item: $diffSource) { item in
            DiffPaneView(source: item.source, gitClient: item.gitClient)
        }
    }

    private func openGitFile(_ file: GitChangedFile) {
        guard let ceFile = workspace.workspaceFileManager?.getFile(file.ceFileKey, createIfNotFound: true) else {
            return
        }
        DispatchQueue.main.async {
            workspace.editorManager?.openTab(item: ceFile, asTemporary: true)
        }
    }

    private func openDiff(_ file: GitChangedFile) {
        diffSource = DiffSource(
            source: .workingTree(file: file, staged: file.isStaged),
            gitClient: sourceControlManager.gitClient
        )
    }
}
