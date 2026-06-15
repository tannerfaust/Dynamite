//
//  CodeEditSplitViewController.swift
//  CodeEdit
//
//  Created by YAPRYNTSEV Aleksey on 31.12.2022.
//

import Cocoa
import SwiftUI

final class CodeEditSplitViewController: NSSplitViewController {
    static let minSidebarWidth: CGFloat = 242
    static let maxSnapWidth: CGFloat = snapWidth + 10
    static let snapWidth: CGFloat = 272
    static let minSnapWidth: CGFloat = snapWidth - 10
    /// Upper bound for a *persisted* navigator width. A wider value is treated as a corrupted
    /// (runaway) layout — it is neither saved nor restored, healing the inflation bug where the
    /// sidebar grew on every Studio↔Ground Control round-trip.
    static let maxPersistedSidebarWidth: CGFloat = 500

    private weak var workspace: WorkspaceDocument?
    private weak var navigatorViewModel: NavigatorAreaViewModel?
    private weak var windowRef: NSWindow?
    private unowned var hapticPerformer: NSHapticFeedbackPerformer

    /// When true, divider-resize callbacks do not persist the navigator width.
    ///
    /// Set while Ground Control is laid out off-screen (e.g. the Shell's background prime, or while a
    /// programmatic `setPosition` settles) so a transient, not-yet-constrained layout can't write a
    /// bogus width into workspace state. Without this guard the sidebar inflated on every reveal.
    var suppressesWidthPersistence = false

    // MARK: - Initialization

    init(
        workspace: WorkspaceDocument,
        navigatorViewModel: NavigatorAreaViewModel,
        windowRef: NSWindow,
        hapticPerformer: NSHapticFeedbackPerformer = NSHapticFeedbackManager.defaultPerformer
    ) {
        self.workspace = workspace
        self.navigatorViewModel = navigatorViewModel
        self.windowRef = windowRef
        self.hapticPerformer = hapticPerformer
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let windowRef else {
            // swiftlint:disable:next line_length
            assertionFailure("No WindowRef found, not initialized properly or the window was dereferenced and the controller was not.")
            return
        }

        guard let workspace,
              let navigatorViewModel,
              let editorManager = workspace.editorManager,
              let statusBarViewModel = workspace.statusBarViewModel,
              let utilityAreaModel = workspace.utilityAreaModel,
              let taskManager = workspace.taskManager else {
            // swiftlint:disable:next line_length
            assertionFailure("Missing a workspace model: workspace=\(workspace == nil), navigator=\(navigatorViewModel == nil), editorManager=\(workspace?.editorManager == nil), statusBarModel=\(workspace?.statusBarViewModel == nil), utilityAreaModel=\(workspace?.utilityAreaModel == nil), taskManager=\(workspace?.taskManager == nil)")
            return
        }

        splitView.translatesAutoresizingMaskIntoConstraints = false

        let navigator = makeNavigator(view: SettingsInjector {
            NavigatorAreaView(
                workspace: workspace,
                viewModel: navigatorViewModel,
                onOpenProductStudio: { [weak windowRef] in
                    (windowRef?.windowController as? CodeEditWindowController)?.switchViewMode(to: .studio)
                }
            )
                .environmentObject(workspace)
                .environmentObject(editorManager)
        })

        addSplitViewItem(navigator)

        let workspaceView = SettingsInjector {
            WindowObserver(window: WindowBox(value: windowRef)) {
                WorkspaceView()
                    .environmentObject(workspace)
                    .environmentObject(editorManager)
                    .environmentObject(statusBarViewModel)
                    .environmentObject(utilityAreaModel)
                    .environmentObject(taskManager)
                    .environmentObject(workspace.undoRegistration)
            }
        }

        let mainContent = NSSplitViewItem(viewController: makeSplitPaneHostingController(rootView: workspaceView))
        mainContent.titlebarSeparatorStyle = .line
        mainContent.minimumThickness = 200

        addSplitViewItem(mainContent)

        let inspector = makeInspector(view: SettingsInjector {
            InspectorAreaView(viewModel: InspectorAreaViewModel())
                .environmentObject(workspace)
                .environmentObject(editorManager)
        })

        addSplitViewItem(inspector)
    }

