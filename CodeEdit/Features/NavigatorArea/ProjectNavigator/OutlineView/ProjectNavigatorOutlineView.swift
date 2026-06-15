//
//  OutlineView.swift
//  CodeEdit
//
//  Created by Lukas Pistrol on 05.04.22.
//

import SwiftUI
import Combine

/// Wraps an ``OutlineViewController`` inside a `NSViewControllerRepresentable`
struct ProjectNavigatorOutlineView: NSViewControllerRepresentable {

    @EnvironmentObject var workspace: WorkspaceDocument
    @EnvironmentObject var editorManager: EditorManager

    @StateObject var prefs: Settings = .shared

    typealias NSViewControllerType = ProjectNavigatorViewController

    func makeNSViewController(context: Context) -> ProjectNavigatorViewController {
        let controller = ProjectNavigatorViewController()
        controller.workspace = workspace
        controller.iconColor = prefs.preferences.general.fileIconStyle
        controller.editor = editorManager.activeEditor
        workspace.workspaceFileManager?.addObserver(context.coordinator)

        context.coordinator.controller = controller

        return controller
    }

    func updateNSViewController(_ nsViewController: ProjectNavigatorViewController, context: Context) {
        nsViewController.iconColor = prefs.preferences.general.fileIconStyle
        nsViewController.rowHeight = prefs.preferences.general.projectNavigatorSize.rowHeight
        nsViewController.fileExtensionsVisibility = prefs.preferences.general.fileExtensionsVisibility
        nsViewController.shownFileExtensions = prefs.preferences.general.shownFileExtensions
        nsViewController.hiddenFileExtensions = prefs.preferences.general.hiddenFileExtensions
        /// if the window becomes active from background, it will restore the selection to outline view.
        nsViewController.updateSelection(itemID: workspace.editorManager?.activeEditor.selectedTab?.file.id)
        return
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(workspace)
    }

    class Coordinator: NSObject, CEWorkspaceFileManagerObserver {
        init(_ workspace: WorkspaceDocument) {
            self.workspace = workspace
            super.init()

            workspace.listenerModel.$highlightedFileItem
                .sink(receiveValue: { [weak self] fileItem in
                    guard let fileItem else {
                        return
                    }
                    if workspace.listenerModel.fileItemPendingCreationRename?.id != fileItem.id {
                        self?.controller?.reveal(fileItem)
                    }
                })
                .store(in: &cancellables)
            workspace.listenerModel.$fileItemPendingCreationRename
                .compactMap { $0 }
                .sink { [weak self] fileItem in
                    self?.controller?.reveal(fileItem)
                    DispatchQueue.main.async {
                        self?.controller?.beginRenaming(fileItem)
                    }
                }
                .store(in: &cancellables)
            workspace.editorManager?.tabBarTabIdSubject
                .sink { [weak self] editorInstance in
                    self?.controller?.updateSelection(itemID: editorInstance?.file.id)
                }
                .store(in: &cancellables)
            workspace.$navigatorFilter
                .throttle(for: 0.1, scheduler: RunLoop.main, latest: true)
                .sink { [weak self] _ in
                    self?.controller?.handleFilterChange()
                }
                .store(in: &cancellables)
            Publishers.Merge(workspace.$sourceControlFilter, workspace.$sortFoldersOnTop)
                .throttle(for: 0.1, scheduler: RunLoop.main, latest: true)
                .sink { [weak self] _ in
                    self?.controller?.handleFilterChange()
                }
                .store(in: &cancellables)
        }

        var cancellables: Set<AnyCancellable> = []
        weak var workspace: WorkspaceDocument?
        weak var controller: ProjectNavigatorViewController?

        func fileManagerUpdated(updatedItems: Set<CEWorkspaceFile>) {
            guard let outlineView = controller?.outlineView else { return }
            // The on-disk tree changed: drop the memoized sorted-children cache so the reload below
            // recomputes from live model state. O(1) clear; the reload re-sorts visible folders once.
            controller?.invalidateChildrenCache()
            let selectedRows = outlineView.selectedRowIndexes.compactMap({ outlineView.item(atRow: $0) })

            // If some text view inside the outline view is first responder right now, push the update off
            // until editing is finished using the `shouldReloadAfterDoneEditing` flag.
            if outlineView.window?.firstResponder !== outlineView
                && outlineView.window?.firstResponder is NSTextView
                && (outlineView.window?.firstResponder as? NSView)?.isDescendant(of: outlineView) == true {
                controller?.shouldReloadAfterDoneEditing = true
            } else {
                // Batch into one update pass, reload only the topmost updated ancestors
                // (reloading an item with `reloadChildren: true` already covers its
                // descendants), and skip rows that aren't visible — collapsed folders read
                // live model state when expanded, so they need no reload now. Git status
                // refreshes in big repos can pass thousands of items here; without this the
                // per-item subtree reloads are the dominant sidebar stall.
                outlineView.beginUpdates()
                for item in updatedItems where !hasAncestor(of: item, in: updatedItems) {
                    if outlineView.row(forItem: item) >= 0 {
                        outlineView.reloadItem(item, reloadChildren: true)
                    }
                }
                outlineView.endUpdates()
            }

            // Restore selected items where the files still exist.
            let selectedIndexes = selectedRows.compactMap({ outlineView.row(forItem: $0) }).filter({ $0 >= 0 })
            controller?.shouldSendSelectionUpdate = false
            outlineView.selectRowIndexes(IndexSet(selectedIndexes), byExtendingSelection: false)
            controller?.shouldSendSelectionUpdate = true
        }

        /// Whether any ancestor of `item` is also in `items` (in which case reloading the
        /// ancestor's subtree already covers `item`).
        private func hasAncestor(of item: CEWorkspaceFile, in items: Set<CEWorkspaceFile>) -> Bool {
            var parent = item.parent
            while let current = parent {
                if items.contains(current) {
                    return true
                }
                parent = current.parent
            }
            return false
        }

        deinit {
            workspace?.workspaceFileManager?.removeObserver(self)
        }
    }
}
