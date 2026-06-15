//
//  Router.swift
//  CodeEdit
//

import AppKit
import Foundation

/// Parses, generates, and dispatches `dynamite://` routes for a workspace.
///
/// Both top-level environments for a workspace (Product Studio and Ground Control) reach the same
/// `Router` through `WorkspaceDocument.router`. Routing is always workspace-relative.
///
/// ## Window targeting rule (ADR-0006 §3)
/// When a route's natural target mode differs from the source window's current mode, the router
/// first looks for another open window on the *same workspace* that is already in the target mode
/// and routes there. This lets a Product Studio window (left) + Ground Control window (right) setup
/// work naturally: clicking a citation in Studio jumps the Ground Control window to file/line
/// without flipping the Studio.
@MainActor
final class Router {
    // MARK: - Properties

    private weak var workspace: WorkspaceDocument?

    // MARK: - Init

    /// Creates a router bound to `workspace`.
    init(workspace: WorkspaceDocument) {
        self.workspace = workspace
    }

    // MARK: - URL parsing

    /// Parses a `dynamite://` URL into a `DynamiteRoute`.
    ///
    /// Returns `nil` when the scheme is not `dynamite` or the host/path cannot be mapped.
    nonisolated static func parse(url: URL) -> DynamiteRoute? {
        guard url.scheme == "dynamite" else { return nil }
        switch url.host ?? "" {
        case "node":    return parseNode(url: url)
        case "surface": return parseSurface(url: url)
        case "code":    return parseCode(url: url)
        case "context": return parseContext(url: url)
        case "mode":    return parseMode(url: url)
        default:        return nil
        }
    }

    nonisolated private static func parseNode(url: URL) -> DynamiteRoute? {
        let id = String(url.path.dropFirst())
        return id.isEmpty ? nil : .node(id: id)
    }

    nonisolated private static func parseSurface(url: URL) -> DynamiteRoute? {
        let id = String(url.path.dropFirst())
        return id.isEmpty ? nil : .surface(id: id)
    }

