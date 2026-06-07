//
//  StickiesAppDelegate.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 06/06/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit

/// Brings up the All Notes manager when the user clicks the dock icon. The manager is the
/// app's main window, so a dock click should surface it whether or not a note window is open,
/// and especially after every note has closed (SwiftUI does not reopen a scene on its own).
final class StickiesAppDelegate: NSObject, NSApplicationDelegate {
  /// Opens (or focuses) the manager window. The App sets this once a scene can vend
  /// `openWindow`; it is held statically so it survives after every note window closes.
  @MainActor static var openManager: (() -> Void)?

  func applicationShouldHandleReopen(
    _: NSApplication,
    hasVisibleWindows _: Bool
  ) -> Bool {
    // Always surface the manager. `openWindow(id:)` focuses it if it already exists, so
    // this is idempotent. AppKit calls this on the main thread, so the main-actor
    // `openManager` access is safe to assume here.
    MainActor.assumeIsolated {
      Self.openManager?()
    }
    return true
  }
}
