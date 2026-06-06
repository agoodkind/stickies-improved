//
//  StickiesAppDelegate.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 06/06/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit

/// Restores a window when the user clicks the dock icon after closing every note. SwiftUI's
/// scene system does not reopen a `Window`/`WindowGroup` on reactivation by itself, so the
/// app would otherwise sit running with nothing on screen.
final class StickiesAppDelegate: NSObject, NSApplicationDelegate {
    // The launcher scene is a 1x1 helper window that stays alive for the app's lifetime, so it
    // must not count as a real, user-facing window when deciding whether to reopen one.
    private static let minVisibleWindowWidth: CGFloat = 50

    /// Opens (or focuses) the manager window. The App sets this once a scene can vend
    /// `openWindow`; it is held statically so it survives after every note window closes.
    @MainActor static var openManager: (() -> Void)?

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows _: Bool
    ) -> Bool {
        // The `hasVisibleWindows` flag counts the 1x1 launcher window, so it stays true even
        // when every note has closed; scan for a real window instead. AppKit calls this on
        // the main thread, so the main-actor `NSApplication`/`NSWindow` reads and the
        // main-actor `openManager` access are safe to assume here.
        MainActor.assumeIsolated {
            let hasRealWindow = sender.windows.contains { window in
                window.isVisible && window.frame.width >= Self.minVisibleWindowWidth
            }
            if !hasRealWindow {
                Self.openManager?()
            }
        }
        return true
    }
}
