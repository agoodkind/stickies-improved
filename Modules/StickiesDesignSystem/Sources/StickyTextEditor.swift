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
  private let isEditable: Bool

  public init(
    text: Binding<String>,
    fontName: String?,
    fontSize: Double,
    fontColorHex: String?,
    isEditable: Bool = true
  ) {
    _text = text
    self.fontName = fontName
    self.fontSize = fontSize
    self.fontColorHex = fontColorHex
    self.isEditable = isEditable
  }

  public func makeNSView(context: Context) -> NSView {
    let textView = NSTextView()
    textView.isRichText = false
    textView.importsGraphics = false
    textView.allowsImageEditing = false
    textView.isEditable = isEditable
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
    // The editable note clears the floating traffic lights with a top inset; the
    // read-only preview has no traffic lights over it, so it starts flush.
    scrollView.contentInsets = NSEdgeInsets(
      top: isEditable ? Layout.scrollTopInset : 0, left: 0, bottom: 0, right: 0
    )

    applyStyle(to: textView)

    // Wrap the scroll view so a transparent strip can sit above its top inset. The strip
    // drags the window like a title bar: the editable note hides the system title bar for
    // the full-bleed look, so without it the text view receives the click as a caret
    // placement instead of a window move. The scroll view fills the container, so the
    // editor's frame, insets, and rendered pixels are unchanged.
    let container = NSView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: container.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])

    // Only the editable note window is draggable; the read-only preview lives inside the
    // manager window and has no top inset to grab.
    if isEditable {
      let dragStrip = WindowDragView()
      dragStrip.scrollView = scrollView
      dragStrip.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(dragStrip)
      NSLayoutConstraint.activate([
        dragStrip.topAnchor.constraint(equalTo: container.topAnchor),
        dragStrip.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        dragStrip.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        dragStrip.heightAnchor.constraint(equalToConstant: Layout.scrollTopInset),
      ])
    }
    return container
  }

  public func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.text = $text
    guard let scrollView = nsView.subviews.compactMap({ $0 as? NSScrollView }).first,
      let textView = scrollView.documentView as? NSTextView
    else { return }
    // While the editor is first responder the user is typing, so the text view is the
    // source of truth: never overwrite it from the model here. The model briefly lags
    // (debounced autosave, then an iCloud-monitor reload of the just-written file), and
    // overwriting mid-keystroke is exactly what made typed characters vanish. Only sync
    // from the model when the editor is not being actively edited.
    let isEditing = textView.window?.firstResponder === textView
    if !isEditing, textView.string != text {
      textView.string = text
    }
    applyStyle(to: textView)
    // Focus the editable note once the window exists so a freshly opened note takes the
    // caret immediately. The read-only preview must never steal first responder.
    if isEditable, !context.coordinator.didFocus, let window = textView.window {
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
    // The note background adapts to the system appearance (vivid pastel in light, muted
    // dark in dark), so the text must adapt too: leave the appearance unpinned so the
    // default `labelColor` is dark on the light note and light on the dark note.
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

// MARK: - WindowDragView

/// A transparent strip pinned over the note's top inset. The editable note hides the system
/// title bar for the full-bleed look, so this restores title-bar-style dragging: a press
/// starts a window move, while wheel events fall through to the note body so scrolling over
/// the strip still scrolls the text. It draws nothing, so it changes no pixels, and it sits
/// only over the inset above the first line, so it never covers text or the traffic lights
/// (which the system draws above the content).
private final class WindowDragView: NSView {
  weak var scrollView: NSScrollView?

  // Let AppKit move the window when this strip is dragged. The window is
  // movableByWindowBackground, and the text view below returns false here, so only this
  // top strip drags the window, the way a title bar does.
  override var mouseDownCanMoveWindow: Bool { true }

  override func scrollWheel(with event: NSEvent) {
    if let scrollView {
      scrollView.scrollWheel(with: event)
    } else {
      super.scrollWheel(with: event)
    }
  }
}
