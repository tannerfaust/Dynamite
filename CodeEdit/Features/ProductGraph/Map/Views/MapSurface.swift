//
//  MapSurface.swift
//  CodeEdit
//

import SwiftUI

/// Cockpit surface that hosts the zoomable Product Map graph view.
///
/// Registered in `ShellViewController.registerCockpitSurfaces()` alongside `StudioSurface`.
/// `ProductMapView` owns its own `@StateObject`, so layout state persists across
/// Cockpit surface switches — the graph doesn't re-layout on every navigation.
///
/// Both references are weak and optional: the map renders (empty) with no index and
/// no router, per the standalone-mode invariant in ARCHITECTURE.md.
struct MapSurface: CockpitSurface {
    let id = "product-map"
    let title = "Product Map"
    let systemImage = "point.3.connected.trianglepath.dotted"

    weak var linkIndexManager: LinkIndexManager?
    weak var router: Router?

    var body: AnyView {
        AnyView(ProductMapView(linkIndexManager: linkIndexManager, router: router))
    }
}
