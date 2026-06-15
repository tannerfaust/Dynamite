//
//  MarkdownEngineAppKitBridge.swift
//  CodeEdit
//
//  Small AppKit hooks layered around the upstream MarkdownEngine view.
//

import AppKit
import Combine
import SwiftUI

struct MarkdownEngineAppKitBridge: NSViewRepresentable {
    var slashMenuEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = MarkdownEngineBridgeProbeView()
        view.onResolve = { [weak coordinator = context.coordinator] probe in
            coordinator?.configure(from: probe)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.slashMenuEnabled = slashMenuEnabled
        DispatchQueue.main.async {
            context.coordinator.configure(from: nsView)
        }
    }

    final class Coordinator {
        var slashMenuEnabled = true

        private let slashMenuController = MarkdownSlashMenuController()

        func configure(from probe: NSView) {
            guard let scrollView = probe.nearestDescendantScrollViewWithTextView(),
                  let textView = scrollView.markdownTextView else {
                return
            }

            if slashMenuEnabled && textView.isEditable {
                slashMenuController.install(textView: textView)
            } else {
                slashMenuController.uninstall()
            }
        }

        deinit {
            slashMenuController.uninstall()
        }
    }
}

private final class MarkdownEngineBridgeProbeView: NSView {
    var onResolve: ((NSView) -> Void)?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        resolveSoon()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resolveSoon()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func resolveSoon() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            onResolve?(self)
        }
    }
}

private final class MarkdownSlashMenuState: ObservableObject {
    @Published var query = ""
    @Published var selectedIndex = 0

    var visibleBlocks: [MarkdownSlashBlock] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return MarkdownSlashBlock.essentials
        }

        return MarkdownSlashBlock.essentials.filter { block in
            block.title.lowercased().contains(normalizedQuery)
                || block.id.lowercased().contains(normalizedQuery)
                || block.category.lowercased().contains(normalizedQuery)
                || block.subtitle.lowercased().contains(normalizedQuery)
        }
    }

    var selectedBlock: MarkdownSlashBlock? {
        guard !visibleBlocks.isEmpty else { return nil }
        return visibleBlocks[min(selectedIndex, visibleBlocks.count - 1)]
    }

    func update(query: String) {
        self.query = query
        selectedIndex = min(selectedIndex, max(visibleBlocks.count - 1, 0))
    }

    func moveSelection(by delta: Int) {
        let blocks = visibleBlocks
        guard !blocks.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = (selectedIndex + delta + blocks.count) % blocks.count
    }
}

private struct MarkdownSlashCommandPaletteView: View {
    @ObservedObject var state: MarkdownSlashMenuState
    var onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if state.visibleBlocks.isEmpty {
                noResults
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        rows
                    }
                    .padding(6)
                }
                .frame(maxHeight: 360)
            }
        }
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .padding(10)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "slash.circle")
                .foregroundStyle(.secondary)
            Text(state.query.isEmpty ? "Insert block" : "/\(state.query)")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Text("Esc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var rows: some View {
        let blocks = state.visibleBlocks
        let indexed = Array(blocks.enumerated())
        ForEach(indexed, id: \.element.id) { index, block in
            if shouldShowCategory(at: index, in: blocks) {
                Text(block.category.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, index == 0 ? 2 : 8)
                    .padding(.bottom, 3)
            }

            row(block: block, isSelected: index == state.selectedIndex)
                .onTapGesture {
                    onSelect(index)
                }
        }
    }

    private func row(block: MarkdownSlashBlock, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(isSelected ? 0.11 : 0.06))
                Image(systemName: block.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(block.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(block.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        }
        .contentShape(Rectangle())
    }

    private var noResults: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No blocks found")
                .font(.system(size: 13, weight: .medium))
            Text("Keep typing, delete the slash, or press Esc.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shouldShowCategory(at index: Int, in blocks: [MarkdownSlashBlock]) -> Bool {
        index == 0 || blocks[index].category != blocks[index - 1].category
    }
}

private final class MarkdownSlashCommandPanel: NSPanel {
    private let state: MarkdownSlashMenuState
    private var hostingView: NSHostingView<MarkdownSlashCommandPaletteView>?
    private var onSelect: ((Int) -> Void)?

    init(state: MarkdownSlashMenuState) {
        self.state = state
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.transient, .ignoresCycle]
        level = .floating
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(attachedTo parentWindow: NSWindow, at screenPoint: NSPoint, onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
        let rootView = MarkdownSlashCommandPaletteView(state: state) { [weak self] index in
            self?.onSelect?(index)
        }
        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            contentView = hostingView
            self.hostingView = hostingView
        }

        let size = desiredSize()
        setContentSize(size)
        setFrameTopLeftPoint(adjustedTopLeftPoint(screenPoint, size: size))

