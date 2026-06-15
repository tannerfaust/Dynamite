//
//  ProjectNavigatorViewController+NSOutlineViewDataSource.swift
//  CodeEdit
//
//  Created by Khan Winter on 7/13/24.
//

import AppKit

extension ProjectNavigatorViewController: NSOutlineViewDataSource {
    /// Retrieves the children of a given item for the outline view, applying the current filter if necessary.
    ///
    /// `NSOutlineView` calls `numberOfChildrenOfItem`/`child(ofItem:)` many times per layout pass —
    /// for every visible row, and repeatedly during scrolling, expand/collapse, and window resize.
    /// Computing + sorting on every call made those passes O(children² · log) per folder and was the
    /// dominant cause of single-digit-fps animations in larger projects. We memoize the final, sorted
    /// array per item in ``sortedChildrenCache`` so repeat queries are O(1) dictionary hits. The cache
    /// is invalidated on structural change (``fileManagerUpdated``), filter/sort change
    /// (``handleFilterChange``), and file mutations (menu actions) — never per frame.
    private func getOutlineViewItems(for item: CEWorkspaceFile) -> [CEWorkspaceFile] {
        if let cached = sortedChildrenCache[item] {
            return cached
        }
        let computed = computeOutlineViewItems(for: item)
        sortedChildrenCache[item] = computed
        return computed
    }

    private func computeOutlineViewItems(for item: CEWorkspaceFile) -> [CEWorkspaceFile] {
        // Folders force-shown by a filter match (see `saveAllContentChildren`) are pinned here.
        if let forcedChildren = filteredContentChildren[item] {
            return sortFiles(forcedChildren)
        }

        guard let workspace, let children = workspace.workspaceFileManager?.childrenOfFile(item) else {
            return []
        }

        if !workspace.navigatorFilter.isEmpty || workspace.sourceControlFilter {
            let filteredChildren = children.filter {
                fileSearchMatches(
                    workspace.navigatorFilter,
                    for: $0,
                    sourceControlFilter: workspace.sourceControlFilter
                )
            }
            filteredContentChildren[item] = filteredChildren
            return sortFiles(filteredChildren)
        }

        return sortFiles(children)
    }

    private func sortFiles(_ files: [CEWorkspaceFile]) -> [CEWorkspaceFile] {
        let foldersOnTop = workspace?.sortFoldersOnTop == true
        return files.sorted { lhs, rhs in
            foldersOnTop ? lhs.isFolder && !rhs.isFolder : lhs.name < rhs.name
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? CEWorkspaceFile {
            return getOutlineViewItems(for: item).count
        }
        return content.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? CEWorkspaceFile {
            return getOutlineViewItems(for: item)[index]
        }
        return content[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? CEWorkspaceFile {
            return item.isFolder
        }
        return false
    }

    /// Write dragged file(s) to pasteboard
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let fileItem = item as? CEWorkspaceFile else { return nil }
        return fileItem.url as NSURL
    }

    /// Declare valid drop target
    func outlineView(
        _ outlineView: NSOutlineView,
        validateDrop info: NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        guard let fileItem = item as? CEWorkspaceFile else { return [] }
        // -1 index indicates that we are hovering over a row in outline view (folder or file)
        if index == -1 {
            if !fileItem.isFolder {
                outlineView.setDropItem(fileItem.parent, dropChildIndex: index)
            }
            return info.draggingSourceOperationMask == .copy ? .copy : .move
        }
        return []
    }

    /// Handle successful or unsuccessful drop
    func outlineView(
        _ outlineView: NSOutlineView,
        acceptDrop info: NSDraggingInfo,
        item: Any?,
        childIndex index: Int
    ) -> Bool {
        guard let pasteboardItems = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) else { return false }
        let fileItemURLS = pasteboardItems.compactMap { $0 as? URL }

        guard let fileItemDestination = item as? CEWorkspaceFile else { return false }
        let destParentURL = fileItemDestination.url

        for fileItemURL in fileItemURLS {
            let destURL = destParentURL.appending(path: fileItemURL.lastPathComponent)
            // cancel dropping file item on self or in parent directory
            if fileItemURL == destURL || fileItemURL == destParentURL {
                return false
            }

            // Needs to come before call to .removeItem or else race condition occurs
            var srcFileItem: CEWorkspaceFile? = workspace?.workspaceFileManager?.getFile(fileItemURL.path)
            // If srcFileItem is nil, fileItemUrl is an external file url.
            if srcFileItem == nil {
                srcFileItem = CEWorkspaceFile(url: URL(fileURLWithPath: fileItemURL.path))
            }

            guard let srcFileItem else {
                return false
            }

            if CEWorkspaceFile.fileManager.fileExists(atPath: destURL.path) {
                let shouldReplace = replaceFileDialog(fileName: fileItemURL.lastPathComponent)
                guard shouldReplace else {
                    return false
                }
                do {
                    try CEWorkspaceFile.fileManager.removeItem(at: destURL)
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
            if info.draggingSourceOperationMask == .copy {
                self.copyFile(file: srcFileItem, to: destURL)
            } else {
                self.moveFile(file: srcFileItem, to: destURL)
            }
        }
        return true
    }

    func replaceFileDialog(fileName: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = """
        A file or folder with the name \(fileName) already exists in the destination folder. Do you want to replace it?
        """
        alert.informativeText = "This action is irreversible!"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
