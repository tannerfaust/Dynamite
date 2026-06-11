//
//  CodeEditWindowController.swift
//  CodeEdit
//
//  Created by Pavel Kasila on 18.03.22.
//

import Cocoa
import SwiftUI
import Combine

final class CodeEditWindowController: NSWindowController, NSToolbarDelegate, ObservableObject, NSWindowDelegate {
    @Published var navigatorCollapsed: Bool = false
    @Published var inspectorCollapsed: Bool = false
    @Published var toolbarCollapsed: Bool = false

    // These variables store the state of the windows when using "Hide interface"
    @Published var prevNavigatorCollapsed: Bool?
    @Published var prevInspectorCollapsed: Bool?
    @Published var prevUtilityAreaCollapsed: Bool?
    @Published var prevToolbarCollapsed: Bool?

    /// Current view mode for this window. `.ide` is the default and the only mode in Phase A.
    ///
    /// Written exclusively by `ShellViewController.setViewMode(_:animated:)`. Toolbar and menu
    /// items observe this property to reflect the active mode.
    @Published var viewMode: ViewMode = .ide

    private var panelOpen = false

    var observers: [NSKeyValueObservation] = []

    var workspace: WorkspaceDocument?
    var workspaceSettingsWindow: NSWindow?
    var quickOpenPanel: SearchPanel?
    var commandPalettePanel: SearchPanel?
    var navigatorSidebarViewModel: NavigatorAreaViewModel?

    internal var cancellables = [AnyCancellable]()

    /// The IDE split view controller, accessed through the `ShellViewController` container.
    ///
    /// Returns `nil` in Phase B when in Cockpit mode and the IDE child hasn't been built yet,
    /// though in practice the IDE child is always built first and retained indefinitely.
    var splitViewController: CodeEditSplitViewController? {
        (contentViewController as? ShellViewController)?.ideViewController
    }

    init(
        window: NSWindow?,
        workspace: WorkspaceDocument?
    ) {
        super.init(window: window)
        window?.delegate = self
        guard let workspace else { return }
        self.workspace = workspace
        self.toolbarCollapsed = workspace.getFromWorkspaceState(.toolbarCollapsed) as? Bool ?? false

        guard let shellViewController = setupShell(with: workspace) else {
            fatalError("Failed to set up content view.")
        }

        // Setting contentViewController triggers ShellViewController.viewDidLoad synchronously,
        // which builds the IDE child and calls ideVC.view (loading ideVC too). By the time this
        // assignment returns, shellVC.ideViewController and its splitViewItems are populated.
        contentViewController = shellViewController

        navigatorSidebarViewModel = shellViewController.navigatorViewModel
        listenToDocumentEdited(workspace: workspace)

        guard let ideVC = shellViewController.ideViewController,
              let firstItem = ideVC.splitViewItems.first,
              let lastItem = ideVC.splitViewItems.last else {
            fatalError("ShellViewController did not produce an IDE view controller.")
        }

        observers = [
            firstItem.observe(\.isCollapsed, changeHandler: { [weak self] item, _ in
                self?.navigatorCollapsed = item.isCollapsed
            }),
            lastItem.observe(\.isCollapsed, changeHandler: { [weak self] item, _ in
                self?.inspectorCollapsed = item.isCollapsed
            })
        ]

        setupToolbar()
        updateToolbarVisibility()
        registerCommands()
    }

