//
//  StickyWindowChromeBridge.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import StickiesDomain
import SwiftUI

/// Configures the hosting `NSWindow` to match the abandoned Plain Text Stickies app
/// exactly, recovered from its `Stickie.nib`:
/// `NSWindowStyleMask` 32783 = titled | closable | miniaturizable | resizable |
/// fullSizeContentView, with a transparent titlebar and hidden title. Because the
/// content view paints the note color full-bleed under that transparent titlebar,
/// the three STANDARD system traffic lights float on the color at the OS default
/// position. The configuration is applied exactly once so it never mutates the window
/// inside an active layout pass, and it never touches the standard window buttons, so
/// they stay the unmodified OS controls at the default inset, which is what makes them
/// pixel-identical.
///
/// On top of that chrome it adds the two recovered window behaviors: per-note frame
/// persistence (restore the saved frame on first configure, save on move and resize)
/// and fold/collapse (the green zoom button or a double-click on the titlebar strip
/// shrinks the window to the titlebar height and shows the note title, toggling back
/// to the stored expanded height). Both are additive and never touch the chrome above.
public struct StickyWindowChromeBridge: NSViewRepresentable {
    private enum Fold {
        /// Fallback expanded height when no height was ever stored, matching the
        /// SwiftUI default 400x400 note size.
        static let defaultExpandedHeight: CGFloat = 400
    }

    // Named no-op defaults for the chrome-only path. Empty closure literals trip the
    // no_empty_block lint rule, so the no-ops are spelled out as functions with bodies.
    // They are `@MainActor` because the workspace-backed closures capture main-actor
    // state, so every closure in this type carries the main-actor isolation.
    @MainActor static func noSavedFrame() -> NoteFrame? {
        nil
    }

    @MainActor static func ignoreFrameChange(_: NoteFrame) {
        // The chrome-only window does not persist its frame.
    }

    @MainActor static func ignoreCollapseChange(_: Bool, _: Double?) {
        // The chrome-only window does not fold.
    }

    @MainActor static func noCollapsedTitle() -> String {
        ""
    }

    private let noteID: NoteID?
    private let savedFrame: @MainActor () -> NoteFrame?
    private let onFrameChange: @MainActor (NoteFrame) -> Void
    private let initialCollapsed: Bool
    private let initialExpandedHeight: Double?
    private let onCollapseChange: @MainActor (Bool, Double?) -> Void
    private let collapsedTitle: @MainActor () -> String

    public final class Coordinator: NSObject {
        var didConfigure = false
        var observers: [NSObjectProtocol] = []
        weak var window: NSWindow?

        var savedFrame: @MainActor () -> NoteFrame? = StickyWindowChromeBridge.noSavedFrame
        var onFrameChange: @MainActor (NoteFrame) -> Void =
            StickyWindowChromeBridge.ignoreFrameChange
        var onCollapseChange: @MainActor (Bool, Double?) -> Void =
            StickyWindowChromeBridge.ignoreCollapseChange
        var collapsedTitle: @MainActor () -> String = StickyWindowChromeBridge.noCollapsedTitle

        var isCollapsed = false
        /// Content height to restore when expanding, in window-frame points.
        var expandedHeight: CGFloat = Fold.defaultExpandedHeight
        /// Set while a fold animation runs so the move and resize observers do not
        /// mistake the shrinking frame for a user resize and persist it as the
        /// expanded height.
        var isFolding = false
        /// The window's content minimum height before folding. SwiftUI sets a content
        /// minimum (the note's `minHeight`), which would otherwise clamp the collapse
        /// and stop the window from shrinking to the titlebar strip. It is captured on
        /// the first collapse and restored on expand.
        var unfoldedContentMinHeight: CGFloat?

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    /// Note-window initializer wiring fold and frame persistence to the workspace.
    @preconcurrency
    public init(
        noteID: NoteID,
        savedFrame: @escaping @MainActor () -> NoteFrame?,
        onFrameChange: @escaping @MainActor (NoteFrame) -> Void,
        initialCollapsed: Bool,
        expandedHeight: Double?,
        onCollapseChange: @escaping @MainActor (Bool, Double?) -> Void,
        collapsedTitle: @escaping @MainActor () -> String
    ) {
        self.noteID = noteID
        self.savedFrame = savedFrame
        self.onFrameChange = onFrameChange
        self.initialCollapsed = initialCollapsed
        initialExpandedHeight = expandedHeight
        self.onCollapseChange = onCollapseChange
        self.collapsedTitle = collapsedTitle
    }