        if parent != parentWindow {
            parentWindow.addChildWindow(self, ordered: .above)
        }
        orderFront(nil)
    }

    func reposition(near screenPoint: NSPoint) {
        let size = desiredSize()
        setContentSize(size)
        setFrameTopLeftPoint(adjustedTopLeftPoint(screenPoint, size: size))
    }

    func hide() {
        orderOut(nil)
        parent?.removeChildWindow(self)
    }

    private func desiredSize() -> NSSize {
        let blocks = state.visibleBlocks
        let groupCount = Set(blocks.map(\.category)).count
        let contentHeight: CGFloat
        if blocks.isEmpty {
            contentHeight = 95
        } else {
            contentHeight = 46 + CGFloat(blocks.count * 42) + CGFloat(groupCount * 22) + 24
        }
        return NSSize(width: 360, height: min(430, max(110, contentHeight)))
    }

    private func adjustedTopLeftPoint(_ point: NSPoint, size: NSSize) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(point) }) ?? NSScreen.main else {
            return point
        }
        let visibleFrame = screen.visibleFrame
        var adjusted = point
        adjusted.x = min(max(adjusted.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        if adjusted.y - size.height < visibleFrame.minY + 8 {
            adjusted.y = min(visibleFrame.maxY - 8, point.y + size.height + 26)
        }
        adjusted.y = min(adjusted.y, visibleFrame.maxY - 8)
        return adjusted
    }
}

private final class MarkdownSlashMenuController {
    private weak var textView: NSTextView?
    private var keyDownMonitor: Any?
    private var textDidChangeObserver: NSObjectProtocol?
    private var selectionDidChangeObserver: NSObjectProtocol?

    private let state = MarkdownSlashMenuState()
    private lazy var panel = MarkdownSlashCommandPanel(state: state)

    private var slashTriggerLocation = NSNotFound
    private var isActive = false

