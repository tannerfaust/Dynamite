//
//  CockpitSurfaceRegistry.swift
//  CodeEdit
//

import SwiftUI

/// Holds the ordered list of `CockpitSurface` registrations for one workspace window.
///
/// `ShellViewController` owns one registry per window. Surfaces register themselves at feature
/// initialization time (T1.6+) and unregister on tear-down. `CockpitRootView` observes the
/// registry to update its sidebar and content area automatically.
final class CockpitSurfaceRegistry: ObservableObject {
    /// Ordered list of registered surfaces, in registration order.
    @Published private(set) var surfaces: [AnyHashableCockpitSurface] = []

    /// Registers a surface. No-op if a surface with the same `id` is already registered.
    func register(_ surface: some CockpitSurface) {
        guard !surfaces.contains(where: { $0.id == surface.id }) else { return }
        surfaces.append(AnyHashableCockpitSurface(surface))
    }

    /// Removes the surface with `id` from the registry.
    func unregister(id: String) {
        surfaces.removeAll { $0.id == id }
    }
}

// MARK: - Type-erased wrapper

/// Type-erased, hashable wrapper around any `CockpitSurface`.
///
/// Needed so `[any CockpitSurface]` can be stored in a `@Published` array and used in ForEach.
struct AnyHashableCockpitSurface: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    private let _body: () -> AnyView

    init(_ surface: some CockpitSurface) {
        self.id = surface.id
        self.title = surface.title
        self.systemImage = surface.systemImage
        self._body = { surface.body }
    }

    /// The surface's root view.
    var body: AnyView { _body() }

    static func == (lhs: AnyHashableCockpitSurface, rhs: AnyHashableCockpitSurface) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