    /// Chrome-only initializer for windows that do not fold or persist a frame.
    public init() {
        noteID = nil
        savedFrame = StickyWindowChromeBridge.noSavedFrame
        onFrameChange = StickyWindowChromeBridge.ignoreFrameChange
        initialCollapsed = false
        initialExpandedHeight = nil
        onCollapseChange = StickyWindowChromeBridge.ignoreCollapseChange
        collapsedTitle = StickyWindowChromeBridge.noCollapsedTitle
    }

    public func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.savedFrame = savedFrame
        coordinator.onFrameChange = onFrameChange
        coordinator.onCollapseChange = onCollapseChange
        coordinator.collapsedTitle = collapsedTitle
        coordinator.isCollapsed = initialCollapsed
        if let initialExpandedHeight {
            coordinator.expandedHeight = CGFloat(initialExpandedHeight)
        }
        return coordinator
    }

    public func makeNSView(context: Context) -> NSView {
        let view = FoldClickView()
        let coordinator = context.coordinator
        view.coordinator = coordinator
        DispatchQueue.main.async {
            configureWindowOnce(from: view, coordinator: coordinator)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            configureWindowOnce(from: nsView, coordinator: coordinator)
        }
    }

    @MainActor
    private func configureWindowOnce(from view: NSView, coordinator: Coordinator) {
        guard !coordinator.didConfigure, let window = view.window else { return }
        coordinator.didConfigure = true
        coordinator.window = window

        window.styleMask.formUnion([
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView,
        ])
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        // Frame persistence and fold only apply to real note windows.
        guard noteID != nil else { return }
        // This bridge owns each note's frame through the note metadata, so turn off the
        // system's automatic window-state restoration. Otherwise macOS restores the
        // window's previous frame (including a stale collapsed strip height) before the
        // saved frame is applied, and the resize observer then persists that wrong height.
        window.isRestorable = false
        restoreSavedFrame(on: window, coordinator: coordinator)
        bindZoomButton(on: window, coordinator: coordinator)
        observeFrameChanges(of: window, coordinator: coordinator)
        applyInitialCollapseIfNeeded(coordinator: coordinator)
    }

    @MainActor
    private func restoreSavedFrame(on window: NSWindow, coordinator: Coordinator) {
        if let frame = coordinator.savedFrame() {
            let restored = NSRect(
                x: frame.x,
                y: frame.y,
                width: frame.width,
                height: frame.height
            )
            window.setFrame(restored, display: false)
            return
        }
        // No frame was ever saved for this note. Force the recovered default size rather
        // than inheriting whatever frame SwiftUI restored from a previous session (which
        // can be a stale collapsed strip), keeping the current top-left anchor so the
        // titlebar stays put and the note grows downward.
        var frame = window.frame
        let topEdge = frame.maxY
        frame.size = NSSize(
            width: Fold.defaultExpandedHeight,
            height: Fold.defaultExpandedHeight
        )
        frame.origin.y = topEdge - Fold.defaultExpandedHeight
        window.setFrame(frame, display: false)
    }

    /// Routes the green zoom button to the fold toggle without altering the button
    /// itself, so it keeps the OS look and default position while triggering a fold
    /// instead of the standard macOS zoom.
    @MainActor
    private func bindZoomButton(on window: NSWindow, coordinator: Coordinator) {
        guard let zoomButton = window.standardWindowButton(.zoomButton) else { return }
        zoomButton.target = coordinator
        zoomButton.action = #selector(Coordinator.toggleFold)
    }

    @MainActor
    private func observeFrameChanges(of window: NSWindow, coordinator: Coordinator) {
        let center = NotificationCenter.default
        let saveFrame: @MainActor () -> Void = {
            guard !coordinator.isFolding else { return }
            let frame = window.frame
            let noteFrame = NoteFrame(
                x: Double(frame.origin.x),
                y: Double(frame.origin.y),
                width: Double(frame.size.width),
                height: Double(frame.size.height)
            )
            coordinator.onFrameChange(noteFrame)
        }
        let onMove = center.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { saveFrame() }
        }
        let onResize = center.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { saveFrame() }
        }
        coordinator.observers.append(contentsOf: [onMove, onResize])
    }

    @MainActor
    private func applyInitialCollapseIfNeeded(coordinator: Coordinator) {
        guard coordinator.isCollapsed else { return }
        coordinator.applyCollapsedFrame(animate: false)
    }
}

// MARK: - StickyWindowChromeBridge.Coordinator

extension StickyWindowChromeBridge.Coordinator {
    /// Content height that the titlebar occupies, computed as the window frame height
    /// minus the content layout rect height. This is the strip that remains visible
    /// when folded.
    @MainActor
    private func titlebarHeight(of window: NSWindow) -> CGFloat {
        window.frame.height - window.contentLayoutRect.height
    }