    nonisolated private static func parseCode(url: URL) -> DynamiteRoute? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let path = items.first(where: { $0.name == "path" })?.value, !path.isEmpty else { return nil }
        let line = items.first(where: { $0.name == "line" })?.value.flatMap { Int($0, radix: 10) }
        let symbol = items.first(where: { $0.name == "symbol" })?.value
        return .code(path: path, line: line, symbol: symbol)
    }

    nonisolated private static func parseContext(url: URL) -> DynamiteRoute? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let path = items.first(where: { $0.name == "path" })?.value, !path.isEmpty else { return nil }
        return .context(path: path)
    }

    nonisolated private static func parseMode(url: URL) -> DynamiteRoute? {
        let raw = String(url.path.dropFirst())
        guard let mode = ViewMode(legacyOrRouteValue: raw) else { return nil }
        return .mode(mode)
    }

    // MARK: - URL generation

    /// Builds a `dynamite://` URL for the given route.
    nonisolated static func url(for route: DynamiteRoute) -> URL {
        var components = URLComponents()
        components.scheme = "dynamite"

        switch route {
        case .node(let id):
            components.host = "node"
            components.path = "/\(id)"

        case .surface(let id):
            components.host = "surface"
            components.path = "/\(id)"

        case let .code(path, line, symbol):
            components.host = "code"
            var items = [URLQueryItem(name: "path", value: path)]
            if let line { items.append(URLQueryItem(name: "line", value: String(line))) }
            if let symbol { items.append(URLQueryItem(name: "symbol", value: symbol)) }
            components.queryItems = items

        case .context(let path):
            components.host = "context"
            components.queryItems = [URLQueryItem(name: "path", value: path)]

        case .mode(let mode):
            components.host = "mode"
            components.path = "/\(mode.routeValue)"
        }

        return components.url ?? URL(string: "dynamite://invalid")! // swiftlint:disable:this force_unwrapping
    }

    // MARK: - Route handling

    /// Handles a route, picking the best window and switching mode if needed.
    ///
    /// - Parameters:
    ///   - route: The route to dispatch.
    ///   - sourceWindow: The window initiating the navigation (nil = use any workspace window).
    func handle(route: DynamiteRoute, from sourceWindow: CodeEditWindowController? = nil) {
        switch route {
        case .mode(let mode):
            let target = sourceWindow ?? windowController(preferring: mode)
            target?.switchViewMode(to: mode)

        case .node(let id):
            let target = windowController(preferring: .studio, from: sourceWindow)
            target?.switchViewMode(to: .studio)
            target?.workspace?.addToWorkspaceState(key: .cockpitSelectedNode, value: id)
            // Post async so the Product Studio child (built by switchViewMode above) has a runloop
            // tick to set up its SwiftUI subscriptions before the focus event arrives.
            let workspaceURL = workspace?.fileURL
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .cockpitFocusNode,
                    object: nil,
                    userInfo: Self.focusUserInfo(id: id, workspaceURL: workspaceURL)
                )
            }

        case .surface(let id):
            let target = windowController(preferring: .studio, from: sourceWindow)
            target?.switchViewMode(to: .studio)
            target?.workspace?.addToWorkspaceState(key: .cockpitSelectedSurface, value: id)
            let workspaceURL = workspace?.fileURL
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .cockpitFocusSurface,
                    object: nil,
                    userInfo: Self.focusUserInfo(id: id, workspaceURL: workspaceURL)
                )
            }

        case let .code(path, line, _):
            let target = windowController(preferring: .groundControl, from: sourceWindow)
            target?.switchViewMode(to: .groundControl)
            openFile(path: path, line: line, in: target)

        case .context(let path):
            // In Ground Control the inspector already surfaces product context from LinkIndex by path.
            // In Product Studio, switch there so the user sees the context panel.
            if let source = sourceWindow, source.viewMode == .groundControl {
                _ = path // Inspector observes active editor; no explicit action needed here.
            } else {
                let target = windowController(preferring: .studio, from: sourceWindow)
                target?.switchViewMode(to: .studio)
            }
        }
    }

    // MARK: - Private helpers

    /// Focus-notification payload. Includes the workspace URL so observers in other
    /// project windows can ignore the event (notifications are app-global).
    nonisolated private static func focusUserInfo(id: String, workspaceURL: URL?) -> [String: Any] {
        var info: [String: Any] = ["id": id]
        if let workspaceURL { info["workspaceURL"] = workspaceURL }
        return info
    }

    /// Best `CodeEditWindowController` for `targetMode` among this workspace's open windows.
    ///
    /// Preference: existing window already in `targetMode` → `exclude` itself → any workspace window.
    private func windowController(
        preferring targetMode: ViewMode,
        from exclude: CodeEditWindowController? = nil
    ) -> CodeEditWindowController? {
        let all = workspaceWindowControllers()
        return all.first(where: { $0 !== exclude && $0.viewMode == targetMode })
            ?? exclude
            ?? all.first
    }

    /// All `CodeEditWindowController`s for this workspace.
    private func workspaceWindowControllers() -> [CodeEditWindowController] {
        NSApplication.shared.windows.compactMap { $0.windowController as? CodeEditWindowController }
            .filter { $0.workspace === workspace }
    }

    /// Opens a workspace-relative file in the given window's editor, then posts a line-navigation
    /// notification if a specific line was requested.
    private func openFile(path: String, line: Int?, in windowController: CodeEditWindowController?) {
        guard let workspace,
              let fileManager = workspace.workspaceFileManager,
              let windowController else { return }

        let absolutePath = fileManager.folderUrl.appendingPathComponent(path).path
        guard let file = fileManager.getFile(absolutePath, createIfNotFound: true) else { return }

        workspace.editorManager?.openTab(item: file)

        guard let line else { return }
        // Line scrolling is handled by the editor itself; post a notification that the active
        // editor can observe (implementation in the Editor feature, not Shell's responsibility).
        NotificationCenter.default.post(
            name: .shellNavigateToLine,
            object: windowController,
            userInfo: ["line": line]
        )
    }
}

extension Notification.Name {
    /// Posted by `Router.handle(route:from:)` after opening a file when a line was specified.
    ///
    /// `userInfo["line"]` is an `Int` (1-based line number). The active editor observes this
    /// notification and scrolls to the requested line.
    static let shellNavigateToLine = Notification.Name("dynamite.shell.navigateToLine")

    /// Posted for a `dynamite://node/<id>` route. `userInfo["id"]` is the node id (`String`).
    ///
    /// `ProductStudioRootView` observes it to switch to the artifact workspace; `StudioViewModel`
    /// observes it to select the artifact.
    /// Name kept as `cockpit` for compatibility with existing in-process subscribers.
    static let cockpitFocusNode = Notification.Name("dynamite.cockpit.focusNode")

    /// Posted for a `dynamite://surface/<id>` route. `userInfo["id"]` is the surface id (`String`).
    /// Name kept as `cockpit` for compatibility with existing in-process subscribers.
    static let cockpitFocusSurface = Notification.Name("dynamite.cockpit.focusSurface")
}
