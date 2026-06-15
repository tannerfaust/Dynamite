//
//  LinearSyncing.swift
//  CodeEdit
//
//  Seam for the future Linear integration. Tasks & Projects are local-first today; when Linear
//  sync lands, an implementation of this protocol pushes local changes and pulls remote state,
//  reconciling against the same `product/tasks` and `product/projects` files. No networking here.
//

import Foundation

/// Bidirectional sync between local work-item stores and an external tracker (Linear first).
///
/// Intentionally minimal: the UI binds to `TaskStore` / `ProjectStore`, never to a provider, so
/// adding Linear is implementing this protocol and wiring a settings toggle — not a UI rewrite.
protocol LinearSyncing: AnyObject {
    /// Whether a remote connection is currently configured and authorized.
    var isConnected: Bool { get }

    /// Push local task/project changes to the remote tracker.
    func push() async throws

    /// Pull remote changes into the local stores, returning the number of records updated.
    @discardableResult
    func pull() async throws -> Int
}

/// Default no-op adapter used until a real Linear adapter ships. Lets call sites depend on the
/// protocol today without branching on optionals.
final class DisconnectedSync: LinearSyncing {
    var isConnected: Bool { false }
    func push() async throws {}
    @discardableResult func pull() async throws -> Int { 0 }
}
