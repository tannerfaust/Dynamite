//
//  CEWorkspaceFileManager+DirectoryEvents.swift
//  CodeEdit
//
//  Created by Axel Martinez on 5/8/24.
//

import Foundation

/// This extension handles the file system events triggered by changes in the root folder.
extension CEWorkspaceFileManager {
    /// Serial background queue for directory listing IO triggered by file system events.
    /// Serial on purpose: event storms (builds, coding agents writing files) queue up behind each
    /// other off the main thread instead of stacking main-thread stalls.
    private static let fsEventIOQueue = DispatchQueue(label: "app.dynamite.fsevents-io", qos: .utility)

    /// Called by `fsEventStream` when an event occurs.
    ///
    /// This method may be called on a background thread. Directory listing (disk IO) stays off the
    /// main thread; only the cheap in-memory reconciliation of the file tree and the observer
    /// notification run on the main thread, in a single hop per event batch.
    /// - Parameter events: An array of events that occurred.
    func fileSystemEventReceived(events: [DirectoryEventStream.Event]) {
        // Parse on the calling thread: collect the set of parent directories affected by
        // structural events. Several events in one batch usually share a parent — deduplicate
        // so each directory is listed and reconciled once per batch, not once per event.
        var parentPaths: Set<String> = []
        for event in events {
            switch event.eventType {
            case .changeInDirectory, .itemChangedOwner, .itemModified:
                // Can be ignored for now, these I think not related to tree changes
                continue
            case .rootChanged:
                // TODO: #1880 - Handle workspace root changing.
                continue
            case .itemCreated, .itemCloned, .itemRemoved, .itemRenamed:
                // Event returns file/folder that was changed, but in tree we need to update it's parent
                guard let parentUrl = URL(
                    string: event.path,
                    relativeTo: folderUrl
                )?.deletingLastPathComponent() else {
                    continue
                }
                parentPaths.insert(parentUrl.path)
            }
        }

        DispatchQueue.main.async {
            // Snapshot which affected directories are cached. The file tree model is
            // main-thread confined, so this read and the later reconciliation happen on main;
            // `resolvedURL` is also resolved here because it is a lazy, non-thread-safe property.
            let parents: [(file: CEWorkspaceFile, url: URL)] = parentPaths
                .compactMap { self.flattenedFileItems[$0] }
                .filter { self.childrenMap[$0.id] != nil }
                .map { ($0, $0.resolvedURL) }

            guard !parents.isEmpty else {
                self.handleGitEventsIfEnabled(events: events)
                return
            }

            self.listAndReconcile(parents: parents, events: events)
        }
    }

    /// Lists the given directories on the background IO queue, then reconciles the file tree and
    /// notifies observers in a single main-thread hop.
    private func listAndReconcile(parents: [(file: CEWorkspaceFile, url: URL)], events: [DirectoryEventStream.Event]) {
        Self.fsEventIOQueue.async {
            // Disk IO off the main thread.
            var listings: [(file: CEWorkspaceFile, contents: [URL])] = []
            for parent in parents {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: parent.url,
                        includingPropertiesForKeys: nil
                    )
                    listings.append((parent.file, contents))
                } catch {
                    self.logger.error("Failed to list directory: \(parent.url.path, privacy: .sensitive)")
                }
            }

