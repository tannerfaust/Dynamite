//
//  ShellViewController.swift
//  CodeEdit
//

import Cocoa
import SwiftUI
import Combine

/// Environment container that owns the two child view controllers for one workspace window.
///
/// `ShellViewController` is the window's `contentViewController`. It holds:
/// - **Ground Control child** (`CodeEditSplitViewController`) — CodeEdit's editor, source-control,
///   terminal, and review environment.
/// - **Product Studio child** (`NSHostingController<ProductStudioRootView>`) — built lazily on
///   first switch to Studio mode, then kept alive so Studio state survives round-trips.
///
/// ## Rollout phases (ADR-0006 §Rollout)
/// - **Phase A** (`FeatureFlags.cockpitView == false`): only Ground Control is built; no switcher UI,
///   no mode state machine, no keybinding changes. Behavior is pixel-identical to CodeEdit.
/// - **Phase B** (`FeatureFlags.cockpitView == true`): switcher active; both children built on demand.
final class ShellViewController: NSViewController {
    // MARK: - Properties

    private weak var workspace: WorkspaceDocument?
    private weak var windowController: CodeEditWindowController?

    /// The Ground Control split view controller. Available after `viewDidLoad`.
    private(set) var ideViewController: CodeEditSplitViewController?
    /// The navigator view model, created alongside Ground Control. Available after `viewDidLoad`.
    private(set) var navigatorViewModel: NavigatorAreaViewModel?

    private var studioHostingController: NSHostingController<ProductStudioRootView>?

    /// True once the initial mode has been applied in `viewDidLoad`. Reveal-time repair of Ground
    /// Control must only run after this; doing it during window setup breaks window creation.
    private var didApplyInitialMode = false

    /// Whether Ground Control has been revealed (and repaired) at least once. It is built hidden when
    /// the window restores into Product Studio, so its first reveal needs repair or it shows blank.
    private var didRevealIDE = false

    /// Whether the one-time background prime of Ground Control has been kicked off. Prevents the
    /// `viewDidAppear` prime from running more than once.
    private var didPrimedGroundControl = false

