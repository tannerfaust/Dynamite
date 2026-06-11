//
//  DiffViewModel.swift
//  CodeEdit
//
//  Created for Dynamite — T0.4 Doc Review Parity
//

import Foundation

@MainActor
final class DiffViewModel: ObservableObject {
    enum Source {
        case workingTree(file: GitChangedFile, staged: Bool)
        case commit(commitHash: String, filePath: String)
    }

    enum DisplayMode: String, CaseIterable {
        case inline = "Inline"
        case sideBySide = "Side by Side"
    }

    @Published var hunks: [DiffHunk] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var displayMode: DisplayMode = .inline

    let fileName: String
    let isMarkdown: Bool

    private let source: Source
    private let gitClient: GitClient

    init(source: Source, gitClient: GitClient) {
        self.source = source
        self.gitClient = gitClient

        let rawPath: String
        switch source {
        case .workingTree(let file, _):
            rawPath = file.fileURL.lastPathComponent
        case .commit(_, let path):
            rawPath = URL(filePath: path).lastPathComponent
        }
        fileName = rawPath
        let ext = (rawPath as NSString).pathExtension.lowercased()
        isMarkdown = ext == "md" || ext == "markdown"
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            switch source {
            case .workingTree(let file, let staged):
                hunks = try await gitClient.getFileDiff(
                    filePath: file.fileURL.path(percentEncoded: false),
                    staged: staged
                )
            case .commit(let hash, let path):
                hunks = try await gitClient.getCommitFileDiff(commitHash: hash, filePath: path)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