    private func makeNavigator(view: some View) -> NSSplitViewItem {
        let navigator = NSSplitViewItem(sidebarWithViewController: makeSplitPaneHostingController(rootView: view))
        if #unavailable(macOS 26) {
            navigator.titlebarSeparatorStyle = .none
        }
        navigator.isSpringLoaded = true
        navigator.minimumThickness = Self.minSidebarWidth
        navigator.collapseBehavior = .useConstraints
        return navigator
    }

    private func makeInspector(view: some View) -> NSSplitViewItem {
        let inspector = NSSplitViewItem(inspectorWithViewController: makeSplitPaneHostingController(rootView: view))
        inspector.titlebarSeparatorStyle = .none
        inspector.minimumThickness = Self.minSidebarWidth
        inspector.maximumThickness = .greatestFiniteMagnitude
        inspector.collapseBehavior = .useConstraints
        inspector.isSpringLoaded = true
        return inspector
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        guard let workspace else { return }

        // Restore the navigator width, but heal an out-of-range (corrupted/runaway) value back to the
        // default snap width instead of faithfully restoring a broken layout.
        let saved = workspace.getFromWorkspaceState(.splitViewWidth) as? CGFloat
        let restoredWidth: CGFloat
        if let saved, (Self.minSidebarWidth...Self.maxPersistedSidebarWidth).contains(saved) {
            restoredWidth = saved
        } else {
            restoredWidth = Self.snapWidth
        }
        // Don't let the resize this triggers write back a transient value mid-settle.
        suppressesWidthPersistence = true
        splitView.setPosition(restoredWidth, ofDividerAt: 0)
        DispatchQueue.main.async { [weak self] in self?.suppressesWidthPersistence = false }

        if let firstSplitView = splitViewItems.first {
            firstSplitView.isCollapsed = workspace.getFromWorkspaceState(
                .navigatorCollapsed
            ) as? Bool ?? false
        }

        if let lastSplitView = splitViewItems.last {
            lastSplitView.isCollapsed = workspace.getFromWorkspaceState(
                .inspectorCollapsed
            ) as? Bool ?? true
        }

        workspace.notificationPanel.updateToolbarItem()
    }

    // MARK: - NSSplitViewDelegate

    /// Perform the spring loaded navigator splits.
    /// - Note: This could be removed. The only additional functionality this provides over using just the
    ///         `NSSplitViewItem.isSpringLoaded` & `NSSplitViewItem.minimumThickness` is the haptic feedback we add.
    /// - Parameters:
    ///   - splitView: The split view to use.
    ///   - proposedPosition: The proposed drag position.
    ///   - dividerIndex: The index of the divider being dragged.
    /// - Returns: The position to move the divider to.
    override func splitView(
        _ splitView: NSSplitView,
        constrainSplitPosition proposedPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        switch dividerIndex {
        case 0:
            // Navigator
            if (Self.minSnapWidth...Self.maxSnapWidth).contains(proposedPosition) {
                return Self.snapWidth
            } else if proposedPosition <= Self.minSidebarWidth / 2 {
                hapticCollapse(splitViewItems.first, collapseAction: true)
                return 0
            } else {
                hapticCollapse(splitViewItems.first, collapseAction: false)
                return max(Self.minSidebarWidth, proposedPosition)
            }
        case 1:
            let proposedWidth = view.frame.width - proposedPosition
            if proposedWidth <= Self.minSidebarWidth / 2 {
                hapticCollapse(splitViewItems.last, collapseAction: true)
                return proposedPosition
            } else {
                hapticCollapse(splitViewItems.last, collapseAction: false)
                return min(view.frame.width - Self.minSidebarWidth, proposedPosition)
            }
        default:
            return proposedPosition
        }
    }

    /// Performs a haptic feedback while collapsing or revealing a split item.
    /// If the item was not previously in the new intended state, a haptic `.alignment` feedback is sent.
    /// - Parameters:
    ///   - item: The item to collapse or reveal
    ///   - collapseAction: Whether or not to collapse the item. Set to true to collapse it.
    private func hapticCollapse(_ item: NSSplitViewItem?, collapseAction: Bool) {
        guard let item, item.isCollapsed != collapseAction else {
            return
        }

        hapticPerformer.perform(.alignment, performanceTime: .now)
        item.isCollapsed = collapseAction
    }

    /// Save the width of the inspector and navigator between sessions.
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        // Ignore resizes that aren't a real, on-screen, user-visible layout: while priming/settling,
        // or while the split view is hidden (e.g. Product Studio is showing and Ground Control sits
        // hidden behind it). Persisting those transient widths is what inflated the sidebar.
        guard !suppressesWidthPersistence, !view.isHiddenOrHasHiddenAncestor else { return }
        guard let resizedDivider = notification.userInfo?["NSSplitViewDividerIndex"] as? Int else {
            return
        }

        if resizedDivider == 0 {
            let panel = splitView.subviews[0]
            let width = panel.frame.size.width
            // Only persist sane widths; a runaway value is dropped rather than written back.
            if width > 0, width <= Self.maxPersistedSidebarWidth {
                workspace?.addToWorkspaceState(key: .splitViewWidth, value: width)
            }
        }
    }

    func saveNavigatorCollapsedState(isCollapsed: Bool) {
        workspace?.addToWorkspaceState(key: .navigatorCollapsed, value: isCollapsed)
    }

    func saveInspectorCollapsedState(isCollapsed: Bool) {
        workspace?.addToWorkspaceState(key: .inspectorCollapsed, value: isCollapsed)
    }
}
