// swiftlint:disable line_length
//
//  StandardTableViewCell.swift
//  CodeEdit
//
//  Created by TAY KAI QUAN on 17/8/22.
//

import SwiftUI

class StandardTableViewCell: NSTableCellView {

    weak var secondaryLabel: NSTextField?
    weak var workspace: WorkspaceDocument?

    var secondaryLabelRightAligned: Bool = true {
        didSet {
            resizeSubviews(withOldSize: .zero)
        }
    }

    /// Initializes the `TableViewCell` with an `icon` and `label`
    /// Both the icon and label will be colored, and sized based on the user's preferences.
    /// - Parameters:
    ///   - frameRect: The frame of the cell.
    ///   - item: The file item the cell represents.
    ///   - isEditable: Set to true if the user should be able to edit the file name.
    init(frame frameRect: NSRect, isEditable: Bool = true) {
        super.init(frame: frameRect)
        setupViews(frame: frameRect, isEditable: isEditable)

    }

    // Default init, assumes isEditable to be false
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews(frame: frameRect, isEditable: false)
    }

    private func setupViews(frame frameRect: NSRect, isEditable: Bool) {
        // Create the label
        let label = createLabel()
        configLabel(label: label, isEditable: isEditable)
        self.textField = label

        // Create the secondary label
        let secondaryLabel = createSecondaryLabel()
        configSecondaryLabel(secondaryLabel: secondaryLabel)
        self.secondaryLabel = secondaryLabel

        // Create the icon
        let icon = createIcon()
        configIcon(icon: icon)
        addSubview(icon)
        imageView = icon

        // add constraints
        createConstraints(frame: frameRect)
        addSubview(label)
        addSubview(secondaryLabel)
        addSubview(icon)
    }

    // MARK: Create and config stuff
    func createLabel() -> NSTextField {
        return SpecialSelectTextField(frame: .zero)
    }

    func configLabel(label: NSTextField, isEditable: Bool) {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = isEditable
        label.isSelectable = isEditable
        label.layer?.cornerRadius = 10.0
        label.font = .labelFont(ofSize: fontSize)
        label.lineBreakMode = .byTruncatingMiddle
    }

    func createSecondaryLabel() -> NSTextField {
        return NSTextField(frame: .zero)
    }

    func configSecondaryLabel(secondaryLabel: NSTextField) {
        secondaryLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryLabel.drawsBackground = false
        secondaryLabel.isBordered = false
        secondaryLabel.isEditable = false
        secondaryLabel.isSelectable = false
        secondaryLabel.layer?.cornerRadius = 10.0
        secondaryLabel.font = .systemFont(ofSize: fontSize-2, weight: .bold)
        secondaryLabel.alignment = .center
        secondaryLabel.textColor = .secondaryLabelColor
    }

    func createIcon() -> NSImageView {
        return NSImageView(frame: .zero)
    }

    func configIcon(icon: NSImageView) {
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.symbolConfiguration = .init(pointSize: fontSize, weight: .regular, scale: .medium)
    }

    func createConstraints(frame frameRect: NSRect) {
        resizeSubviews(withOldSize: .zero)
    }

    let iconWidth: CGFloat = 22
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        guard let imageView, textField != nil, secondaryLabel != nil else {
            assertionFailure(
                "Missing child view:"
                + " imageView \(imageView == nil)"
                + ", textField: \(textField == nil)"
                + ", label: \(secondaryLabel == nil)"
            )
            return
        }

        imageView.frame = NSRect(
            x: 2,
            y: 4,
            width: iconWidth,
            height: frame.height
        )
        // center align the image
        if let alignmentRect = imageView.image?.alignmentRect {
            imageView.frame = NSRect(
                x: (iconWidth - alignmentRect.width) / 2,
                y: 4,
                width: alignmentRect.width,
                height: frame.height
            )
        }

        // right align the secondary label
        if secondaryLabelRightAligned {
            rightAlignSecondary()
        } else {
            // put the secondary label right after the primary label
            leftAlignSecondary()
        }
    }

    private func rightAlignSecondary() {
        guard let secondaryLabel, let textField, let imageView else { return }
        let secondLabelWidth = secondaryLabel.frame.size.width
        let newSize = secondaryLabel.sizeThatFits(
            CGSize(width: secondLabelWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        // somehow, a width of 0 makes it resize properly.
        secondaryLabel.frame = NSRect(
            x: frame.width - newSize.width,
            y: 3.5,
            width: 0,
            height: newSize.height
        )

        textField.frame = NSRect(
            x: iconWidth + 2,
            y: 3.5,
            width: secondaryLabel.frame.minX - imageView.frame.maxX - 5,
            height: 25
        )
    }

    private func leftAlignSecondary() {
        guard let secondaryLabel, let textField else { return }
        let mainLabelWidth = textField.frame.size.width
        let newSize = textField.sizeThatFits(CGSize(width: mainLabelWidth, height: CGFloat.greatestFiniteMagnitude))
        textField.frame = NSRect(
            x: iconWidth + 2,
            y: 2.5,
            width: newSize.width,
            height: 25
        )
        secondaryLabel.frame = NSRect(
            x: textField.frame.maxX + 2,
            y: 2.5,
            width: frame.width - textField.frame.maxX - 2,
            height: 25
        )
    }

    /// *Not Implemented*
    required init?(coder: NSCoder) {
        fatalError("""
            init?(coder: NSCoder) isn't implemented on `StandardTableViewCell`.
            Please use `.init(frame: NSRect, isEditable: Bool)
            """)
    }

    /// Returns the font size for the current row height. Defaults to `13.0`
    private var fontSize: Double {
        switch self.frame.height {
        case 20: return 11
        case 22: return 13
        case 24: return 14
        default: return 13
        }
    }

    class SpecialTextFieldCell: NSTextFieldCell {
        var textInsets = NSEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

        private var isEditingOrSelecting: Bool {
            if let textField = controlView as? NSTextField,
               textField.currentEditor() != nil {
                return true
            }
            return false
        }

        override func drawingRect(forBounds rect: NSRect) -> NSRect {
            guard isEditingOrSelecting else {
                return super.drawingRect(forBounds: rect)
            }
            let rectWithInsets = NSRect(
                x: rect.origin.x + textInsets.left,
                y: rect.origin.y + textInsets.top,
                width: rect.size.width - textInsets.left - textInsets.right,
                height: rect.size.height - textInsets.top - textInsets.bottom
            )
            return super.drawingRect(forBounds: rectWithInsets)
        }

        override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
            let rectWithInsets = NSRect(
                x: rect.origin.x + textInsets.left,
                y: rect.origin.y + textInsets.top,
                width: rect.size.width - textInsets.left - textInsets.right,
                height: rect.size.height - textInsets.top - textInsets.bottom
            )
            super.select(withFrame: rectWithInsets, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
        }

        override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
            let rectWithInsets = NSRect(
                x: rect.origin.x + textInsets.left,
                y: rect.origin.y + textInsets.top,
                width: rect.size.width - textInsets.left - textInsets.right,
                height: rect.size.height - textInsets.top - textInsets.bottom
            )
            super.edit(withFrame: rectWithInsets, in: controlView, editor: textObj, delegate: delegate, event: event)
        }
    }

    class SpecialSelectTextField: NSTextField {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.cell = SpecialTextFieldCell()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.cell = SpecialTextFieldCell()
        }

        override func becomeFirstResponder() -> Bool {
            let endIdx: String.Index
            if let lastDot = stringValue.lastIndex(of: "."), lastDot != stringValue.startIndex {
                endIdx = lastDot
            } else {
                endIdx = stringValue.endIndex
            }
            let length = stringValue.distance(from: stringValue.startIndex, to: endIdx)
            let range = NSRange(location: 0, length: length)
            selectText(self)
            let editor = currentEditor()
            editor?.selectedRange = range
            return true
        }

        override func resignFirstResponder() -> Bool {
            let status = super.resignFirstResponder()
            if status {
                wantsLayer = false
                layer?.backgroundColor = nil
                layer?.borderWidth = 0
                layer?.borderColor = nil
            }
            return status
        }

        override func textDidBeginEditing(_ notification: Notification) {
            super.textDidBeginEditing(notification)
            wantsLayer = true
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.cornerRadius = 4
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        }

        override func textDidEndEditing(_ notification: Notification) {
            super.textDidEndEditing(notification)
            wantsLayer = false
            layer?.backgroundColor = nil
            layer?.borderWidth = 0
            layer?.borderColor = nil
        }
    }
}
