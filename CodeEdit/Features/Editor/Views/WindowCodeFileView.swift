//
//  WindowCodeFileView.swift
//  CodeEdit
//
//  Created by Khan Winter on 3/19/23.
//

import Foundation
import SwiftUI

/// View that fixes [#1158](https://github.com/CodeEditApp/CodeEdit/issues/1158)
/// # Should **not** be used other than in a single file window.
struct WindowCodeFileView: View {
    @StateObject var editorInstance: EditorInstance
    @StateObject var undoRegistration: UndoManagerRegistration = UndoManagerRegistration()
    @State private var showMinimap: Bool
    @State private var wrapLines: Bool
    var codeFile: CodeFileDocument

    init(codeFile: CodeFileDocument) {
        self._editorInstance = .init(
            wrappedValue: EditorInstance(
                workspace: nil,
                file: CEWorkspaceFile(url: codeFile.fileURL ?? URL(fileURLWithPath: ""))
            )
        )
        self._showMinimap = .init(initialValue: false)
        self._wrapLines = .init(initialValue: Self.defaultWrapLines(for: codeFile))
        self.codeFile = codeFile
    }

    var body: some View {
        Group {
            if let utType = codeFile.utType, utType.conforms(to: .text) {
                VStack(spacing: 0) {
                    standaloneControls
                    Divider()
                    CodeFileView(
                        editorInstance: editorInstance,
                        codeFile: codeFile,
                        showMinimapOverride: showMinimap
                    )
                    .environmentObject(undoRegistration)
                    .onAppear {
                        codeFile.wrapLines = wrapLines
                    }
                    .onChange(of: wrapLines) { _, newValue in
                        codeFile.wrapLines = newValue
                    }
                }
            } else {
                NonTextFileView(fileDocument: codeFile)
            }
        }
        .frame(minWidth: 420, minHeight: 260)
    }

    private var standaloneControls: some View {
        HStack(spacing: 6) {
            Spacer()

            Button {
                wrapLines.toggle()
            } label: {
                Image(systemName: wrapLines ? "text.alignleft" : "textformat.size")
            }
            .help(wrapLines ? "Disable Line Wrap" : "Enable Line Wrap")
            .accessibilityLabel(Text(wrapLines ? "Disable Line Wrap" : "Enable Line Wrap"))

            Button {
                showMinimap.toggle()
            } label: {
                Image(systemName: showMinimap ? "map.fill" : "map")
            }
            .help(showMinimap ? "Hide Minimap" : "Show Minimap")
            .accessibilityLabel(Text(showMinimap ? "Hide Minimap" : "Show Minimap"))
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.bar)
    }

    private static func defaultWrapLines(for codeFile: CodeFileDocument) -> Bool {
        guard let fileExtension = codeFile.fileURL?.pathExtension.lowercased() else {
            return Settings[\.textEditing].wrapLinesToEditorWidth
        }

        switch fileExtension {
        case "md", "markdown", "mdown", "mkd", "txt", "text":
            return true
        default:
            return Settings[\.textEditing].wrapLinesToEditorWidth
        }
    }
}