    func install(textView: NSTextView) {
        guard self.textView !== textView else { return }
        uninstall()
        self.textView = textView

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
        textDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAfterTextChange()
        }
        selectionDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAfterSelectionChange()
        }
    }

    func uninstall() {
        close()
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        if let textDidChangeObserver {
            NotificationCenter.default.removeObserver(textDidChangeObserver)
        }
        if let selectionDidChangeObserver {
            NotificationCenter.default.removeObserver(selectionDidChangeObserver)
        }
        keyDownMonitor = nil
        textDidChangeObserver = nil
        selectionDidChangeObserver = nil
        textView = nil
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let textView,
              textView.isEditable,
              textView.window?.firstResponder === textView else {
            return event
        }

        if isActive {
            return handleActiveKeyDown(event, in: textView)
        }

        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
              event.characters == "/" || event.charactersIgnoringModifiers == "/" else {
            return event
        }

        DispatchQueue.main.async { [weak self] in
            self?.openIfValidSession()
        }
        return event
    }

    private func handleActiveKeyDown(_ event: NSEvent, in textView: NSTextView) -> NSEvent? {
        switch event.keyCode {
        case 53: // Escape
            close()
            return nil
        case 125: // Down arrow
            state.moveSelection(by: 1)
            repositionPanel()
            return nil
        case 126: // Up arrow
            state.moveSelection(by: -1)
            repositionPanel()
            return nil
        case 36, 76, 48: // Return, keypad return, Tab
            guard state.selectedBlock != nil else {
                close()
                return event
            }
            insertSelectedBlock()
            return nil
        case 49: // Space
            close()
            return event
        case 51, 117: // Backspace, forward delete
            DispatchQueue.main.async { [weak self] in
                self?.refreshAfterTextChange()
            }
            return event
        default:
            DispatchQueue.main.async { [weak self] in
                self?.refreshAfterTextChange()
            }
            return event
        }
    }

    private func openIfValidSession() {
        guard let textView,
              let session = currentSession(in: textView) else {
            return
        }
        isActive = true
        slashTriggerLocation = session.triggerLocation
        state.selectedIndex = 0
        state.update(query: session.query)
        showPanel()
    }

    private func refreshAfterTextChange() {
        guard isActive, let textView else { return }
        guard let session = currentSession(in: textView),
              session.triggerLocation == slashTriggerLocation,
              !session.query.contains(where: { $0.isWhitespace || $0.isNewline }) else {
            close()
            return
        }
        state.update(query: session.query)
        repositionPanel()
    }

    private func refreshAfterSelectionChange() {
        guard isActive, let textView else { return }
        guard let session = currentSession(in: textView),
              session.triggerLocation == slashTriggerLocation else {
            close()
            return
        }
        state.update(query: session.query)
        repositionPanel()
    }

    private func currentSession(in textView: NSTextView) -> (triggerLocation: Int, query: String)? {
        guard let storage = textView.textStorage else { return nil }
        let selectedRange = textView.selectedRange()
        guard selectedRange.length == 0,
              selectedRange.location > 0,
              selectedRange.location <= storage.length else {
            return nil
        }

        let nsString = storage.string as NSString
        let searchRange = NSRange(location: 0, length: selectedRange.location)
        let slashRange = nsString.range(of: "/", options: .backwards, range: searchRange)
        guard slashRange.location != NSNotFound else { return nil }

        let lineRange = nsString.lineRange(for: NSRange(location: slashRange.location, length: 0))
        guard slashRange.location >= lineRange.location else { return nil }

        let prefixLength = slashRange.location - lineRange.location
        let prefix = nsString.substring(with: NSRange(location: lineRange.location, length: prefixLength))
        guard prefix.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let queryStart = slashRange.location + 1
        guard selectedRange.location >= queryStart else { return nil }
        let queryRange = NSRange(location: queryStart, length: selectedRange.location - queryStart)
        let query = nsString.substring(with: queryRange)
        guard !query.contains("\n") else { return nil }
        return (slashRange.location, query)
    }

    private func showPanel() {
        guard let textView,
              let window = textView.window else { return }
        panel.show(attachedTo: window, at: panelScreenPoint(in: textView)) { [weak self] index in
            self?.insertBlock(at: index)
        }
    }

    private func repositionPanel() {
        guard isActive, let textView else { return }
        if panel.isVisible {
            panel.reposition(near: panelScreenPoint(in: textView))
        } else {
            showPanel()
        }
    }

    private func panelScreenPoint(in textView: NSTextView) -> NSPoint {
        guard let window = textView.window else {
            return .zero
        }
        let range = NSRange(location: max(slashTriggerLocation, 0), length: 1)
        let rect = textView.firstRect(forCharacterRange: range, actualRange: nil)
        guard !rect.isEmpty else {
            let local = NSPoint(x: textView.textContainerOrigin.x, y: textView.textContainerOrigin.y + 20)
            return window.convertPoint(toScreen: textView.convert(local, to: nil))
        }
        return NSPoint(x: rect.minX, y: rect.minY - 8)
    }

    private func insertSelectedBlock() {
        guard let block = state.selectedBlock else { return }
        insert(block)
    }

    private func insertBlock(at index: Int) {
        let blocks = state.visibleBlocks
        guard index >= 0, index < blocks.count else { return }
        insert(blocks[index])
    }

    private func insert(_ block: MarkdownSlashBlock) {
        guard let textView,
              let storage = textView.textStorage,
              slashTriggerLocation != NSNotFound,
              slashTriggerLocation < storage.length else {
            close()
            return
        }

        let caretLocation = textView.selectedRange().location
        let replacementLength = max(1, caretLocation - slashTriggerLocation)
        let replacementRange = NSRange(
            location: slashTriggerLocation,
            length: min(replacementLength, storage.length - slashTriggerLocation)
        )

        var snippet = block.snippet
        let caretOffset: Int
        if let caretRange = snippet.range(of: MarkdownSlashBlock.caretToken) {
            let prefix = String(snippet[..<caretRange.lowerBound])
            caretOffset = (prefix as NSString).length
            snippet.removeSubrange(caretRange)
        } else {
            caretOffset = (snippet as NSString).length
        }

        guard textView.shouldChangeText(in: replacementRange, replacementString: snippet) else {
            close()
            return
        }
        storage.replaceCharacters(in: replacementRange, with: snippet)
        textView.didChangeText()
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: slashTriggerLocation + caretOffset, length: 0))
        close()
    }

    private func close() {
        guard isActive || panel.isVisible else { return }
        isActive = false
        slashTriggerLocation = NSNotFound
        state.query = ""
        state.selectedIndex = 0
        panel.hide()
    }
}

private extension NSScrollView {
    var markdownTextView: NSTextView? {
        if let textView = documentView as? NSTextView {
            return textView
        }
        return documentView?.firstDescendant(of: NSTextView.self)
    }
}

private extension NSView {
    func nearestDescendantScrollViewWithTextView() -> NSScrollView? {
        var root: NSView? = self
        for _ in 0..<10 {
            if let scrollView = root?.firstDescendant(
                of: NSScrollView.self,
                where: { $0.markdownTextView != nil }
            ) {
                return scrollView
            }
            root = root?.superview
        }
        return nil
    }

    func firstDescendant<T: NSView>(of type: T.Type) -> T? {
        firstDescendant(of: type) { _ in true }
    }

    func firstDescendant<T: NSView>(of type: T.Type, where predicate: (T) -> Bool) -> T? {
        if let view = self as? T, predicate(view) {
            return view
        }
        for subview in subviews {
            if let match = subview.firstDescendant(of: type, where: predicate) {
                return match
            }
        }
        return nil
    }
}