            DispatchQueue.main.async {
                var files: Set<CEWorkspaceFile> = []
                for listing in listings {
                    self.reconcileChildren(of: listing.file, withDirectoryContents: listing.contents)
                    files.insert(listing.file)
                }
                if !files.isEmpty {
                    self.notifyObservers(updatedItems: files)
                }
                self.handleGitEventsIfEnabled(events: events)
            }
        }
    }

    /// Forwards git-related events to the source control manager when source control is enabled.
    private func handleGitEventsIfEnabled(events: [DirectoryEventStream.Event]) {
        guard Settings.shared.preferences.sourceControl.general.sourceControlIsEnabled &&
            Settings.shared.preferences.sourceControl.general.refreshStatusLocally else {
            return
        }
        handleGitEvents(events: events)
    }

    func handleGitEvents(events: [DirectoryEventStream.Event]) {
        // Changes excluding .git folder
        let notGitChanges = events.filter({ !$0.path.contains(".git/") })

        // .git folder was changed
        let gitFolderChange = events.first(where: {
            $0.path == "\(self.folderUrl.relativePath)/.git"
        })

        // Change made to git index file, staged/unstaged files
        let gitIndexChange = events.first(where: {
            $0.path == "\(self.folderUrl.relativePath)/.git/index"
        })

        // Change made to git stash
        let gitStashChange = events.first(where: {
            $0.path == "\(self.folderUrl.relativePath)/.git/refs/stash"
        })

        // Changes made to git branches
        let gitBranchChange = events.first(where: {
            $0.path.contains("\(self.folderUrl.relativePath)/.git/refs/heads")
        })

        // Changes made to git HEAD - current branch changed
        let gitHeadChange = events.first(where: {
            $0.path.contains("\(self.folderUrl.relativePath)/.git/HEAD")
        })

        // Change made to remotes by looking at .git/config
        let gitConfigChange = events.first(where: {
            $0.path == "\(self.folderUrl.relativePath)/.git/config"
        })

        // If changes were made to project OR files were staged, refresh changes.
        // Debounced + serialized: write storms (builds, agents) coalesce into one
        // `git status` per window instead of spawning overlapping processes.
        if !notGitChanges.isEmpty || gitIndexChange != nil {
            sourceControlManager?.scheduleStatusRefresh()
        }

        // If changes were stashed, refresh stashed entries
        if gitStashChange != nil {
            Task {
                try await self.sourceControlManager?.refreshStashEntries()
            }
        }

        // If branches were added or removed, refresh branches
        if gitBranchChange != nil {
            Task {
                await self.sourceControlManager?.refreshBranches()
            }
        }

        // If HEAD was changed, refresh the current branch
        if gitHeadChange != nil {
            Task {
                await self.sourceControlManager?.refreshCurrentBranch()
            }
        }

        // If git config changed, refresh remotes
        if gitConfigChange != nil {
            Task {
                try await self.sourceControlManager?.refreshRemotes()
            }
        }

        // If .git folder was added or removed, check if repository is valid
        if gitFolderChange != nil {
            Task {
                try await self.sourceControlManager?.validate()
            }
        }
    }

    /// Creates or deletes children of the ``CEWorkspaceFile`` so that they are accurate with the file system,
    /// instead of creating an entirely new ``CEWorkspaceFile``. Can optionally run a deep rebuild.
    ///
    /// This method will return immediately if the given file item is not a directory.
    /// This will also only rebuild *already cached* directories.
    /// - Parameters:
    ///   - fileItem: The ``CEWorkspaceFile``  to correct the children of
    ///   - deep: Set to `true` if this should perform the rebuild recursively.
    func rebuildFiles(fromItem fileItem: CEWorkspaceFile, deep: Bool = false) throws {
        // Do not index directories that are not already loaded.
        guard childrenMap[fileItem.id] != nil else { return }

        // get the actual directory children
        let directoryContentsUrls = try fileManager.contentsOfDirectory(
            at: fileItem.resolvedURL,
            includingPropertiesForKeys: nil
        )

        reconcileChildren(of: fileItem, withDirectoryContents: directoryContentsUrls)

        if deep && childrenMap[fileItem.id] != nil {
            for child in (childrenMap[fileItem.id] ?? []).compactMap({ flattenedFileItems[$0] }) {
                try rebuildFiles(fromItem: child)
            }
        }
    }

    /// Reconciles the cached children of a directory with an already-fetched directory listing.
    ///
    /// In-memory only — no disk IO besides the `fileExists` check for new children — so callers can
    /// perform the (slow) directory listing on a background queue and apply the result here on the
    /// main thread. Set-based lookups keep this O(children) instead of O(children²).
    /// - Parameters:
    ///   - fileItem: The cached directory item to reconcile.
    ///   - directoryContentsUrls: The directory's current contents as returned by `FileManager`.
    func reconcileChildren(of fileItem: CEWorkspaceFile, withDirectoryContents directoryContentsUrls: [URL]) {
        // Do not index directories that are not already loaded.
        guard let cachedChildren = childrenMap[fileItem.id] else { return }

        // test for deleted children, and remove them from the index
        // Folders may or may not have slash at the end, this will normalize check
        let directoryContentsUrlsRelativePaths = Set(directoryContentsUrls.map({ $0.relativePath }))
        for (idx, oldURL) in cachedChildren.map({ URL(filePath: $0) }).enumerated().reversed()
        where !directoryContentsUrlsRelativePaths.contains(oldURL.relativePath) {
            flattenedFileItems.removeValue(forKey: oldURL.relativePath)
            childrenMap[fileItem.id]?.remove(at: idx)
        }

        // test for new children, and index them
        let existingChildren = Set(childrenMap[fileItem.id] ?? [])
        for newContent in directoryContentsUrls {
            // if the child has already been indexed, continue to the next item.
            guard !ignoredFilesAndFolders.contains(newContent.lastPathComponent) &&
                    !existingChildren.contains(newContent.relativePath) else { continue }

            if fileManager.fileExists(atPath: newContent.path) {
                let newFileItem = createChild(newContent, forParent: fileItem)
                flattenedFileItems[newFileItem.id] = newFileItem
                childrenMap[fileItem.id]?.append(newFileItem.id)
            }
        }

        childrenMap[fileItem.id] = childrenMap[fileItem.id]?
            .map { URL(filePath: $0) }
            .sortItems(foldersOnTop: true)
            .map { $0.relativePath }
    }

    /// Notify observers that an update occurred in the watched files.
    func notifyObservers(updatedItems: Set<CEWorkspaceFile>) {
        observers.allObjects.reversed().forEach { delegate in
            guard let delegate = delegate as? CEWorkspaceFileManagerObserver else {
                observers.remove(delegate)
                return
            }
            delegate.fileManagerUpdated(updatedItems: updatedItems)
        }
    }

    /// Add an observer for file system events.
    /// - Parameter observer: The observer to add.
    func addObserver(_ observer: CEWorkspaceFileManagerObserver) {
        observers.add(observer as AnyObject)
    }

    /// Remove an observer for file system events.
    /// - Parameter observer: The observer to remove.
    func removeObserver(_ observer: CEWorkspaceFileManagerObserver) {
        observers.remove(observer as AnyObject)
    }
}
