//
//  StickyTextEditor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import SwiftUI

/// An `NSTextView`-backed plain-text editor that reproduces the original Plain Text
/// Stickies note body: one uniform font, size, and text color across the whole note,
/// not rich text. The view draws no background so the SwiftUI per-note color shows
/// through, and it routes Fonts and Colors panel changes back to the workspace through
/// the supplied callbacks.
public struct StickyTextEditor: NSViewRepresentable {
    /// Insets measured against a real Plain Text Stickies note, where the first text line
    /// sits about 32pt below the window top, clearing the traffic lights, with a 5pt left
    /// margin. SwiftUI already insets the editor below the titlebar by the window safe
    /// area (about 30pt), so the top inset here is only a small fine-tune on top of that.
    /// The left margin is the standard `NSTextView` line-fragment padding of 5pt.
    private enum Layout {
        static let topInset: CGFloat = 2
        static let horizontalInset: CGFloat = 0
        static let lineFragmentPadding: CGFloat = 5
    }

    @Binding private var text: String
    private let fontName: String?
    private let fontSize: Double
    private let fontColorHex: String?
    private let onFontChange: (String?, Double) -> Void
    private let onColorChange: (String?) -> Void

    public init(
        text: Binding<String>,
        fontName: String?,
        fontSize: Double,
        fontColorHex: String?,
        onFontChange: @escaping (String?, Double) -> Void,
        onColorChange: @escaping (String?) -> Void
    ) {
        _text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColorHex = fontColorHex
        self.onFontChange = onFontChange
        self.onColorChange = onColorChange
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        // Pin the editor to the light appearance so the default text color resolves
        // dark on the pastel note. Pinning the window alone is not enough, since the
        // SwiftUI hosting view re-imposes the system appearance on its subviews; setting
        // it directly on the editor view is more specific and wins. This matches Plain
        // Text Stickies, which always renders dark text regardless of system dark mode.
        scrollView.appearance = NSAppearance(named: .aqua)

        let textView = StickyNoteTextView()
        textView.appearance = NSAppearance(named: .aqua)
        textView.onFontChange = onFontChange
        textView.onColorChange = onColorChange
        textView.delegate = context.coordinator

        textView.isRichText = false
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.usesFontPanel = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        textView.string = text
        applyTypography(to: textView)
        applyContainerInsets(to: textView)

        scrollView.documentView = textView
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? StickyNoteTextView else { return }

        // Refresh the callbacks so they capture the current note's identity rather
        // than the one bound when the view was first made.
        textView.onFontChange = onFontChange
        textView.onColorChange = onColorChange
        context.coordinator.updateBinding($text)

        // Reapply the bound text without stomping the caret when the model and the
        // view already agree, which is the common case while the user is typing.
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        applyTypography(to: textView)
        applyContainerInsets(to: textView)
    }

    private func applyTypography(to textView: NSTextView) {
        let resolvedFont = Self.resolveFont(name: fontName, size: fontSize)
        let resolvedColor = Self.resolveColor(hex: fontColorHex)

        // Uniform across the whole note: set the view-level font/color and push them
        // onto the full text storage so existing glyphs adopt the change too.
        if textView.font != resolvedFont {
            textView.font = resolvedFont
        }
        if textView.textColor != resolvedColor {
            textView.textColor = resolvedColor
        }

        guard let textStorage = textView.textStorage, textStorage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.font, value: resolvedFont, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: resolvedColor, range: fullRange)
    }

    private func applyContainerInsets(to textView: NSTextView) {
        let inset = NSSize(width: Layout.horizontalInset, height: Layout.topInset)
        if textView.textContainerInset != inset {
            textView.textContainerInset = inset
        }
        // Line-fragment padding insets the start and end of each line, so it is the
        // left margin (5pt, the standard NSTextView value that Plain Text Stickies uses).
        textView.textContainer?.lineFragmentPadding = Layout.lineFragmentPadding
    }

    private static func resolveFont(name: String?, size: Double) -> NSFont {
        let pointSize = CGFloat(size)
        guard let name, let named = NSFont(name: name, size: pointSize) else {
            return NSFont.systemFont(ofSize: pointSize)
        }
        return named
    }

    private static func resolveColor(hex: String?) -> NSColor {
        guard let hex, let color = HexColor.color(from: hex) else {
            return NSColor.textColor
        }
        return color
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func updateBinding(_ binding: Binding<String>) {
            text = binding
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

// MARK: - StickyNoteTextView

/// `NSTextView` subclass that captures the system Fonts and Colors panel actions. While
/// this view is first responder it claims the shared `NSFontManager` and `NSColorPanel`
/// target/action with custom selectors, so a panel pick lands here directly rather than
/// travelling the responder chain to the inherited `changeFont:`/`changeColor:`. Routing
/// to custom selectors sidesteps both the Objective-C selector clash with the superclass
/// and the untyped `Any?` sender of the inherited overrides, and it keeps the note's one
/// uniform font and color in sync through the workspace callbacks.
public final class StickyNoteTextView: NSTextView {
    public var onFontChange: ((String?, Double) -> Void)?
    public var onColorChange: ((String?) -> Void)?

    // `NSColorPanel` exposes only setters for its target/action, so ownership is tracked
    // here rather than read back from the panel when releasing it on resignation.
    private var ownsColorPanel = false

    override public func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            claimPanelTargets()
        }
        return didBecome
    }

    override public func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            releasePanelTargets()
        }
        return didResign
    }

    private func claimPanelTargets() {
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.action = #selector(handleFontPanelChange(_:))

        // Only wire the target and action. Do NOT sync the panel's color here: setting
        // `NSColorPanel.color` while the action is wired fires `handleColorPanelChange`,
        // which would persist the resolved default text color as an explicit color the
        // user never chose (white under system dark mode). The note keeps its nil default
        // until the user actually picks a color in the panel.
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(handleColorPanelChange(_:)))
        ownsColorPanel = true
    }

    private func releasePanelTargets() {
        let fontManager = NSFontManager.shared
        if fontManager.target === self {
            fontManager.target = nil
        }
        if ownsColorPanel {
            let colorPanel = NSColorPanel.shared
            colorPanel.setTarget(nil)
            colorPanel.setAction(nil)
            ownsColorPanel = false
        }
    }

    @objc
    private func handleFontPanelChange(_ sender: NSFontManager) {
        let currentFont = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let convertedFont = sender.convert(currentFont)

        font = convertedFont
        applyUniformFont(convertedFont)

        let resolvedName = Self.persistableFontName(for: convertedFont)
        onFontChange?(resolvedName, Double(convertedFont.pointSize))
    }

    @objc
    private func handleColorPanelChange(_ sender: NSColorPanel) {
        let chosenColor = sender.color

        textColor = chosenColor
        applyUniformColor(chosenColor)

        onColorChange?(HexColor.string(from: chosenColor))
    }

    private func applyUniformFont(_ font: NSFont) {
        guard let textStorage, textStorage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.font, value: font, range: fullRange)
    }

    private func applyUniformColor(_ color: NSColor) {
        guard let textStorage, textStorage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.foregroundColor, value: color, range: fullRange)
    }

    /// Returns the PostScript font name to persist, or `nil` when the font is the
    /// system font so the note keeps tracking the system face rather than pinning a
    /// concrete name that could drift across OS releases.
    private static func persistableFontName(for font: NSFont) -> String? {
        let systemFont = NSFont.systemFont(ofSize: font.pointSize)
        if font.fontName == systemFont.fontName {
            return nil
        }
        return font.fontName
    }
}