    @objc @MainActor func toggleFold() {
        guard let window else { return }
        if isCollapsed {
            expand(window: window, animate: true)
        } else {
            collapse(window: window, animate: true)
        }
    }

    @MainActor func collapse(window: NSWindow, animate: Bool) {
        let titlebar = titlebarHeight(of: window)
        expandedHeight = window.frame.height
        isCollapsed = true
        onCollapseChange(true, Double(expandedHeight))
        setTitleVisible(true, on: window)
        lowerContentMinHeight(of: window, to: titlebar)

        var frame = window.frame
        let topEdge = frame.maxY
        frame.size.height = titlebar
        frame.origin.y = topEdge - titlebar
        setFolding(window: window, to: frame, animate: animate)
    }

    @MainActor func expand(window: NSWindow, animate: Bool) {
        isCollapsed = false
        onCollapseChange(false, Double(expandedHeight))
        setTitleVisible(false, on: window)
        restoreContentMinHeight(of: window)

        var frame = window.frame
        let topEdge = frame.maxY
        frame.size.height = expandedHeight
        frame.origin.y = topEdge - expandedHeight
        setFolding(window: window, to: frame, animate: animate)
    }

    /// Applies the collapsed frame for a window that opens already folded, with no
    /// animation. The expanded height is whatever was persisted (already loaded into
    /// `expandedHeight`); only the visible frame shrinks to the titlebar.
    @MainActor func applyCollapsedFrame(animate: Bool) {
        guard let window else { return }
        let titlebar = titlebarHeight(of: window)
        setTitleVisible(true, on: window)
        lowerContentMinHeight(of: window, to: titlebar)

        var frame = window.frame
        let topEdge = frame.maxY
        frame.size.height = titlebar
        frame.origin.y = topEdge - titlebar
        setFolding(window: window, to: frame, animate: animate)
    }

    @MainActor private func setFolding(window: NSWindow, to frame: NSRect, animate: Bool) {
        isFolding = true
        window.setFrame(frame, display: true, animate: animate)
        isFolding = false
    }

    /// Drops the window's content minimum height to the titlebar strip so AppKit lets
    /// the frame shrink past the SwiftUI-imposed minimum. The original is captured once
    /// so a repeated collapse does not overwrite it with the already-lowered value.
    @MainActor private func lowerContentMinHeight(of window: NSWindow, to titlebar: CGFloat) {
        if unfoldedContentMinHeight == nil {
            unfoldedContentMinHeight = window.contentMinSize.height
        }
        window.contentMinSize.height = titlebar
        window.minSize.height = titlebar
    }

    @MainActor private func restoreContentMinHeight(of window: NSWindow) {
        guard let restored = unfoldedContentMinHeight else { return }
        window.contentMinSize.height = restored
        window.minSize.height = restored
        unfoldedContentMinHeight = nil
    }

    /// When folded, the recovered behavior shows the note title in the titlebar strip.
    /// Since `titleVisibility` is hidden for the full-bleed look, set the window title
    /// and flip visibility to `.visible` while collapsed, then back to `.hidden` on
    /// expand so the expanded note stays full-bleed with no title.
    @MainActor private func setTitleVisible(_ visible: Bool, on window: NSWindow) {
        if visible {
            window.title = collapsedTitle()
            window.titleVisibility = .visible
        } else {
            window.titleVisibility = .hidden
        }
    }
}

// MARK: - FoldClickView

/// Backing view for the bridge that also turns a double-click into a fold toggle.
/// A double-click only folds when it lands on the titlebar strip (outside the
/// content layout rect), so double-clicking to select text in the editor below is
/// never swallowed.
private final class FoldClickView: NSView {
    /// `mouseUp` click count that counts as a fold toggle on the titlebar strip.
    private static let doubleClickCount = 2

    weak var coordinator: StickyWindowChromeBridge.Coordinator?

    override func mouseUp(with event: NSEvent) {
        let isDoubleClick = event.clickCount == Self.doubleClickCount
        if isDoubleClick, let window, isInTitlebarStrip(event, in: window) {
            coordinator?.toggleFold()
            return
        }
        super.mouseUp(with: event)
    }

    private func isInTitlebarStrip(_ event: NSEvent, in window: NSWindow) -> Bool {
        let pointInWindow = event.locationInWindow
        // contentLayoutRect is the area below the titlebar in window coordinates, so a
        // point above its top edge is on the titlebar strip where folding is allowed.
        return pointInWindow.y > window.contentLayoutRect.maxY
    }
}
