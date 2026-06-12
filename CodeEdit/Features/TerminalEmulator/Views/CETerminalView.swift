//
//  CETerminalView.swift
//  CodeEdit
//
//  Created by Khan Winter on 7/11/25.
//

import SwiftTerm
import AppKit

/// # Please see dev note in ``CELocalShellTerminalView``!

class CETerminalView: TerminalView {
    private var terminalGridResizeWorkItem: DispatchWorkItem?
    private var isApplyingTerminalGridResize = false
    private var lastTerminalGridResizeTime: TimeInterval = 0

    override func setFrameSize(_ newSize: NSSize) {
        if newSize != .zero {
            if isApplyingTerminalGridResize {
                super.setFrameSize(newSize)
            } else {
                super.setFrameSize(newSize)
                scheduleTerminalGridResize()
            }
        }
    }

    override open var frame: CGRect {
        get {
            super.frame
        }
        set {
            if newValue.size != .zero {
                if isApplyingTerminalGridResize {
                    super.frame = newValue
                } else {
                    super.setFrameOrigin(newValue.origin)
                    super.setFrameSize(newValue.size)
                    scheduleTerminalGridResize()
                }
            }
        }
    }

    override func viewDidEndLiveResize() {
        terminalGridResizeWorkItem?.cancel()
        terminalGridResizeWorkItem = nil
        applyTerminalGridResize()
        super.viewDidEndLiveResize()
    }

    private func scheduleTerminalGridResize() {
        guard terminalGridResizeWorkItem == nil else { return }
        // Terminal buffer reflow is much more expensive than visually resizing the view.
        // Keep it live, but capped low enough that split/window resize stays smooth.
        let interval: TimeInterval = 1.0 / 12.0
        let now = ProcessInfo.processInfo.systemUptime
        let delay = max(0, interval - (now - lastTerminalGridResizeTime))

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.terminalGridResizeWorkItem = nil
            self.lastTerminalGridResizeTime = ProcessInfo.processInfo.systemUptime
            self.applyTerminalGridResize()
        }
        terminalGridResizeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func applyTerminalGridResize() {
        guard frame.size != .zero else { return }
        isApplyingTerminalGridResize = true
        super.frame = frame
        isApplyingTerminalGridResize = false
    }

    @objc
    override open func copy(_ sender: Any) {
        let range = selectedPositions()
        let text = terminal.getText(start: range.start, end: range.end)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    override open func isAccessibilityElement() -> Bool {
        true
    }

    override open func isAccessibilityEnabled() -> Bool {
        true
    }

    override open func accessibilityLabel() -> String? {
        "Terminal Emulator"
    }

    override open func accessibilityRole() -> NSAccessibility.Role? {
        .textArea
    }

    override open func accessibilityValue() -> Any? {
        terminal.getText(
            start: Position(col: 0, row: 0),
            end: Position(col: terminal.buffer.x, row: terminal.getTopVisibleRow() + terminal.rows)
        )
    }

    override open func accessibilitySelectedText() -> String? {
        let range = selectedPositions()
        let text = terminal.getText(start: range.start, end: range.end)
        return text
    }

}
