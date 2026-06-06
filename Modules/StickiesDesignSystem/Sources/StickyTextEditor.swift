//
//  StickyTextEditor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import SwiftUI

/// The plain-text note body. It bridges an `NSTextView` configured with
/// `isRichText = false`, which Apple documents converts pasted or dropped rich text to
/// plain text, so ⌘V, the Edit menu, and drag-and-drop all land as plain characters in
/// one uniform font, size, and color across the whole note. The view draws no
/// background so the per-note color shows through.
public struct StickyTextEditor: NSViewRepresentable {
    /// Insets tuned against a real Plain Text Stickies note: the first text line sits
    /// about 32pt below the window top, clearing the floating traffic lights, with a 5pt
    /// left margin. The editor fills the window (the caller pins it past the safe area),
    /// so the top split between the scroll view's content inset and the text container
    /// inset is absolute rather than relative to a SwiftUI safe area.
    private enum Layout {
        static let scrollTopInset: CGFloat = 24
        static let containerTopInset: CGFloat = 8
        static let containerLeftInset: CGFloat = 5
    }

    @Binding private var text: String
    private let fontName: String?
    private let fontSize: Double
    private let fontColorHex: String?

    public init(
        text: Binding<String>,
        fontName: String?,
        fontSize: Double,
        fontColorHex: String?
    ) {
        _text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColorHex = fontColorHex
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsImageEditing = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(
            width: Layout.containerLeftInset,
            height: Layout.containerTopInset
        )
        textView.delegate = context.coordinator
        textView.string = text
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(
            top: Layout.scrollTopInset, left: 0, bottom: 0, right: 0
        )

        applyStyle(to: textView)
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Rebuild from the model only when it genuinely diverges, so typing does not
        // reset the caret. Reassigning `string` collapses the selection otherwise.
        if textView.string != text {
            textView.string = text
        }
        applyStyle(to: textView)
        // Focus the editor once the window exists so a freshly opened note takes the
        // caret immediately. Retries across updates until the window is attached.
        if !context.coordinator.didFocus, let window = textView.window {
            if window.makeFirstResponder(textView) {
                context.coordinator.didFocus = true
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    /// Applies the uniform note font and color. With `isRichText = false` the font and
    /// color cover the whole note, so a pasted run can never carry its own.
    private func applyStyle(to textView: NSTextView) {
        let font = resolvedFont
        textView.font = font
        textView.textColor = resolvedColor
        // The note is a light frosted glass panel, so pin a light appearance to keep the
        // default label color dark and readable on the tint.
        textView.appearance = NSAppearance(named: .aqua)
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: resolvedColor,
        ]
    }

    private var resolvedFont: NSFont {
        guard let fontName, let named = NSFont(name: fontName, size: fontSize) else {
            return .systemFont(ofSize: fontSize)
        }
        return named
    }

    private var resolvedColor: NSColor {
        guard let fontColorHex, let color = HexColor.color(from: fontColorHex) else {
            return .labelColor
        }
        return NSColor(color)
    }

    @preconcurrency
    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var didFocus = false

        init(text: Binding<String>) {
            self.text = text
        }

        public func textDidChange(_ notification: Notification) {
            guard let changedView = notification.object as? NSTextView else { return }
            // Persist the plain string only; with `isRichText = false` there are no
            // attributes to carry, so the saved note matches what is on screen.
            if text.wrappedValue != changedView.string {
                text.wrappedValue = changedView.string
            }
        }
    }
}