    /// Source of truth for the active child view.
    ///
    /// Keep this inside the shell instead of deriving it from toolbar/UI state; toolbar rebuilds
    /// are AppKit chrome and should not be part of the environment state machine.
    private var activeMode: ViewMode = .groundControl

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
        if savedMode == .studio {
            buildStudioChildIfNeeded()
            applyMode(.studio)
        } else {
            applyMode(.groundControl)
        }
        activeMode = savedMode
        windowController?.viewMode = savedMode
        workspace?.addToWorkspaceState(key: .viewMode, value: savedMode.routeValue)
        didApplyInitialMode = true
        if savedMode == .groundControl { didRevealIDE = true }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // When the window restored into Product Studio, Ground Control was built hidden and never laid
        // out, so its first reveal came up blank until cycled. Rather than repair on the user's first
        // click (which left it needing a second click), prime it *now* — in the background, while the
        // user is looking at Studio — so the very first click lands on a fully loaded IDE.
        guard FeatureFlags.cockpitView, didApplyInitialMode, currentMode == .studio, !didPrimedGroundControl
        else { return }
        primeGroundControlInBackground()
    }

    // MARK: - Mode switching

    /// Switches to `mode`, crossfading the active child. Persists the choice to workspace state.
    ///
    /// This is the single call-site for all mode switches (toolbar, menu, `Router`, keyboard).
    func setViewMode(_ mode: ViewMode, animated: Bool = true) {
        guard FeatureFlags.cockpitView else { return }
        _ = animated // Switching is intentionally deterministic; see `applyMode(_:)`.

        if mode == .studio {
            buildStudioChildIfNeeded()
        }

        if mode == currentMode {
            applyMode(mode)
            restoreWindowFocus()
            return
        }

        activeMode = mode
        windowController?.viewMode = mode
        applyMode(mode)
        workspace?.addToWorkspaceState(key: .viewMode, value: mode.routeValue)
        restoreWindowFocus()

        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentMode == mode else { return }
            self.windowController?.refreshToolbarForViewMode()
            self.restoreWindowFocus()
        }
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

    private func buildStudioChildIfNeeded() {
        guard studioHostingController == nil else { return }

        let rootView = ProductStudioRootView(
            workspaceURL: workspace?.fileURL,
            linkIndexManager: workspace?.linkIndexManager,
            router: workspace?.router,
            sourceControlManager: workspace?.workspaceFileManager?.sourceControlManager,
            onOpenGroundControl: { [weak self] in self?.setViewMode(.groundControl) }
        )
        let hosting = NSHostingController(rootView: rootView)
        // Don't let SwiftUI export the Studio's minimum size into AppKit. The hosting view is
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
        studioHostingController = hosting
    }

    // MARK: - Private: mode application

    private var currentMode: ViewMode {
        activeMode
    }

    private func applyMode(_ mode: ViewMode) {
        let showIDE = mode == .groundControl
        let ideView = ideViewController?.view
        let studioView = studioHostingController?.view
        let activeView = showIDE ? ideView : studioView

        // Exactly one child is visible at a time. Both children unhidden makes the workspace window
        // fail to appear (the Studio hosting view's layout participates in window setup), so visibility
        // is driven by `isHidden`, not z-order.
        ideView?.alphaValue = 1
        studioView?.alphaValue = 1
        ideView?.isHidden = !showIDE
        studioView?.isHidden = showIDE

        if let activeView, activeView.superview === view {
            view.addSubview(activeView, positioned: .above, relativeTo: nil)
        }

        // First runtime reveal of Ground Control (it launched hidden because the window restored into
        // Product Studio): a hidden split view never completes its first appearance, so its editor and
        // file tree come up blank ("green screen") until the user toggles modes by hand. Reproduce that
        // toggle programmatically — cycle Ground Control's visibility off and back on across runloops —
        // which is the only thing that fully drives the panes (editor AND navigator) to load. Gated to
        // post-launch: touching visibility during `viewDidLoad` breaks window creation.
        if showIDE, didApplyInitialMode, !didRevealIDE {
            didRevealIDE = true
            warmUpGroundControlOnFirstReveal()
        }
    }

    /// Drives Ground Control through one visibility cycle (hide → show across runloops) so its hidden
    /// child controllers complete the appearance they missed at launch. This mirrors the manual
    /// Studio→Ground Control toggle users currently rely on to get past the blank first reveal; the
    /// brief Studio frame in between is a single runloop and effectively invisible.
    private func warmUpGroundControlOnFirstReveal() {
        guard let ideView = ideViewController?.view else { return }
        let studioView = studioHostingController?.view
        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentMode == .groundControl else { return }
            ideView.isHidden = true
            studioView?.isHidden = false
            DispatchQueue.main.async {
                guard self.currentMode == .groundControl else { return }
                studioView?.isHidden = true
                ideView.isHidden = false
                self.view.addSubview(ideView, positioned: .above, relativeTo: nil)
            }
        }
    }

    /// Lays out Ground Control once, in the background, while Product Studio stays on top and visible.
    ///
    /// A hidden split view never lays out, so its editor and file tree stay empty until something
    /// forces a layout pass. Here we briefly unhide Ground Control *behind* the opaque Studio view
    /// (so nothing flashes on screen), let it lay out across a short window, then re-hide it. By the
    /// time the user clicks into Ground Control it is already fully populated — no blank first reveal,
    /// no second click. Studio is re-pinned on top throughout so this stays invisible.
    private func primeGroundControlInBackground() {
        guard let ideView = ideViewController?.view, let studioView = studioHostingController?.view
        else { return }
        didPrimedGroundControl = true

        // The prime lays Ground Control out off-screen; its split view must NOT persist the transient
        // width it sees during that hidden layout, or the navigator sidebar inflates on later reveals.
        ideViewController?.suppressesWidthPersistence = true

        // Keep Studio visible and on top; unhide Ground Control behind it so it lays out unseen.
        studioView.isHidden = false
        ideView.isHidden = false
        view.addSubview(studioView, positioned: .above, relativeTo: nil)
        ideView.layoutSubtreeIfNeeded()

        // Give it a few runloops to complete layout (editor typesetting + navigator data source),
        // then re-hide — unless the user has since switched into Ground Control themselves.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.ideViewController?.suppressesWidthPersistence = false
            guard self.currentMode == .studio else { return }
            ideView.isHidden = true
            studioView.isHidden = false
            self.view.addSubview(studioView, positioned: .above, relativeTo: nil)
            // Ground Control has now laid out at least once; its first real reveal is instant.
            self.didRevealIDE = true
        }
    }

    private func restoreWindowFocus() {
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoredMode() -> ViewMode {
        guard let raw = workspace?.getFromWorkspaceState(.viewMode) as? String,
              let mode = ViewMode(workspaceStateValue: raw) else { return .studio }
        return mode
    }
}
