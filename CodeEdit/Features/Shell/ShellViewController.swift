//
//  ShellViewController.swift
//  CodeEdit
//

import Cocoa
import SwiftUI
import Combine

/// Mode container that owns the two child view controllers for one workspace window.
///
/// `ShellViewController` is the window's `contentViewController`. It holds:
/// - **IDE child** (`CodeEditSplitViewController`) — always built at `viewDidLoad`, pixel-identical
///   to the pre-Shell behavior.
/// - **Cockpit child** (`NSHostingController<CockpitRootView>`) — built lazily on first switch to
///   Cockpit mode, then kept alive so canvas/editor state survives round-trips.
///
/// ## Rollout phases (ADR-0006 §Rollout)
/// - **Phase A** (`FeatureFlags.cockpitView == false`): only the IDE child is built; no switcher UI,
///   no mode state machine, no keybinding changes. Behavior is pixel-identical to today.
/// - **Phase B** (`FeatureFlags.cockpitView == true`): switcher active; both children built on demand.
final class ShellViewController: NSViewController {
    // MARK: - Properties

    private weak var workspace: WorkspaceDocument?
    private weak var windowController: CodeEditWindowController?

    /// The IDE split view controller. Available after `viewDidLoad`.
    private(set) var ideViewController: CodeEditSplitViewController?
    /// The navigator view model, created alongside the IDE VC. Available after `viewDidLoad`.
    private(set) var navigatorViewModel: NavigatorAreaViewModel?

    private var cockpitHostingController: NSHostingController<CockpitRootView>?

    /// Registry of Cockpit surfaces. Shared with `CockpitRootView` and exposed for feature registration.
    let registry = CockpitSurfaceRegistry()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(workspace: WorkspaceDocument, windowController: CodeEditWindowController) {
        self.workspace = workspace
        self.windowController = windowController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildIDEChild()

        guard FeatureFlags.cockpitView else { return }

        let savedMode = restoredMode()
        if savedMode == .cockpit {
            buildCockpitChildIfNeeded()
            applyMode(.cockpit, animated: false)
            windowController?.viewMode = .cockpit
        }
        // .ide is the default; IDE child is already visible from buildIDEChild().
    }

    // MARK: - Mode switching

    /// Switches to `mode`, crossfading the active child. Persists the choice to workspace state.
    ///
    /// This is the single call-site for all mode switches (toolbar, menu, `Router`, keyboard).
    func setViewMode(_ mode: ViewMode, animated: Bool = true) {
        guard FeatureFlags.cockpitView else { return }
        guard mode != currentMode else { return }

        if mode == .cockpit {
            buildCockpitChildIfNeeded()
        }

        applyMode(mode, animated: animated)
        workspace?.addToWorkspaceState(key: .viewMode, value: mode.rawValue)
        windowController?.viewMode = mode
    }

    // MARK: - Private: child construction

    private func buildIDEChild() {
        guard let workspace, let windowController, let window = windowController.window else { return }

        let navModel = NavigatorAreaViewModel()
        navigatorViewModel = navModel

        let ideVC = CodeEditSplitViewController(
            workspace: workspace,
            navigatorViewModel: navModel,
            windowRef: window
        )
        addChild(ideVC)
        view.addSubview(ideVC.view)
        ideVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ideVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ideVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ideVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            ideVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.ideViewController = ideVC
    }

    private func registerCockpitSurfaces() {
        guard let workspaceURL = workspace?.fileURL else { return }
        registry.register(StudioSurface(
            workspaceURL: workspaceURL,
            linkIndexManager: workspace?.linkIndexManager
        ))
        registry.register(MapSurface(
            linkIndexManager: workspace?.linkIndexManager,
            router: workspace?.router
        ))
    }

    private func buildCockpitChildIfNeeded() {
        guard cockpitHostingController == nil else { return }

        registerCockpitSurfaces()
        let rootView = CockpitRootView(registry: registry, workspaceURL: workspace?.fileURL)
        let hosting = NSHostingController(rootView: rootView)
        // Don't let SwiftUI export the Cockpit's minimum size into AppKit. The hosting view is
        // pinned edge-to-edge, so any min-size constraint propagates to the window — and since
        // this child stays in the hierarchy (hidden) after the first mode switch, it would lock
        // the window's minimum size in IDE mode too (window refused to shrink below ~half screen).
        hosting.sizingOptions = []
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.view.isHidden = true
        cockpitHostingController = hosting
    }

    // MARK: - Private: mode application

    private var currentMode: ViewMode {
        windowController?.viewMode ?? .ide
    }

    private func applyMode(_ mode: ViewMode, animated: Bool) {
        let showIDE = mode == .ide
        let ideView = ideViewController?.view
        let cockpitView = cockpitHostingController?.view

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.allowsImplicitAnimation = true
                ideView?.isHidden = !showIDE
                cockpitView?.isHidden = showIDE
            }
        } else {
            ideView?.isHidden = !showIDE
            cockpitView?.isHidden = showIDE
        }
    }

    private func restoredMode() -> ViewMode {
        guard let raw = workspace?.getFromWorkspaceState(.viewMode) as? String,
              let mode = ViewMode(rawValue: raw) else { return .ide }
        return mode
    }
}
