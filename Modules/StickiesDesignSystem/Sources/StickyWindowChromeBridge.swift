//
//  StickyWindowChromeBridge.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
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
public struct StickyWindowChromeBridge: NSViewRepresentable {
    /// Recovered from `-[StickieWindowController windowDidResignKey:]`, which reads the
    /// `nonFocusTransparency` user default whose registered fallback is 0.97. A focused
    /// window is fully opaque; an unfocused one drops to this alpha.
    private enum Focus {
        static let unfocusedAlphaDefaultsKey = "nonFocusTransparency"
        static let unfocusedAlphaFallback: CGFloat = 0.97
        static let focusedAlpha: CGFloat = 1.0
    }

    public final class Coordinator {
        var didConfigure = false
        var observers: [NSObjectProtocol] = []

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    public init() {
        // No configuration; the window is found at make time.
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        let coordinator = context.coordinator
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

        window.styleMask.formUnion([
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView,
        ])
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        applyFocusAlpha(to: window)
        observeFocus(of: window, coordinator: coordinator)
    }

    @MainActor
    private func observeFocus(of window: NSWindow, coordinator: Coordinator) {
        let center = NotificationCenter.default
        let onKey = center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                window.alphaValue = Focus.focusedAlpha
            }
        }
        let onResign = center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                window.alphaValue = unfocusedAlpha()
            }
        }
        coordinator.observers.append(contentsOf: [onKey, onResign])
    }

    @MainActor
    private func applyFocusAlpha(to window: NSWindow) {
        window.alphaValue = window.isKeyWindow ? Focus.focusedAlpha : unfocusedAlpha()
    }

    private func unfocusedAlpha() -> CGFloat {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Focus.unfocusedAlphaDefaultsKey) != nil else {
            return Focus.unfocusedAlphaFallback
        }
        return CGFloat(defaults.float(forKey: Focus.unfocusedAlphaDefaultsKey))
    }
}