    deinit {
        cancellables.forEach({ $0.cancel() })
        cancellables.removeAll()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupShell(with workspace: WorkspaceDocument) -> ShellViewController? {
        guard window != nil else {
            assertionFailure("No window found for this controller. Cannot set up content.")
            return nil
        }
        return ShellViewController(workspace: workspace, windowController: self)
    }

    // MARK: - Mode switching

    /// Switches the window to `mode`. No-op when `FeatureFlags.cockpitView` is false.
    func switchViewMode(to mode: ViewMode) {
        guard FeatureFlags.cockpitView else { return }
        (contentViewController as? ShellViewController)?.setViewMode(mode)
    }

    private func getSelectedCodeFile() -> CodeFileDocument? {
        workspace?.editorManager?.activeEditor.selectedTab?.file.fileDocument
    }

    @IBAction func saveDocument(_ sender: Any) {
        guard let codeFile = getSelectedCodeFile() else { return }
        codeFile.save(sender)
        workspace?.editorManager?.activeEditor.temporaryTab = nil
    }

    @IBAction func openCommandPalette(_ sender: Any) {
        if let workspace, let state = workspace.commandsPaletteState {
            if let commandPalettePanel {
                if commandPalettePanel.isKeyWindow {
                    commandPalettePanel.close()
                    self.panelOpen = false
                    state.reset()
                    return
                } else {
                    state.reset()
                    window?.addChildWindow(commandPalettePanel, ordered: .above)
                    commandPalettePanel.makeKeyAndOrderFront(self)
                    self.panelOpen = true
                }
            } else {
                let panel = SearchPanel()
                self.commandPalettePanel = panel
                let contentView = QuickActionsView(state: state) {
                    panel.close()
                    self.panelOpen = false
                }
                panel.contentView = NSHostingView(rootView: SettingsInjector { contentView })
                window?.addChildWindow(panel, ordered: .above)
                panel.makeKeyAndOrderFront(self)
                self.panelOpen = true
            }
        }
    }

    /// Opens the search navigator and focuses the search field
    @IBAction func openSearchNavigator(_ sender: Any? = nil) {
        if navigatorCollapsed {
            toggleFirstPanel()
        }

        if let navigatorViewModel = navigatorSidebarViewModel,
           let searchTab = navigatorViewModel.tabItems.first(where: { $0 == .search }) {
            DispatchQueue.main.async {
                self.workspace?.searchState?.shouldFocusSearchField = true
                navigatorViewModel.setNavigatorTab(tab: searchTab)
            }
        }
    }

    @IBAction func openQuickly(_ sender: Any?) {
        if let workspace, let state = workspace.openQuicklyViewModel {
            if let quickOpenPanel {
                if quickOpenPanel.isKeyWindow {
                    quickOpenPanel.close()
                    self.panelOpen = false
                    return
                } else {
                    window?.addChildWindow(quickOpenPanel, ordered: .above)
                    quickOpenPanel.makeKeyAndOrderFront(self)
                    self.panelOpen = true
                }
            } else {
                let panel = SearchPanel()
                self.quickOpenPanel = panel

                let contentView = OpenQuicklyView(state: state) {
                    panel.close()
                    self.panelOpen = false
                } openFile: { file in
                    workspace.editorManager?.openTab(item: file)
                }.environmentObject(workspace)

                panel.contentView = NSHostingView(rootView: SettingsInjector { contentView })
                window?.addChildWindow(panel, ordered: .above)
                panel.makeKeyAndOrderFront(self)
                self.panelOpen = true
            }
        }
    }

    @IBAction func closeCurrentTab(_ sender: Any) {
        if self.panelOpen { return }
        if (workspace?.editorManager?.activeEditor.tabs ?? []).isEmpty {
            self.closeActiveEditor(self)
        } else {
            workspace?.editorManager?.activeEditor.closeSelectedTab()
        }
    }

    @IBAction func closeActiveEditor(_ sender: Any) {
        if workspace?.editorManager?.editorLayout.findSomeEditor(
            except: workspace?.editorManager?.activeEditor
        ) == nil {
            NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: NSApp.keyWindow, from: nil)
        } else {
            workspace?.editorManager?.activeEditor.close()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancellables.forEach({ $0.cancel() })
        cancellables.removeAll()

        for _ in 0..<(splitViewController?.children.count ?? 0) {
            splitViewController?.removeChild(at: 0)
        }
        contentViewController?.removeFromParent()
        contentViewController = nil

        workspaceSettingsWindow?.close()
        workspaceSettingsWindow = nil
        quickOpenPanel = nil
        commandPalettePanel = nil
        navigatorSidebarViewModel = nil
        workspace = nil
        return true
    }
}
