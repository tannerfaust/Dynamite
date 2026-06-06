//
//  SplitViewItem.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 05/03/2023.
//

import SwiftUI
import Combine

func makeSplitPaneHostingController<Content: View>(rootView: Content) -> NSHostingController<Content> {
    let controller = NSHostingController(rootView: rootView)
    if #available(macOS 13.0, *) {
        // Split panes are sized by NSSplitViewItem constraints and holding priorities.
        // Exporting SwiftUI min/intrinsic/max size constraints makes AppKit remeasure
        // large hosted subtrees on every resize frame.
        controller.sizingOptions = []
    }
    return controller
}

class SplitViewItem: ObservableObject {

    var id: AnyHashable
    var item: NSSplitViewItem

    var collapsed: Binding<Bool>
    private var requestedCollapsed: Bool

    var cancellables: [AnyCancellable] = []

    var observers: [NSKeyValueObservation] = []

    init(child: _VariadicView.Children.Element) {
        self.id = child.id
        self.item = NSSplitViewItem(viewController: makeSplitPaneHostingController(rootView: child))
        self.collapsed = child[SplitViewItemCollapsedViewTraitKey.self]
        self.requestedCollapsed = self.collapsed.wrappedValue
        self.item.canCollapse = child[SplitViewItemCanCollapseViewTraitKey.self]
        self.item.isCollapsed = self.collapsed.wrappedValue
        self.item.holdingPriority = child[SplitViewHoldingPriorityTraitKey.self]
        // Skip the initial observation via a dispatch to avoid a "updating during view update" error
        DispatchQueue.main.async {
            self.observers = self.createObservers()
        }
    }

    private func createObservers() -> [NSKeyValueObservation] {
        [
            item.observe(\.isCollapsed) { [weak self] item, _ in
                self?.requestedCollapsed = item.isCollapsed
                self?.collapsed.wrappedValue = item.isCollapsed
            }
        ]
    }

    /// Updates a SplitViewItem.
    /// This will fetch updated binding values and update them if needed.
    /// - Parameter child: the view corresponding to the SplitViewItem.
    func update(child: _VariadicView.Children.Element) {
        item.canCollapse = child[SplitViewItemCanCollapseViewTraitKey.self]
        item.holdingPriority = child[SplitViewHoldingPriorityTraitKey.self]

        let canAnimate = child[SplitViewItemCanAnimateViewTraitKey.self]

        let collapsed = child[SplitViewItemCollapsedViewTraitKey.self]
        self.collapsed = collapsed

        let shouldCollapse = collapsed.wrappedValue
        guard requestedCollapsed != shouldCollapse else {
            return
        }
        requestedCollapsed = shouldCollapse

        DispatchQueue.main.async { [weak self] in
            guard let self, self.item.isCollapsed != shouldCollapse else {
                return
            }

            self.observers.removeAll()
            if canAnimate {
                self.item.animator().isCollapsed = shouldCollapse
            } else {
                self.item.isCollapsed = shouldCollapse
            }
            self.observers = self.createObservers()
        }
    }
}
