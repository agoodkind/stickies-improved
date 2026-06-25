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
    /// Height of the top frost band. The blur is densest at the very top, under the
    /// floating traffic lights, and the band's gradient mask fades it to clear by this
    /// depth so it blends into the note body. A taller band frosts more lines.
    static let frostBandHeight: CGFloat = 64
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

    // The editable note adds a top frost band that blurs text scrolling under the window's
    // top edge, plus a transparent strip that drags the window like a title bar. The
    // read-only preview lives inside the manager window with no titlebar, so it gets neither.
    if isEditable {
      addFrostBand(to: container, scrollView: scrollView)
      addDragStrip(to: container, scrollView: scrollView)
    }
    return container
  }

  /// Adds the top frost band above the scroll view so it blurs the text scrolling behind it.
  /// It is added before the drag strip so the strip stays on top for window dragging, and it
  /// tracks the scroll view so the frost fades in only as content scrolls under it.
  private func addFrostBand(to container: NSView, scrollView: NSScrollView) {
    let frost = FrostBandView()
    frost.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(frost)
    NSLayoutConstraint.activate([
      frost.topAnchor.constraint(equalTo: container.topAnchor),
      frost.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      frost.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      frost.heightAnchor.constraint(equalToConstant: Layout.frostBandHeight),
    ])
    frost.bind(to: scrollView)
  }

  /// Adds the transparent top strip that drags the window like a title bar, scrolling the
  /// note when the wheel passes over it.
  private func addDragStrip(to container: NSView, scrollView: NSScrollView) {
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

// MARK: - FrostBandView

/// A top-aligned Liquid Glass band that refracts and blurs the note text scrolling behind it,
/// the way Messages frosts content under its header. It is an `NSGlassEffectView`, which is
/// AppKit-native, so unlike a SwiftUI `.glassEffect` it lives in the same layer tree as the
/// sibling scroll view ordered behind it and refracts that text rather than only tinting. The
/// glass computes its own tint and light/dark adaptation from the content behind it, so the
/// appearance is left untouched. A vertical gradient layer mask fades it to clear toward the
/// body so the frost is densest at the top edge. It never takes hit-testing, so clicks fall
/// through to the drag strip and the text below.
private final class FrostBandView: NSGlassEffectView {
  /// Unit gradient endpoints for the fade mask: opaque at the top edge, clear at the bottom.
  private static let maskCenterX: CGFloat = 0.5
  private static let maskTop = CGPoint(x: maskCenterX, y: 1)
  private static let maskBottom = CGPoint(x: maskCenterX, y: 0)
  /// Scroll distance, in points, over which the frost ramps from invisible to full. Keeping
  /// it about one line means the first line stays fully crisp at rest and the frost appears
  /// as soon as content begins moving under the edge, the way native scroll edge effects do.
  private static let rampDistance: CGFloat = 28

  private let fadeMask = CAGradientLayer()
  private weak var observedScrollView: NSScrollView?
  // Set only on the main actor in bind(to:); read in the nonisolated deinit, which for an
  // AppKit view also runs on the main thread, so unguarded access is safe here.
  nonisolated(unsafe) private var scrollObserver: NSObjectProtocol?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configureGlass()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureGlass()
  }

  deinit {
    if let scrollObserver {
      NotificationCenter.default.removeObserver(scrollObserver)
    }
  }

  private func configureGlass() {
    // An empty, clear content view makes the band a pure glass pane, so the Liquid Glass
    // refracts the note text scrolling behind it instead of hosting a control.
    contentView = NSView()
    cornerRadius = 0
    wantsLayer = true
    // Start invisible: the frost only appears once content scrolls under the edge.
    alphaValue = 0
    fadeMask.colors = [NSColor.white.cgColor, NSColor.clear.cgColor]
    fadeMask.startPoint = Self.maskTop
    fadeMask.endPoint = Self.maskBottom
    layer?.mask = fadeMask
  }

  /// Tracks the scroll view's clip view so the frost strength follows the scroll position:
  /// fully transparent at the top (first line crisp) and ramping to full as content scrolls
  /// under the edge.
  func bind(to scrollView: NSScrollView) {
    observedScrollView = scrollView
    let clip = scrollView.contentView
    clip.postsBoundsChangedNotifications = true
    scrollObserver = NotificationCenter.default.addObserver(
      forName: NSView.boundsDidChangeNotification,
      object: clip,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.updateFrostStrength() }
    }
    updateFrostStrength()
  }

  private func updateFrostStrength() {
    guard let observedScrollView else { return }
    let restingTopOriginY = -observedScrollView.contentInsets.top
    let originY = max(observedScrollView.contentView.bounds.origin.y, restingTopOriginY)
    let scrolled = max(0, originY - restingTopOriginY)
    alphaValue = min(scrolled / Self.rampDistance, 1)
  }

  override func hitTest(_: NSPoint) -> NSView? {
    nil
  }

  override func layout() {
    super.layout()
    fadeMask.frame = bounds
  }
}
