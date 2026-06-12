//
//  WorkspaceDocument+CommandListeners.swift
//  CodeEdit
//
//  Created by Khan Winter on 6/5/22.
//

import Foundation
import Combine

class WorkspaceNotificationModel: ObservableObject {

    @Published var highlightedFileItem: CEWorkspaceFile?

    /// A newly created file or folder waiting for the user to type a name inline in the project navigator.
    @Published var fileItemPendingCreationRename: CEWorkspaceFile?

    init() {
        highlightedFileItem = nil
        fileItemPendingCreationRename = nil
    }

    /// Reveals the item in the navigator and begins inline naming, like VS Code's new file flow.
    func requestCreationRename(_ file: CEWorkspaceFile) {
        highlightedFileItem = file
        fileItemPendingCreationRename = file
    }

}
